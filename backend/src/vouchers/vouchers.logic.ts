export interface VoucherWindow {
  isActive: boolean;
  startsAt: Date;
  endsAt: Date;
  quota: number; // 0 = tanpa batas
  used: number;
}

/** Sisa kuota; null bila tanpa batas. */
export function voucherRemaining(quota: number, used: number): number | null {
  return quota > 0 ? Math.max(0, quota - used) : null;
}

/** Voucher bisa dipakai sekarang: aktif, dalam periode, dan kuota belum habis. */
export function isVoucherAvailable(v: VoucherWindow, now = new Date()): boolean {
  if (!v.isActive || v.startsAt > now || v.endsAt < now) return false;
  const remaining = voucherRemaining(v.quota, v.used);
  return remaining === null || remaining > 0;
}
