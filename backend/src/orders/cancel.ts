import type { PrismaClient } from '../generated/prisma/client.js';
import { notifyOrderStatus } from '../notifications/notify.js';
import { recordEvent } from './events.js';

/** Batalkan pesanan yang belum dibayar; kembalikan kuota voucher dan poin yang dipakai. Aman dipanggil berulang. */
export async function cancelUnpaidOrder(
  prisma: PrismaClient,
  orderId: string,
  status: 'CANCELLED' | 'EXPIRED',
): Promise<boolean> {
  let changed = false;
  await prisma.$transaction(async (tx) => {
    const res = await tx.order.updateMany({
      where: { id: orderId, status: 'PENDING_PAYMENT' },
      data: { status },
    });
    if (res.count === 0) return;
    await recordEvent(tx, orderId, status, null, status === 'EXPIRED' ? 'Pembayaran kedaluwarsa' : 'Pembayaran gagal/dibatalkan');
    const order = await tx.order.findUniqueOrThrow({ where: { id: orderId } });
    if (order.voucherId) {
      await tx.voucher.update({ where: { id: order.voucherId }, data: { used: { decrement: 1 } } });
    }
    if (order.pointsUsed > 0) {
      await tx.user.update({ where: { id: order.userId }, data: { points: { increment: order.pointsUsed } } });
      await tx.pointLedger.create({
        data: { userId: order.userId, delta: order.pointsUsed, reason: 'REFUND_REDEEM', orderId },
      });
    }
    changed = true;
  });
  // Notifikasi dibuat setelah transaksi berhasil dan tidak pernah menggagalkannya (best-effort).
  if (changed) await notifyOrderStatus(prisma, orderId, status);
  return changed;
}

/**
 * Pembatalan pesanan yang sudah dibayar: kembalikan poin yang dipakai, tarik poin yang sempat didapat,
 * dan kurangi belanja seumur akun (penentu level).
 * Hanya dipanggil setelah transisi status ke CANCELLED berhasil (sekali per pesanan).
 */
export async function reversePaidOrderPoints(prisma: PrismaClient, orderId: string) {
  await prisma.$transaction(async (tx) => {
    const order = await tx.order.findUniqueOrThrow({ where: { id: orderId } });
    const user = await tx.user.findUniqueOrThrow({ where: { id: order.userId } });
    const revoke = Math.min(order.pointsEarned, user.points + order.pointsUsed);
    const delta = order.pointsUsed - revoke;
    if (order.pointsUsed > 0) {
      await tx.pointLedger.create({ data: { userId: user.id, delta: order.pointsUsed, reason: 'REFUND_REDEEM', orderId } });
    }
    if (revoke > 0) {
      await tx.pointLedger.create({ data: { userId: user.id, delta: -revoke, reason: 'REVOKE_EARNED', orderId } });
    }
    // Belanja seumur akun ikut berkurang (tidak pernah di bawah 0), sehingga level bisa turun bila memang tidak lagi memenuhi.
    const spendDelta = -Math.min(order.total, user.lifetimeSpend);
    if (delta !== 0 || spendDelta !== 0) {
      await tx.user.update({
        where: { id: user.id },
        data: { ...(delta !== 0 ? { points: { increment: delta } } : {}), ...(spendDelta !== 0 ? { lifetimeSpend: { increment: spendDelta } } : {}) },
      });
    }
  });
}
