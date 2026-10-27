import { Logger } from '@nestjs/common';
import type { PrismaClient } from '../generated/prisma/client.js';
import { buildOrderNotification, clip, type NotificationDraft } from './notifications.logic.js';

const logger = new Logger('Notifications');

/**
 * Buat satu notifikasi. Best-effort: kegagalan hanya dicatat di log dan TIDAK PERNAH dilempar,
 * supaya urusan bisnis (pembayaran, status pesanan, check-in) tidak ikut gagal karena notifikasi.
 */
export async function createNotification(
  db: Pick<PrismaClient, 'notification'>,
  userId: string,
  draft: NotificationDraft,
  orderId?: string | null,
): Promise<void> {
  try {
    await db.notification.create({ data: { userId, type: draft.type, title: clip(draft.title, 80), body: draft.body, orderId: orderId ?? null } });
  } catch (err) {
    logger.warn(`Gagal membuat notifikasi ${draft.type} untuk ${userId}: ${err instanceof Error ? err.message : err}`);
  }
}

/** Notifikasi perubahan status pesanan untuk pemiliknya. Panggil SETELAH transaksi perubahan status berhasil. */
export async function notifyOrderStatus(prisma: PrismaClient, orderId: string, status: string): Promise<void> {
  try {
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      select: { userId: true, code: true, type: true, pointsEarned: true, pointsUsed: true, courier: { select: { name: true } } },
    });
    if (!order) return;
    const draft = buildOrderNotification(status, {
      code: order.code,
      type: order.type,
      courierName: order.courier?.name,
      pointsEarned: order.pointsEarned,
      pointsUsed: order.pointsUsed,
    });
    if (draft) await createNotification(prisma, order.userId, draft, orderId);
  } catch (err) {
    logger.warn(`Gagal notifikasi status ${status} pesanan ${orderId}: ${err instanceof Error ? err.message : err}`);
  }
}
