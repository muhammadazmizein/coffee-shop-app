import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { cancelUnpaidOrder } from '../orders/cancel.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { PaymentsService } from './payments.service.js';
import { ORDER_PAY_WINDOW_MS, shouldSweep } from './payments.logic.js';

/**
 * Membatalkan pesanan yang tidak pernah dibayar. Berjalan tiap menit (PAYMENT_SWEEP_MS untuk uji), tidak memblok startup,
 * dan tidak pernah melempar error. Sebelum membatalkan, status terakhir ditanyakan ke Midtrans agar pembayaran
 * yang notifikasinya terlambat tidak ikut dibatalkan.
 */
@Injectable()
export class PaymentSweeper implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PaymentSweeper.name);
  private timer?: NodeJS.Timeout;
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly payments: PaymentsService,
  ) {}

  onModuleInit() {
    const every = Number(process.env.PAYMENT_SWEEP_MS) || 60_000;
    this.timer = setInterval(() => void this.sweep(), every);
    this.timer.unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  /** Mengembalikan jumlah pesanan yang dibatalkan. */
  async sweep(now = new Date()): Promise<number> {
    if (this.running) return 0;
    this.running = true;
    let cancelled = 0;
    try {
      const stale = await this.prisma.order.findMany({
        where: { status: 'PENDING_PAYMENT', createdAt: { lt: new Date(now.getTime() - ORDER_PAY_WINDOW_MS) } },
        include: { payment: { select: { expiresAt: true } } },
        take: 100,
      });
      for (const o of stale) {
        if (!shouldSweep(o.createdAt, o.payment?.expiresAt ?? null, now)) continue;
        if (o.payment) {
          await this.payments.syncPending(o.id);
          const fresh = await this.prisma.order.findUnique({ where: { id: o.id }, select: { status: true } });
          if (fresh?.status !== 'PENDING_PAYMENT') continue;
        }
        await cancelUnpaidOrder(this.prisma, o.id, 'EXPIRED');
        cancelled++;
      }
      if (cancelled > 0) this.logger.log(`${cancelled} pesanan kedaluwarsa dibatalkan`);
    } catch (err) {
      this.logger.error(`Sweep gagal: ${err instanceof Error ? err.message : err}`);
    } finally {
      this.running = false;
    }
    return cancelled;
  }
}
