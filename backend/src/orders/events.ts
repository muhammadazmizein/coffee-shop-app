import type { OrderStatus, PrismaClient } from '../generated/prisma/client.js';

/** Catat perubahan status pesanan. Panggil di dalam transaksi yang sama dengan perubahan statusnya. */
export function recordEvent(
  db: Pick<PrismaClient, 'orderEvent'>,
  orderId: string,
  status: OrderStatus,
  actorId?: string | null,
  note?: string | null,
) {
  return db.orderEvent.create({ data: { orderId, status, actorId: actorId ?? null, note: note ?? null } });
}
