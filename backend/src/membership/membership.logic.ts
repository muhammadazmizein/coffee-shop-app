/** Logika murni level member (tanpa akses database) agar mudah diuji. */

export interface TierRule {
  id: string;
  name: string;
  minSpend: number;
  earnMultiplierPct: number; // 100 = 1,0x
  discountPct: number; // 0-50
  maxDiscount: number | null; // batas diskon per pesanan; null = tanpa batas
  sort: number;
}

/** Cadangan bila tabel Tier kosong (salah konfigurasi): tanpa diskon, poin normal. */
export const FALLBACK_TIER: TierRule = {
  id: 'fallback',
  name: 'Member',
  minSpend: 0,
  earnMultiplierPct: 100,
  discountPct: 0,
  maxDiscount: null,
  sort: 0,
};

export const sortTiers = <T extends { minSpend: number }>(tiers: T[]): T[] => [...tiers].sort((a, b) => a.minSpend - b.minSpend);

/** Level = tier dengan minSpend terbesar yang <= belanja seumur akun. */
export function tierFor(tiers: TierRule[], lifetimeSpend: number): TierRule {
  const sorted = sortTiers(tiers);
  if (sorted.length === 0) return FALLBACK_TIER;
  let current = sorted[0];
  for (const t of sorted) if (t.minSpend <= lifetimeSpend) current = t;
  return current;
}

export function nextTierOf(tiers: TierRule[], current: TierRule): TierRule | null {
  return sortTiers(tiers).find((t) => t.minSpend > current.minSpend) ?? null;
}

export function membershipProgress(tiers: TierRule[], lifetimeSpend: number) {
  const spend = Math.max(0, lifetimeSpend);
  const current = tierFor(tiers, spend);
  const next = nextTierOf(tiers, current);
  if (!next) return { current, next: null, remainingToNext: null, progressPct: 100 };
  const span = next.minSpend - current.minSpend;
  const pct = Math.floor(((spend - current.minSpend) / span) * 100);
  return { current, next, remainingToNext: next.minSpend - spend, progressPct: Math.min(99, Math.max(0, pct)) };
}

/** Diskon member per pesanan: persen dari subtotal (dibulatkan ke bawah), dibatasi maxDiscount, tak melebihi subtotal. */
export function calcMemberDiscount(tier: Pick<TierRule, 'discountPct' | 'maxDiscount'>, subtotal: number): number {
  if (subtotal <= 0 || tier.discountPct <= 0) return 0;
  let d = Math.floor((subtotal * tier.discountPct) / 100);
  if (tier.maxDiscount != null) d = Math.min(d, tier.maxDiscount);
  return Math.max(0, Math.min(d, subtotal));
}

/** Poin yang didapat: floor(total / 10.000 x pengali%), dihitung dengan bilangan bulat agar tak terkena error pecahan. */
export function calcPointsEarned(total: number, earnMultiplierPct: number): number {
  if (total <= 0) return 0;
  return Math.floor((total * earnMultiplierPct) / 1_000_000);
}

// ---------- Validasi konfigurasi level (admin) ----------

export interface TierInput {
  name: string;
  minSpend: number;
  earnMultiplierPct: number;
  discountPct: number;
  maxDiscount?: number | null;
}

export const MAX_TIERS = 6;

/** Mengembalikan pesan kesalahan (Indonesia) atau null bila konfigurasi valid. Pemeriksaan lintas-baris. */
export function validateTierSet(tiers: TierInput[]): string | null {
  if (tiers.length < 1 || tiers.length > MAX_TIERS) return `Jumlah level harus 1-${MAX_TIERS}`;
  const names = new Set<string>();
  for (const t of tiers) {
    const name = t.name.trim();
    if (!name) return 'Nama level tidak boleh kosong';
    if (name.length > 20) return `Nama level "${name}" maksimal 20 karakter`;
    const key = name.toLowerCase();
    if (names.has(key)) return `Nama level "${name}" dipakai dua kali`;
    names.add(key);
  }
  if (tiers[0].minSpend !== 0) return 'Level pertama harus dimulai dari belanja Rp0';
  for (let i = 1; i < tiers.length; i++) {
    if (tiers[i].minSpend <= tiers[i - 1].minSpend) {
      return `Minimal belanja level "${tiers[i].name.trim()}" harus lebih besar dari level sebelumnya`;
    }
  }
  return null;
}
