export interface DeliveryRule {
  baseFee: number; // tarif sampai baseKm
  baseKm: number;
  perKmFee: number; // tambahan per km (dibulatkan ke atas) setelah baseKm
}

/** Ongkir mengikuti aturan outlet: tarif dasar sampai baseKm, lalu tambahan per km. */
export function calcDeliveryFee(km: number, rule: DeliveryRule): number {
  if (km <= rule.baseKm) return rule.baseFee;
  return rule.baseFee + Math.ceil(km - rule.baseKm) * rule.perKmFee;
}

export interface VoucherRule {
  type: 'PERCENT' | 'FIXED';
  value: number;
  minSpend: number;
  maxDiscount: number | null;
}

/** Diskon voucher; tidak pernah melebihi subtotal. Mengembalikan 0 jika minimum belanja belum terpenuhi. */
export function calcDiscount(v: VoucherRule, subtotal: number): number {
  if (subtotal < v.minSpend) return 0;
  let discount = v.type === 'PERCENT' ? Math.floor((subtotal * v.value) / 100) : v.value;
  if (v.maxDiscount != null) discount = Math.min(discount, v.maxDiscount);
  return Math.min(discount, subtotal);
}

/** Jam sekarang di zona waktu Jakarta (0-23). */
export function jakartaHour(now = new Date()): number {
  return Number(
    new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Jakarta', hour: '2-digit', hour12: false }).format(now),
  ) % 24;
}

export function isOutletOpen(openHour: number, closeHour: number, now = new Date()): boolean {
  const h = jakartaHour(now);
  return openHour <= closeHour ? h >= openHour && h < closeHour : h >= openHour || h < closeHour;
}

export const POINT_VALUE = 100; // 1 poin = Rp100
export const POINT_MAX_SHARE = 0.5; // maksimal 50% dari belanja (setelah voucher) boleh dibayar poin

/** Poin yang benar-benar dipakai: dibatasi saldo, kebutuhan, dan batas 50%. */
export function calcPointRedemption(requested: number, balance: number, base: number) {
  const cap = Math.floor((base * POINT_MAX_SHARE) / POINT_VALUE);
  const pointsUsed = Math.max(0, Math.min(requested, balance, cap));
  return { pointsUsed, pointDiscount: pointsUsed * POINT_VALUE };
}

/** Diskon voucher setelah diskon member: minimum belanja diuji terhadap subtotal ASLI, nilainya dihitung dari subtotal - diskon member. */
export function calcVoucherDiscount(v: VoucherRule, subtotal: number, memberDiscount: number): number {
  if (subtotal < v.minSpend) return 0;
  return calcDiscount({ ...v, minSpend: 0 }, subtotal - memberDiscount);
}

export interface TotalsInput {
  subtotal: number;
  memberDiscount: number;
  voucher: VoucherRule | null;
  usePoints: number;
  pointsBalance: number;
  deliveryFee: number;
}

/**
 * Urutan harga: subtotal -> diskon member -> voucher -> tukar poin -> ongkir.
 * Semua bilangan bulat rupiah; total tidak pernah negatif.
 */
export function calcTotals(i: TotalsInput) {
  const afterMember = i.subtotal - i.memberDiscount;
  const discount = i.voucher ? calcVoucherDiscount(i.voucher, i.subtotal, i.memberDiscount) : 0;
  const afterVoucher = afterMember - discount;
  const { pointsUsed, pointDiscount } = i.usePoints > 0 ? calcPointRedemption(i.usePoints, i.pointsBalance, afterVoucher) : { pointsUsed: 0, pointDiscount: 0 };
  const total = Math.max(0, afterVoucher - pointDiscount + i.deliveryFee);
  return { memberDiscount: i.memberDiscount, discount, pointsUsed, pointDiscount, total };
}
