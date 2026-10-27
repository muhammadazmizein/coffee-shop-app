import {
  BadGatewayException,
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { normalizePhone } from '../common/phone.js';
import { calcPointsEarned, tierFor } from '../membership/membership.logic.js';
import { createNotification, notifyOrderStatus } from '../notifications/notify.js';
import { levelUpNotification } from '../notifications/notifications.logic.js';
import { cancelUnpaidOrder } from '../orders/cancel.js';
import { recordEvent } from '../orders/events.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { MidtransService, type MidtransNotification } from './midtrans.service.js';
import {
  ORDER_PAY_WINDOW_MS,
  CHARGE_TTL_MIN,
  attemptId,
  buildChargePayload,
  buildItemDetails,
  canReuseCharge,
  deriveOrderCode,
  enabledMethods,
  mapStatus,
  methodInfo,
  methodKeyFromNotification,
  orderPayDeadline,
  parseChargeResponse,
  toPaymentView,
  type PayMethod,
  type PaymentView,
} from './payments.logic.js';


@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly midtrans: MidtransService,
  ) {}

  /** Antrean per pesanan: permintaan /pay yang bersamaan diproses berurutan, jadi yang kedua memakai charge pertama. */
  private readonly locks = new Map<string, Promise<unknown>>();

  private async withOrderLock<T>(orderId: string, fn: () => Promise<T>): Promise<T> {
    const prev = this.locks.get(orderId) ?? Promise.resolve();
    const next = prev.catch(() => undefined).then(fn);
    this.locks.set(orderId, next);
    try {
      return await next;
    } finally {
      if (this.locks.get(orderId) === next) this.locks.delete(orderId);
    }
  }

  methods() {
    return enabledMethods().map(({ key, label, group }) => ({ key, label, group }));
  }

  /**
   * Buat (atau pakai ulang) charge untuk pesanan. Satu baris Payment per pesanan, diperbarui tiap percobaan.
   * Metode sama + masih berlaku = idempoten; metode beda = charge lama dibatalkan lalu percobaan baru.
   */
  charge(userId: string, orderId: string, method: PayMethod, rawPhone?: string): Promise<PaymentView> {
    return this.withOrderLock(orderId, () => this.chargeLocked(userId, orderId, method, rawPhone));
  }

  private async chargeLocked(userId: string, orderId: string, method: PayMethod, rawPhone?: string): Promise<PaymentView> {
    if (!enabledMethods().some((m) => m.key === method)) throw new BadRequestException('Metode pembayaran tidak tersedia');

    const order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
      include: { items: true, payment: true, user: true },
    });
    if (!order) throw new NotFoundException('Pesanan tidak ditemukan');
    if (order.status !== 'PENDING_PAYMENT') throw new ConflictException('Pesanan ini sudah tidak menunggu pembayaran');

    let ovoPhone: string | undefined;
    if (method === 'ovo') {
      ovoPhone = normalizePhone(rawPhone ?? order.user.phone) ?? undefined;
      if (!ovoPhone) throw new BadRequestException('Nomor OVO tidak valid');
    }

    const now = new Date();
    const existing = order.payment;
    if (existing && canReuseCharge(existing, method, now) && (method !== 'ovo' || existing.payerPhone === ovoPhone)) {
      return toPaymentView(order.id, order.total, existing);
    }
    if (now.getTime() - order.createdAt.getTime() > ORDER_PAY_WINDOW_MS) {
      await cancelUnpaidOrder(this.prisma, order.id, 'EXPIRED');
      throw new ConflictException('Waktu pembayaran pesanan ini sudah habis, silakan pesan lagi');
    }

    // Charge lama yang masih menunggu dibatalkan agar pelanggan tidak bisa membayar dua kali.
    if (existing && existing.status === 'PENDING') await this.midtrans.cancel(existing.midtransId);

    const attempt = (existing?.attempt ?? 0) + 1;
    const midtransOrderId = attemptId(order.code, attempt);
    const payload = buildChargePayload(method, {
      midtransOrderId,
      amount: order.total,
      items: buildItemDetails(order),
      customer: { name: order.user.name, phone: order.user.phone },
      returnUrl: process.env.PAYMENT_RETURN_URL ?? 'kopiapp://payment/finish',
      ovoPhone,
    });
    const response = await this.midtrans.charge(payload);

    let parsed;
    try {
      parsed = parseChargeResponse(method, response);
    } catch (err) {
      this.logger.error(`Respons charge ${midtransOrderId} tidak bisa dipakai: ${err instanceof Error ? err.message : err}`);
      await this.midtrans.cancel(midtransOrderId);
      throw new BadGatewayException('Metode pembayaran ini sedang tidak tersedia, coba metode lain');
    }

    const data = {
      midtransId: midtransOrderId,
      attempt,
      method,
      status: 'PENDING' as const,
      amount: order.total,
      snapToken: null,
      redirectUrl: null,
      vaBank: parsed.vaBank,
      vaNumber: parsed.vaNumber,
      billerCode: parsed.billerCode,
      billKey: parsed.billKey,
      qrString: parsed.qrString,
      qrImageUrl: parsed.qrImageUrl,
      deeplinkUrl: parsed.deeplinkUrl,
      payerPhone: parsed.payerPhone ?? ovoPhone ?? null,
      expiresAt: parsed.expiresAt ?? new Date(now.getTime() + CHARGE_TTL_MIN * 60_000),
      paidAt: null,
    };

    let saved = false;
    try {
      if (existing) {
        // Hanya jika baris belum berubah (percobaan sama, belum PAID); mencegah dua permintaan bersamaan saling timpa.
        const r = await this.prisma.payment.updateMany({ where: { id: existing.id, attempt: existing.attempt, status: { not: 'PAID' } }, data });
        saved = r.count === 1;
      } else {
        await this.prisma.payment.create({ data: { ...data, orderId: order.id } });
        saved = true;
      }
    } catch (err) {
      this.logger.warn(`Simpan charge ${midtransOrderId} bentrok: ${err instanceof Error ? err.message : err}`);
    }

    if (!saved) {
      // Permintaan lain menang (atau pesanan sudah dibayar): batalkan charge kita dan kembalikan keadaan terkini.
      await this.midtrans.cancel(midtransOrderId);
      const current = await this.prisma.payment.findUnique({ where: { orderId: order.id } });
      if (!current) throw new BadGatewayException('Gagal menyimpan pembayaran, coba lagi');
      return toPaymentView(order.id, order.total, current);
    }
    const row = await this.prisma.payment.findUniqueOrThrow({ where: { orderId: order.id } });
    return toPaymentView(order.id, order.total, row);
  }

  async handleNotification(n: MidtransNotification) {
    if (!this.midtrans.verifySignature(n)) throw new UnauthorizedException('Signature tidak valid');

    let payment = await this.prisma.payment.findUnique({ where: { midtransId: n.order_id }, include: { order: true } });
    const isLatestAttempt = !!payment;
    if (!payment) {
      // Percobaan lama (sudah diganti metode lain): cari lewat kode order tanpa akhiran `-<n>`.
      const order = await this.prisma.order.findUnique({ where: { code: deriveOrderCode(n.order_id) }, include: { payment: true } });
      if (order?.payment) payment = { ...order.payment, order };
    }
    if (!payment) {
      this.logger.warn(`Notifikasi untuk order tidak dikenal: ${n.order_id}`);
      return { ok: true }; // 200 agar Midtrans tidak mengulang terus
    }
    if (Number(n.gross_amount) !== payment.order.total) {
      this.logger.error(`Nominal tidak cocok untuk ${n.order_id}: ${n.gross_amount} vs ${payment.order.total}`);
      throw new BadRequestException('Nominal tidak cocok');
    }

    const outcome = mapStatus(n);
    if (outcome === 'PAID') {
      // Uang masuk dari percobaan mana pun menandai pesanan dibayar.
      const key = isLatestAttempt ? (payment.method ?? methodKeyFromNotification(n)) : (methodKeyFromNotification(n) ?? payment.method);
      const paid = await this.markPaid(payment.id, payment.orderId, payment.order.userId, payment.order.total, key);
      const claimed = paid.claimed;
      if (paid.moved) {
        await notifyOrderStatus(this.prisma, payment.orderId, 'PAID');
        if (paid.levelUp) await createNotification(this.prisma, payment.order.userId, levelUpNotification(paid.levelUp));
      }
      if (claimed && !isLatestAttempt && payment.status === 'PENDING') await this.midtrans.cancel(payment.midtransId);
    } else if (isLatestAttempt && (outcome === 'FAILED' || outcome === 'EXPIRED') && payment.status !== 'PAID') {
      // Hanya percobaan terbaru yang menentukan. Pesanan tetap menunggu bayar agar pelanggan bisa memilih metode lain;
      // pembatalan terjadi saat batas waktu pesanan habis.
      await this.prisma.payment.updateMany({ where: { id: payment.id, status: { not: 'PAID' } }, data: { status: outcome } });
      if (orderPayDeadline(payment.order.createdAt, payment.expiresAt).getTime() <= Date.now()) {
        await cancelUnpaidOrder(this.prisma, payment.orderId, 'EXPIRED');
      }
    }
    return { ok: true };
  }

  /** Rekonsiliasi: tanya Midtrans untuk charge terbaru pesanan yang masih menunggu bayar. Tidak pernah melempar error. */
  async syncPending(orderId: string) {
    try {
      const payment = await this.prisma.payment.findUnique({ where: { orderId }, select: { midtransId: true } });
      if (!payment) return;
      const status = await this.midtrans.getStatus(payment.midtransId);
      if (status) await this.handleNotification(status);
    } catch (err) {
      this.logger.warn(`Sinkronisasi status pesanan ${orderId} gagal: ${err instanceof Error ? err.message : err}`);
    }
  }

  /**
   * Idempoten: notifikasi settlement yang dikirim berulang hanya diproses sekali.
   * claimed = kali ini yang menandai lunas; moved = pesanan benar-benar berpindah ke PAID; levelUp = nama level baru bila pembayaran menaikkan level.
   */
  private async markPaid(
    paymentId: string,
    orderId: string,
    userId: string,
    total: number,
    method?: string | null,
  ): Promise<{ claimed: boolean; moved: boolean; levelUp: string | null }> {
    return this.prisma.$transaction(async (tx) => {
      const claimed = await tx.payment.updateMany({
        where: { id: paymentId, status: { not: 'PAID' } },
        data: { status: 'PAID', paidAt: new Date(), ...(method ? { method } : {}) },
      });
      if (claimed.count === 0) return { claimed: false, moved: false, levelUp: null };

      const moved = await tx.order.updateMany({
        where: { id: orderId, status: 'PENDING_PAYMENT' },
        data: { status: 'PAID' },
      });
      if (moved.count === 0) {
        this.logger.error(`Pembayaran masuk untuk order ${orderId} yang sudah tidak PENDING_PAYMENT: cek refund manual`);
        return { claimed: true, moved: false, levelUp: null };
      }

      await recordEvent(tx, orderId, 'PAID', null, method ? `Dibayar via ${methodInfo(method)?.label ?? method}` : 'Dibayar');

      // Pengali poin memakai snapshot level saat pesanan dibuat. Belanja seumur akun (penentu level) ikut bertambah,
      // di transaksi yang sama dengan klaim pembayaran sehingga notifikasi ganda tidak menghitungnya dua kali.
      const order = await tx.order.findUniqueOrThrow({ where: { id: orderId }, select: { earnMultiplierPct: true, total: true } });
      const points = calcPointsEarned(order.total, order.earnMultiplierPct);
      if (points > 0) {
        await tx.order.update({ where: { id: orderId }, data: { pointsEarned: points } });
        await tx.pointLedger.create({ data: { userId, delta: points, reason: 'ORDER', orderId } });
      }
      const before = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { lifetimeSpend: true } });
      await tx.user.update({ where: { id: userId }, data: { lifetimeSpend: { increment: order.total }, ...(points > 0 ? { points: { increment: points } } : {}) } });
      const tiers = await tx.tier.findMany();
      const from = tierFor(tiers, before.lifetimeSpend);
      const to = tierFor(tiers, before.lifetimeSpend + order.total);
      return { claimed: true, moved: true, levelUp: to.minSpend > from.minSpend ? to.name : null };
    });
  }
}
