import { BadRequestException, Controller, Get, Header, NotFoundException, Param, Query, UseGuards } from '@nestjs/common';
import { IsNumberString, IsOptional, IsString, MaxLength } from 'class-validator';
import { CurrentUser, JwtAuthGuard, Roles, RolesGuard } from '../common/auth.js';
import type { AuthUser } from '../common/auth.js';
import { outletScope } from '../common/scope.js';
import { Prisma } from '../generated/prisma/client.js';
import type { OrderStatus } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

/** Status yang dihitung sebagai penjualan: sudah dibayar dan tidak dibatalkan. */
const SALES_STATUSES: OrderStatus[] = ['PAID', 'PREPARING', 'READY', 'ON_DELIVERY', 'COMPLETED'];
const ALL_STATUSES: OrderStatus[] = [...SALES_STATUSES, 'PENDING_PAYMENT', 'CANCELLED', 'EXPIRED'];
const WIB_OFFSET_MS = 7 * 3600_000;
const DAY_MS = 86_400_000;
const MAX_RANGE_DAYS = 366;
const EXPORT_LIMIT = 5000;

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** 'YYYY-MM-DD' (hari WIB) -> awal hari itu sebagai instant UTC. */
function wibDayStart(day: string): Date {
  if (!DATE_RE.test(day)) throw new BadRequestException('Format tanggal harus YYYY-MM-DD');
  const d = new Date(`${day}T00:00:00+07:00`);
  if (Number.isNaN(d.getTime())) throw new BadRequestException('Tanggal tidak valid');
  return d;
}

const wibDayString = (d: Date) => new Date(d.getTime() + WIB_OFFSET_MS).toISOString().slice(0, 10);

/** Rentang [from, to) dalam UTC; default 7 hari terakhir (termasuk hari ini, WIB). */
function parseRange(from?: string, to?: string) {
  const today = wibDayString(new Date());
  const start = wibDayStart(from ?? wibDayString(new Date(Date.now() - 6 * DAY_MS)));
  const end = new Date(wibDayStart(to ?? today).getTime() + DAY_MS);
  if (end <= start) throw new BadRequestException('Tanggal akhir harus sama atau setelah tanggal awal');
  if ((end.getTime() - start.getTime()) / DAY_MS > MAX_RANGE_DAYS) {
    throw new BadRequestException(`Rentang maksimal ${MAX_RANGE_DAYS} hari`);
  }
  return { start, end };
}

const num = (v: unknown) => Number(v ?? 0);

/** Hindari formula injection saat CSV dibuka di Excel/Sheets: sel berawalan = + - @ diberi tanda kutip. */
function csvCell(v: unknown): string {
  let s = v == null ? '' : String(v);
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

class OrderFilter {
  @IsOptional() @IsString() @MaxLength(10) from?: string;
  @IsOptional() @IsString() @MaxLength(10) to?: string;
  @IsOptional() @IsString() @MaxLength(20) status?: string;
  @IsOptional() @IsString() @MaxLength(20) type?: string;
  @IsOptional() @IsString() @MaxLength(40) outletId?: string;
  @IsOptional() @IsString() @MaxLength(60) q?: string;
  @IsOptional() @IsNumberString() page?: string;
  @IsOptional() @IsNumberString() pageSize?: string;
}

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('STAFF', 'ADMIN')
export class ReportsController {
  constructor(private readonly prisma: PrismaService) {}

  private async where(user: AuthUser, f: OrderFilter) {
    const scope = await outletScope(this.prisma, user);
    const { start, end } = parseRange(f.from, f.to);
    if (f.status && !ALL_STATUSES.includes(f.status as OrderStatus)) throw new BadRequestException('Status tidak valid');
    if (f.type && f.type !== 'PICKUP' && f.type !== 'DELIVERY') throw new BadRequestException('Tipe tidak valid');
    const q = f.q?.trim();
    const where: Prisma.OrderWhereInput = {
      createdAt: { gte: start, lt: end },
      ...(scope ?? f.outletId ? { outletId: scope ?? f.outletId } : {}),
      ...(f.status ? { status: f.status as OrderStatus } : {}),
      ...(f.type ? { type: f.type as 'PICKUP' | 'DELIVERY' } : {}),
      ...(q
        ? { OR: [{ code: { contains: q } }, { user: { phone: { contains: q.replace(/\D/g, '') || q } } }, { user: { name: { contains: q } } }] }
        : {}),
    };
    return { where, scope, start, end };
  }

  @Get('orders')
  async list(@CurrentUser() user: AuthUser, @Query() f: OrderFilter) {
    const { where } = await this.where(user, f);
    const pageSize = Math.min(Math.max(Number(f.pageSize) || 25, 1), 100);
    const page = Math.max(Number(f.page) || 1, 1);
    const [total, items, sum] = await Promise.all([
      this.prisma.order.count({ where }),
      this.prisma.order.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
        select: {
          id: true, code: true, type: true, status: true, total: true, createdAt: true,
          outlet: { select: { name: true } },
          user: { select: { name: true, phone: true } },
          payment: { select: { method: true } },
        },
      }),
      // Total penjualan hanya menghitung pesanan terbayar; filter status non-penjualan (batal, kedaluwarsa) menghasilkan 0.
      f.status && !SALES_STATUSES.includes(f.status as OrderStatus)
        ? null
        : this.prisma.order.aggregate({ where: { ...where, status: f.status ? (f.status as OrderStatus) : { in: SALES_STATUSES } }, _sum: { total: true } }),
    ]);
    return { items, total, page, pageSize, salesTotal: sum?._sum.total ?? 0 };
  }

  @Get('orders/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  async exportCsv(@CurrentUser() user: AuthUser, @Query() f: OrderFilter) {
    const { where } = await this.where(user, f);
    const rows = await this.prisma.order.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: EXPORT_LIMIT,
      include: {
        outlet: { select: { name: true } },
        user: { select: { name: true, phone: true } },
        payment: { select: { method: true } },
        courier: { select: { name: true } },
      },
    });
    const header = ['Kode', 'Waktu (WIB)', 'Outlet', 'Tipe', 'Status', 'Pelanggan', 'Telepon', 'Subtotal', 'Diskon', 'Diskon member', 'Poin dipakai', 'Ongkir', 'Total', 'Metode bayar', 'Kurir'];
    const lines = rows.map((o) =>
      [
        o.code,
        new Date(o.createdAt.getTime() + WIB_OFFSET_MS).toISOString().replace('T', ' ').slice(0, 19),
        o.outlet.name, o.type, o.status, o.user.name ?? '', o.user.phone,
        o.subtotal, o.discount, o.memberDiscount, o.pointsUsed, o.deliveryFee, o.total,
        o.payment?.method ?? '', o.courier?.name ?? '',
      ].map(csvCell).join(','),
    );
    return '﻿' + [header.join(','), ...lines].join('\r\n');
  }

  @Get('orders/:id')
  async detail(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const scope = await outletScope(this.prisma, user);
    const order = await this.prisma.order.findFirst({
      where: { id, ...(scope ? { outletId: scope } : {}) },
      include: {
        items: true,
        outlet: { select: { name: true } },
        user: { select: { name: true, phone: true } },
        address: true,
        courier: { select: { name: true, phone: true } },
        payment: { select: { status: true, method: true, paidAt: true, midtransId: true } },
        voucher: { select: { code: true } },
        events: { orderBy: { createdAt: 'asc' } },
      },
    });
    if (!order) throw new NotFoundException('Pesanan tidak ditemukan');

    // Nama pelaku perubahan status (staff/admin) agar riwayat bisa dibaca.
    const actorIds = [...new Set(order.events.map((e) => e.actorId).filter((x): x is string => !!x))];
    const actors = await this.prisma.user.findMany({ where: { id: { in: actorIds } }, select: { id: true, name: true, phone: true, role: true } });
    const byId = new Map(actors.map((a) => [a.id, a]));
    return {
      ...order,
      events: order.events.map((e) => ({
        status: e.status,
        note: e.note,
        createdAt: e.createdAt,
        actor: e.actorId ? (({ name, phone, role }) => ({ name: name ?? phone, role }))(byId.get(e.actorId) ?? { name: null, phone: '-', role: 'CUSTOMER' }) : null,
      })),
    };
  }

  @Get('reports/summary')
  async summary(@CurrentUser() user: AuthUser, @Query() f: OrderFilter) {
    const scope = await outletScope(this.prisma, user);
    const { start, end } = parseRange(f.from, f.to);
    const outletId = scope ?? (f.outletId || undefined);

    const paid = Prisma.join(SALES_STATUSES);
    const outletSql = outletId ? Prisma.sql`AND o.outletId = ${outletId}` : Prisma.empty;
    const base = Prisma.sql`o.createdAt >= ${start} AND o.createdAt < ${end} AND o.status IN (${paid}) ${outletSql}`;
    const wib = Prisma.sql`CONVERT_TZ(o.createdAt, '+00:00', '+07:00')`;

    const [totals, daily, hourly, byType, byOutlet, byPayment, topProducts, statusCounts] = await Promise.all([
      this.prisma.$queryRaw<Record<string, unknown>[]>`
        SELECT COUNT(*) AS orders, COALESCE(SUM(o.total),0) AS revenue, COALESCE(SUM(o.discount),0) AS discount, COALESCE(SUM(o.memberDiscount),0) AS memberDiscount,
               COALESCE(SUM(o.deliveryFee),0) AS deliveryFees, COALESCE(SUM(o.pointsUsed),0) AS pointsUsed
        FROM \`Order\` o WHERE ${base}`,
      this.prisma.$queryRaw<{ d: Date; orders: bigint; revenue: unknown }[]>`
        SELECT DATE(${wib}) AS d, COUNT(*) AS orders, SUM(o.total) AS revenue
        FROM \`Order\` o WHERE ${base} GROUP BY d ORDER BY d`,
      this.prisma.$queryRaw<{ h: number; orders: bigint }[]>`
        SELECT HOUR(${wib}) AS h, COUNT(*) AS orders FROM \`Order\` o WHERE ${base} GROUP BY h ORDER BY h`,
      this.prisma.$queryRaw<{ k: string; orders: bigint; revenue: unknown }[]>`
        SELECT o.type AS k, COUNT(*) AS orders, SUM(o.total) AS revenue FROM \`Order\` o WHERE ${base} GROUP BY o.type`,
      this.prisma.$queryRaw<{ k: string; orders: bigint; revenue: unknown }[]>`
        SELECT t.name AS k, COUNT(*) AS orders, SUM(o.total) AS revenue
        FROM \`Order\` o JOIN \`Outlet\` t ON t.id = o.outletId WHERE ${base} GROUP BY t.name ORDER BY revenue DESC`,
      this.prisma.$queryRaw<{ k: string; orders: bigint; revenue: unknown }[]>`
        SELECT COALESCE(p.method, 'tidak diketahui') AS k, COUNT(*) AS orders, SUM(o.total) AS revenue
        FROM \`Order\` o LEFT JOIN \`Payment\` p ON p.orderId = o.id WHERE ${base} GROUP BY k ORDER BY revenue DESC`,
      this.prisma.$queryRaw<{ name: string; qty: unknown; revenue: unknown }[]>`
        SELECT i.name AS name, SUM(i.qty) AS qty, SUM(i.qty * i.unitPrice) AS revenue
        FROM \`OrderItem\` i JOIN \`Order\` o ON o.id = i.orderId WHERE ${base}
        GROUP BY i.name ORDER BY qty DESC, revenue DESC LIMIT 10`,
      this.prisma.order.groupBy({
        by: ['status'],
        where: { createdAt: { gte: start, lt: end }, ...(outletId ? { outletId } : {}) },
        _count: { _all: true },
      }),
    ]);

    // Isi hari tanpa penjualan dengan 0 agar grafik tidak melompat.
    const dayMap = new Map(daily.map((r) => [new Date(r.d).toISOString().slice(0, 10), r]));
    const days: { date: string; orders: number; revenue: number }[] = [];
    for (let t = start.getTime(); t < end.getTime(); t += DAY_MS) {
      const key = wibDayString(new Date(t));
      const r = dayMap.get(key);
      days.push({ date: key, orders: num(r?.orders), revenue: num(r?.revenue) });
    }

    const t = totals[0] ?? {};
    const orders = num(t.orders);
    const revenue = num(t.revenue);
    const statusMap = new Map(statusCounts.map((s) => [s.status, s._count._all]));
    const group = (rows: { k: string; orders: bigint; revenue: unknown }[]) =>
      rows.map((r) => ({ key: r.k, orders: num(r.orders), revenue: num(r.revenue) }));

    return {
      range: { from: wibDayString(start), to: wibDayString(new Date(end.getTime() - DAY_MS)) },
      totals: {
        orders,
        revenue,
        avgOrder: orders ? Math.round(revenue / orders) : 0,
        discount: num(t.discount),
        memberDiscount: num(t.memberDiscount),
        deliveryFees: num(t.deliveryFees),
        pointsRedeemed: num(t.pointsUsed),
      },
      daily: days,
      hourly: Array.from({ length: 24 }, (_, h) => ({ hour: h, orders: num(hourly.find((x) => x.h === h)?.orders) })),
      byType: group(byType),
      byOutlet: group(byOutlet),
      byPayment: group(byPayment),
      topProducts: topProducts.map((p) => ({ name: p.name, qty: num(p.qty), revenue: num(p.revenue) })),
      byStatus: ALL_STATUSES.map((s) => ({ status: s, count: statusMap.get(s) ?? 0 })),
    };
  }
}
