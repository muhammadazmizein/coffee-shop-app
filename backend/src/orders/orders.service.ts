import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { distanceKm } from '../common/geo.js';
import type { AuthUser } from '../common/auth.js';
import { calcMemberDiscount, calcPointsEarned } from '../membership/membership.logic.js';
import { MembershipService } from '../membership/membership.service.js';
import { PaymentsService } from '../payments/payments.service.js';
import { toPaymentView, type PayMethod } from '../payments/payments.logic.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { OrderStatus } from '../generated/prisma/client.js';
import type { CreateOrderDto } from './orders.dto.js';
import { notifyOrderStatus } from '../notifications/notify.js';
import { reversePaidOrderPoints } from './cancel.js';
import { recordEvent } from './events.js';
import { calcDeliveryFee, calcTotals, isOutletOpen } from './pricing.js';

const TRANSITIONS: Record<string, OrderStatus[]> = {
  PAID: ['PREPARING', 'CANCELLED'],
  PREPARING: ['READY', 'CANCELLED'],
  READY: ['ON_DELIVERY', 'COMPLETED'],
  ON_DELIVERY: ['COMPLETED'],
};

@Injectable()
export class OrdersService {
  private readonly logger = new Logger(OrdersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly payments: PaymentsService,
    private readonly membership: MembershipService,
  ) {}

  /** Validasi + hitung harga. Dipakai bersama oleh quote() dan create(); tidak menulis ke DB. */
  private async prepare(userId: string, dto: CreateOrderDto) {
    const outlet = await this.prisma.outlet.findFirst({ where: { id: dto.outletId, isActive: true } });
    if (!outlet) throw new NotFoundException('Outlet tidak ditemukan');
    if (!isOutletOpen(outlet.openHour, outlet.closeHour)) {
      throw new BadRequestException('Outlet sedang tutup');
    }

    // Harga selalu dihitung ulang di server; harga dari client tidak pernah dipercaya.
    const productIds = [...new Set(dto.items.map((i) => i.productId))];
    const products = await this.prisma.product.findMany({
      where: { id: { in: productIds }, isActive: true },
      include: {
        optionGroups: { include: { options: true } },
        stock: { where: { outletId: outlet.id } },
      },
    });
    const byId = new Map(products.map((p) => [p.id, p]));

    let subtotal = 0;
    const lines = dto.items.map((item) => {
      const product = byId.get(item.productId);
      if (!product) throw new BadRequestException('Produk tidak tersedia');
      if (product.stock.some((s) => !s.isAvailable)) {
        throw new BadRequestException(`${product.name} sedang habis di outlet ini`);
      }

      const optionIds = [...new Set(item.optionIds)];
      const chosen = optionIds.map((id) => {
        for (const g of product.optionGroups) {
          const o = g.options.find((o) => o.id === id);
          if (o) return { group: g, option: o };
        }
        throw new BadRequestException(`Opsi tidak valid untuk ${product.name}`);
      });
      for (const g of product.optionGroups) {
        const n = chosen.filter((c) => c.group.id === g.id).length;
        if (g.required && n === 0) throw new BadRequestException(`${g.name} wajib dipilih untuk ${product.name}`);
        if (n > g.maxSelect) throw new BadRequestException(`${g.name} maksimal ${g.maxSelect} pilihan`);
      }

      const unitPrice = product.price + chosen.reduce((sum, c) => sum + c.option.extraPrice, 0);
      subtotal += unitPrice * item.qty;
      return {
        productId: product.id,
        name: product.name,
        qty: item.qty,
        unitPrice,
        options: chosen.map((c) => ({ id: c.option.id, name: c.option.name, extraPrice: c.option.extraPrice })),
        note: item.note ?? null,
      };
    });

    let addressId: string | null = null;
    let deliveryFee = 0;
    if (dto.type === 'DELIVERY') {
      if (!dto.addressId) throw new BadRequestException('Alamat pengiriman wajib diisi');
      const address = await this.prisma.address.findFirst({ where: { id: dto.addressId, userId } });
      if (!address) throw new NotFoundException('Alamat tidak ditemukan');
      const km = distanceKm(Number(outlet.lat), Number(outlet.lng), Number(address.lat), Number(address.lng));
      const radius = Number(outlet.deliveryRadiusKm);
      if (km > radius) {
        throw new BadRequestException(
          `Alamat di luar jangkauan pengiriman (maks ${radius} km, alamat Anda sekitar ${km.toFixed(1)} km)`,
        );
      }
      addressId = address.id;
      deliveryFee = calcDeliveryFee(km, {
        baseFee: outlet.deliveryBaseFee,
        baseKm: Number(outlet.deliveryBaseKm),
        perKmFee: outlet.deliveryPerKmFee,
      });
    }

    // Level member saat ini: diskon dan pengali poin di-snapshot ke pesanan supaya quote = hasil akhir.
    const { tier } = await this.membership.tierForUser(userId);
    const memberDiscount = calcMemberDiscount(tier, subtotal);

    let voucher = null;
    if (dto.voucherCode) {
      const now = new Date();
      voucher = await this.prisma.voucher.findUnique({ where: { code: dto.voucherCode.trim().toUpperCase() } });
      if (!voucher || !voucher.isActive || voucher.startsAt > now || voucher.endsAt < now) {
        throw new BadRequestException('Voucher tidak valid atau sudah berakhir');
      }
      if (voucher.quota > 0 && voucher.used >= voucher.quota) throw new BadRequestException('Kuota voucher habis');
      // Minimum belanja diuji terhadap subtotal asli (sebelum diskon member).
      if (subtotal < voucher.minSpend) {
        throw new BadRequestException(`Minimum belanja voucher Rp${voucher.minSpend.toLocaleString('id-ID')}`);
      }
    }

    let pointsBalance = 0;
    if (dto.usePoints) {
      pointsBalance = (await this.prisma.user.findUniqueOrThrow({ where: { id: userId }, select: { points: true } })).points;
    }

    // Urutan: subtotal -> diskon member -> voucher -> tukar poin -> ongkir.
    const { discount, pointsUsed, pointDiscount, total } = calcTotals({
      subtotal,
      memberDiscount,
      voucher,
      usePoints: dto.usePoints ?? 0,
      pointsBalance,
      deliveryFee,
    });
    return {
      outlet, lines, addressId, voucher, subtotal, memberDiscount, tierName: tier.name, earnMultiplierPct: tier.earnMultiplierPct,
      discount, pointsUsed, pointDiscount, deliveryFee, total,
    };
  }

  async quote(userId: string, dto: CreateOrderDto) {
    const { subtotal, memberDiscount, tierName, earnMultiplierPct, discount, pointsUsed, pointDiscount, deliveryFee, total } = await this.prepare(userId, dto);
    return { subtotal, memberDiscount, tierName, discount, pointsUsed, pointDiscount, deliveryFee, total, pointsToEarn: calcPointsEarned(total, earnMultiplierPct) };
  }

  async create(userId: string, dto: CreateOrderDto) {
    const { outlet, lines, addressId, voucher, subtotal, memberDiscount, tierName, earnMultiplierPct, discount, pointsUsed, deliveryFee, total } =
      await this.prepare(userId, dto);
    const code = `KP${Date.now().toString(36).toUpperCase()}${randomBytes(2).toString('hex').toUpperCase()}`;

    const order = await this.prisma.$transaction(async (tx) => {
      if (voucher) {
        // Klaim kuota secara atomik: gagal jika `used` sudah berubah oleh pesanan lain.
        const claimed = await tx.voucher.updateMany({
          where: { id: voucher.id, used: voucher.used },
          data: { used: { increment: 1 } },
        });
        if (claimed.count === 0) throw new ConflictException('Voucher sedang dipakai, coba lagi');
      }
      if (pointsUsed > 0) {
        // Potong saldo hanya jika masih cukup; mencegah saldo negatif bila dua order bersamaan.
        const deducted = await tx.user.updateMany({
          where: { id: userId, points: { gte: pointsUsed } },
          data: { points: { decrement: pointsUsed } },
        });
        if (deducted.count === 0) throw new ConflictException('Saldo poin tidak cukup, coba lagi');
      }
      const created = await tx.order.create({
        data: {
          code,
          userId,
          outletId: outlet.id,
          type: dto.type,
          addressId,
          voucherId: voucher?.id,
          subtotal,
          memberDiscount,
          tierName,
          earnMultiplierPct,
          discount,
          deliveryFee,
          pointsUsed,
          total,
          note: dto.note,
          items: { create: lines },
        },
        include: { items: true },
      });
      if (pointsUsed > 0) {
        await tx.pointLedger.create({ data: { userId, delta: -pointsUsed, reason: 'REDEEM', orderId: created.id } });
      }
      await recordEvent(tx, created.id, 'PENDING_PAYMENT', userId, 'Pesanan dibuat');
      return created;
    });

    // Pembayaran dimulai terpisah lewat POST /orders/:id/pay setelah pelanggan memilih metode.
    return { ...order, payment: null };
  }

  /** Mulai/ulangi pembayaran dengan metode pilihan pelanggan. */
  pay(userId: string, orderId: string, method: PayMethod, phone?: string) {
    return this.payments.charge(userId, orderId, method, phone);
  }

  async listMine(userId: string) {
    const orders = await this.prisma.order.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: { items: true, outlet: { select: { name: true } }, payment: true },
    });
    return orders.map(({ payment, ...o }) => ({ ...o, payment: payment ? toPaymentView(o.id, o.total, payment) : null }));
  }

  async getMine(userId: string, id: string) {
    const pending = await this.prisma.order.findFirst({
      where: { id, userId, status: 'PENDING_PAYMENT' },
      select: { id: true },
    });
    if (pending) await this.payments.syncPending(pending.id);
    const order = await this.prisma.order.findFirst({
      where: { id, userId },
      include: {
        items: true,
        outlet: true,
        address: true,
        courier: { select: { name: true, phone: true } },
        events: { orderBy: { createdAt: 'asc' }, select: { status: true, createdAt: true, note: true } },
        payment: true,
      },
    });
    if (!order) throw new NotFoundException('Pesanan tidak ditemukan');
    const { payment, ...rest } = order;
    return { ...rest, payment: payment ? toPaymentView(order.id, order.total, payment) : null };
  }

  private async staffOutletScope(user: AuthUser): Promise<string | undefined> {
    if (user.role === 'ADMIN') return undefined;
    const u = await this.prisma.user.findUniqueOrThrow({ where: { id: user.id } });
    if (!u.outletId) throw new ForbiddenException('Akun staff belum terhubung ke outlet');
    return u.outletId;
  }

  async listForStaff(user: AuthUser, status?: OrderStatus) {
    const outletId = await this.staffOutletScope(user);
    return this.prisma.order.findMany({
      where: { ...(outletId ? { outletId } : {}), ...(status ? { status } : {}) },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { items: true, address: true, courier: { select: { id: true, name: true, phone: true } }, user: { select: { name: true, phone: true } } },
    });
  }

  async updateStatus(user: AuthUser, id: string, next: OrderStatus, requestedCourierId?: string) {
    const outletId = await this.staffOutletScope(user);
    const order = await this.prisma.order.findFirst({ where: { id, ...(outletId ? { outletId } : {}) } });
    if (!order) throw new NotFoundException('Pesanan tidak ditemukan');

    const allowed = TRANSITIONS[order.status] ?? [];
    if (!allowed.includes(next)) throw new BadRequestException(`Tidak bisa mengubah ${order.status} ke ${next}`);
    if (order.status === 'READY' && order.type === 'PICKUP' && next === 'ON_DELIVERY') {
      throw new BadRequestException('Pesanan pickup tidak bisa dikirim');
    }
    if (order.status === 'READY' && order.type === 'DELIVERY' && next === 'COMPLETED') {
      throw new BadRequestException('Pesanan delivery harus melalui ON_DELIVERY');
    }

    let courierId: string | undefined;
    let note: string | undefined;
    if (next === 'ON_DELIVERY') {
      if (!requestedCourierId) throw new BadRequestException('Pilih kurir untuk mengirim pesanan');
      const courier = await this.prisma.courier.findFirst({ where: { id: requestedCourierId, outletId: order.outletId, isActive: true } });
      if (!courier) throw new BadRequestException('Kurir tidak valid untuk outlet ini');
      courierId = courier.id;
      note = `Kurir: ${courier.name} (${courier.phone})`;
    }

    await this.prisma.$transaction(async (tx) => {
      const res = await tx.order.updateMany({
        where: { id, status: order.status },
        data: { status: next, ...(courierId ? { courierId } : {}) },
      });
      if (res.count === 0) throw new ConflictException('Status pesanan sudah berubah, muat ulang');
      await recordEvent(tx, id, next, user.id, note);
    });
    if (next === 'CANCELLED') await reversePaidOrderPoints(this.prisma, id);
    await notifyOrderStatus(this.prisma, id, next); // best-effort: tidak pernah melempar error
    if (next === 'CANCELLED') this.logger.warn(`Pesanan ${order.code} dibatalkan setelah dibayar: perlu refund manual di dashboard Midtrans`);
    return this.prisma.order.findUniqueOrThrow({ where: { id } });
  }
}
