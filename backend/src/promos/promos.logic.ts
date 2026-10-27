/** Kunci ilustrasi bawaan app yang boleh dipakai slide promo (harus ada di aset mobile/assets/illustrations). */
export const PROMO_ART_KEYS = [
  'onboarding_1',
  'onboarding_2',
  'onboarding_3',
  'product_latte',
  'product_matcha',
  'product_chocolate',
  'product_croissant',
  'product_donut',
  'product_boba',
] as const;

export const WELCOME_MAX = 8;

export interface PromoWindow {
  isActive: boolean;
  startsAt: Date | null;
  endsAt: Date | null;
}

/** Promo tayang sekarang: aktif dan di dalam periode (batas kosong = tanpa batas). */
export function isPromoLive(p: PromoWindow, now = new Date()): boolean {
  if (!p.isActive) return false;
  if (p.startsAt && p.startsAt > now) return false;
  if (p.endsAt && p.endsAt < now) return false;
  return true;
}

/**
 * Slide welcome: promo yang tayang; promo ber-voucher hanya bila vouchernya masih bisa dipakai,
 * supaya app tidak mempromosikan kode yang sudah mati. Urutan input dipertahankan (sudah diurutkan oleh pemanggil).
 */
export function selectWelcomePromos<T extends PromoWindow & { voucherCode: string | null }>(
  promos: T[],
  availableVoucherCodes: ReadonlySet<string>,
  now = new Date(),
  max = WELCOME_MAX,
): T[] {
  return promos
    .filter((p) => isPromoLive(p, now) && (!p.voucherCode || availableVoucherCodes.has(p.voucherCode)))
    .slice(0, max);
}

/** Susun ulang urutan: tukar item `id` dengan tetangganya, lalu beri nomor rapi (10, 20, 30...) agar tidak ada nilai kembar. */
export function moveInOrder(ids: string[], id: string, direction: 'up' | 'down'): { id: string; sort: number }[] | null {
  const i = ids.indexOf(id);
  if (i < 0) return null;
  const j = direction === 'up' ? i - 1 : i + 1;
  const next = [...ids];
  if (j >= 0 && j < next.length) [next[i], next[j]] = [next[j], next[i]];
  return next.map((x, k) => ({ id: x, sort: (k + 1) * 10 }));
}
