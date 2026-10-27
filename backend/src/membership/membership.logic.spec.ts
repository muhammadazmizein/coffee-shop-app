import { describe, expect, it } from 'vitest';
import { calcTotals, calcVoucherDiscount } from '../orders/pricing.js';
import {
  calcMemberDiscount,
  calcPointsEarned,
  FALLBACK_TIER,
  membershipProgress,
  tierFor,
  validateTierSet,
  type TierRule,
} from './membership.logic.js';

const T = (name: string, minSpend: number, earnMultiplierPct: number, discountPct: number, maxDiscount: number | null, sort: number): TierRule => ({ id: name, name, minSpend, earnMultiplierPct, discountPct, maxDiscount, sort });
const TIERS = [T('Member', 0, 100, 0, null, 0), T('Silver', 500_000, 125, 3, 10_000, 1), T('Gold', 2_000_000, 150, 5, 15_000, 2), T('Platinum', 5_000_000, 200, 8, 25_000, 3)];

describe('tierFor', () => {
  it('memilih tier dengan minSpend terbesar yang <= belanja', () => {
    expect(tierFor(TIERS, 0).name).toBe('Member');
    expect(tierFor(TIERS, 499_999).name).toBe('Member');
    expect(tierFor(TIERS, 500_000).name).toBe('Silver');
    expect(tierFor(TIERS, 1_999_999).name).toBe('Silver');
    expect(tierFor(TIERS, 2_000_000).name).toBe('Gold');
    expect(tierFor(TIERS, 99_000_000).name).toBe('Platinum');
  });
  it('urutan input tidak memengaruhi hasil', () => {
    expect(tierFor([...TIERS].reverse(), 2_500_000).name).toBe('Gold');
  });
  it('tabel kosong memakai tier cadangan tanpa diskon', () => {
    expect(tierFor([], 10_000_000)).toBe(FALLBACK_TIER);
    expect(FALLBACK_TIER.discountPct).toBe(0);
  });
});

describe('membershipProgress', () => {
  it('progres menuju level berikutnya', () => {
    const p = membershipProgress(TIERS, 1_250_000); // Silver: 500rb -> 2jt, sudah 750rb dari 1,5jt = 50%
    expect(p.current.name).toBe('Silver');
    expect(p.next?.name).toBe('Gold');
    expect(p.remainingToNext).toBe(750_000);
    expect(p.progressPct).toBe(50);
  });
  it('level tertinggi: tanpa next dan 100%', () => {
    const p = membershipProgress(TIERS, 6_000_000);
    expect(p.next).toBeNull();
    expect(p.remainingToNext).toBeNull();
    expect(p.progressPct).toBe(100);
  });
  it('tidak pernah menampilkan 100% sebelum benar-benar naik level', () => {
    expect(membershipProgress(TIERS, 1_999_999).progressPct).toBe(99);
    expect(membershipProgress(TIERS, 0).progressPct).toBe(0);
  });
  it('belanja negatif diperlakukan sebagai 0', () => {
    expect(membershipProgress(TIERS, -50).current.name).toBe('Member');
  });
});

describe('calcMemberDiscount', () => {
  const gold = TIERS[2];
  it('persen dibulatkan ke bawah', () => {
    expect(calcMemberDiscount(gold, 33_333)).toBe(1_666); // 1666,65
    expect(calcMemberDiscount(T('X', 0, 100, 3, null, 0), 99)).toBe(2); // 2,97
  });
  it('dibatasi maxDiscount', () => {
    expect(calcMemberDiscount(gold, 1_000_000)).toBe(15_000);
  });
  it('maxDiscount null = tanpa batas; level tanpa diskon = 0', () => {
    expect(calcMemberDiscount(T('X', 0, 100, 10, null, 0), 1_000_000)).toBe(100_000);
    expect(calcMemberDiscount(TIERS[0], 1_000_000)).toBe(0);
  });
  it('tidak pernah melebihi subtotal atau negatif', () => {
    expect(calcMemberDiscount(T('X', 0, 100, 50, 999_999, 0), 1_000)).toBe(500);
    expect(calcMemberDiscount(gold, 0)).toBe(0);
    expect(calcMemberDiscount(gold, -10)).toBe(0);
  });
});

describe('calcPointsEarned', () => {
  it('pengali 1,0x = 1 poin per Rp10.000', () => {
    expect(calcPointsEarned(46_800, 100)).toBe(4);
    expect(calcPointsEarned(9_999, 100)).toBe(0);
  });
  it('pengali dipakai dengan pembulatan ke bawah', () => {
    expect(calcPointsEarned(46_800, 150)).toBe(7); // 7,02
    expect(calcPointsEarned(100_000, 125)).toBe(12); // 12,5
    expect(calcPointsEarned(100_000, 200)).toBe(20);
  });
  it('tidak terkena kesalahan pecahan untuk nilai pas', () => {
    expect(calcPointsEarned(30_000, 100)).toBe(3);
    expect(calcPointsEarned(70_000, 150)).toBe(10); // 10,5
    expect(calcPointsEarned(0, 200)).toBe(0);
  });
});

describe('urutan harga: member -> voucher -> poin -> ongkir', () => {
  const hemat10 = { type: 'PERCENT' as const, value: 10, minSpend: 30_000, maxDiscount: 15_000 };

  it('voucher menguji minimum pada subtotal asli, nilainya dari subtotal setelah diskon member', () => {
    // subtotal 31.000, diskon member 5% = 1.550 -> subtotal setelah member 29.450 (< min 30.000) tetap lolos
    expect(calcVoucherDiscount(hemat10, 31_000, 1_550)).toBe(2_945); // 10% dari 29.450
    expect(calcVoucherDiscount(hemat10, 29_999, 0)).toBe(0); // di bawah minimum asli
  });

  it('semua potongan + ongkir, cocok hitungan manual', () => {
    // subtotal 100.000; Gold 5% = 5.000; voucher 10% dari 95.000 = 9.500; basis poin 85.500, maks 50% = 42.750 -> 427 poin
    // minta 100 poin (saldo 1000) -> 10.000; total = 85.500 - 10.000 + 8.000 = 83.500
    const r = calcTotals({ subtotal: 100_000, memberDiscount: 5_000, voucher: hemat10, usePoints: 100, pointsBalance: 1_000, deliveryFee: 8_000 });
    expect(r).toEqual({ memberDiscount: 5_000, discount: 9_500, pointsUsed: 100, pointDiscount: 10_000, total: 83_500 });
  });

  it('basis tukar poin adalah subtotal - member - voucher (batas 50%)', () => {
    const r = calcTotals({ subtotal: 20_000, memberDiscount: 1_000, voucher: null, usePoints: 100_000, pointsBalance: 100_000, deliveryFee: 0 });
    // basis 19.000 -> maks 9.500 = 95 poin
    expect(r.pointsUsed).toBe(95);
    expect(r.total).toBe(9_500);
  });

  it('total tidak pernah negatif', () => {
    const fixed = { type: 'FIXED' as const, value: 1_000_000, minSpend: 0, maxDiscount: null };
    const r = calcTotals({ subtotal: 10_000, memberDiscount: 10_000, voucher: fixed, usePoints: 500, pointsBalance: 500, deliveryFee: 0 });
    expect(r.total).toBe(0);
    expect(r.discount).toBe(0);
  });

  it('tanpa voucher/poin/diskon member = subtotal + ongkir', () => {
    expect(calcTotals({ subtotal: 26_000, memberDiscount: 0, voucher: null, usePoints: 0, pointsBalance: 0, deliveryFee: 8_000 }).total).toBe(34_000);
  });
});

describe('validateTierSet', () => {
  const ok = [{ name: 'Member', minSpend: 0, earnMultiplierPct: 100, discountPct: 0 }, { name: 'Gold', minSpend: 100, earnMultiplierPct: 150, discountPct: 5, maxDiscount: 1000 }];
  it('konfigurasi valid', () => expect(validateTierSet(ok)).toBeNull());
  it('1 level saja boleh', () => expect(validateTierSet([ok[0]])).toBeNull());
  it('0 atau lebih dari 6 level ditolak', () => {
    expect(validateTierSet([])).toMatch(/1-6/);
    expect(validateTierSet(Array.from({ length: 7 }, (_, i) => ({ name: `L${i}`, minSpend: i * 10, earnMultiplierPct: 100, discountPct: 0 })))).toMatch(/1-6/);
  });
  it('level pertama harus Rp0', () => expect(validateTierSet([{ ...ok[0], minSpend: 1 }])).toMatch(/Rp0/));
  it('minSpend harus naik ketat', () => {
    expect(validateTierSet([ok[0], { ...ok[1], minSpend: 0 }])).toMatch(/lebih besar/);
    expect(validateTierSet([ok[0], { ...ok[1], minSpend: 100 }, { name: 'X', minSpend: 100, earnMultiplierPct: 100, discountPct: 0 }])).toMatch(/lebih besar/);
  });
  it('nama unik (tanpa membedakan huruf besar/kecil), tak kosong, maks 20', () => {
    expect(validateTierSet([ok[0], { ...ok[1], name: 'member' }])).toMatch(/dua kali/);
    expect(validateTierSet([{ ...ok[0], name: '   ' }])).toMatch(/kosong/);
    expect(validateTierSet([{ ...ok[0], name: 'x'.repeat(21) }])).toMatch(/20 karakter/);
  });
});
