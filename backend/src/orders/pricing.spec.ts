import { describe, expect, it } from 'vitest';
import { calcDeliveryFee, calcDiscount, calcPointRedemption, isOutletOpen } from './pricing.js';

describe('calcDeliveryFee', () => {
  const rule = { baseFee: 8000, baseKm: 2, perKmFee: 2500 };
  it('tarif dasar sampai batas baseKm', () => {
    expect(calcDeliveryFee(0.5, rule)).toBe(8000);
    expect(calcDeliveryFee(2, rule)).toBe(8000);
  });
  it('menambah per km dibulatkan ke atas', () => {
    expect(calcDeliveryFee(2.1, rule)).toBe(10500);
    expect(calcDeliveryFee(4, rule)).toBe(13000);
    expect(calcDeliveryFee(4.01, rule)).toBe(15500);
  });
  it('mengikuti aturan outlet yang berbeda', () => {
    expect(calcDeliveryFee(0.9, { baseFee: 5000, baseKm: 1, perKmFee: 1000 })).toBe(5000);
    expect(calcDeliveryFee(1.5, { baseFee: 5000, baseKm: 1, perKmFee: 1000 })).toBe(6000);
  });
});

describe('calcDiscount', () => {
  const percent = { type: 'PERCENT' as const, value: 10, minSpend: 30000, maxDiscount: 15000 };
  it('0 jika di bawah minimum belanja', () => {
    expect(calcDiscount(percent, 29999)).toBe(0);
  });
  it('persen dengan batas maksimum', () => {
    expect(calcDiscount(percent, 50000)).toBe(5000);
    expect(calcDiscount(percent, 500000)).toBe(15000);
  });
  it('nominal tetap tidak melebihi subtotal', () => {
    expect(calcDiscount({ type: 'FIXED', value: 20000, minSpend: 0, maxDiscount: null }, 15000)).toBe(15000);
  });
});

describe('isOutletOpen', () => {
  const at = (hourUtc: number) => new Date(Date.UTC(2026, 0, 1, hourUtc)); // Jakarta = UTC+7
  it('buka dalam jam operasional (WIB)', () => {
    expect(isOutletOpen(8, 22, at(1))).toBe(true); // 08:00 WIB
    expect(isOutletOpen(8, 22, at(14))).toBe(true); // 21:00 WIB
  });
  it('tutup di luar jam operasional', () => {
    expect(isOutletOpen(8, 22, at(0))).toBe(false); // 07:00 WIB
    expect(isOutletOpen(8, 22, at(15))).toBe(false); // 22:00 WIB
  });
});

describe('calcPointRedemption', () => {
  it('dibatasi saldo poin', () => {
    expect(calcPointRedemption(1000, 30, 100000)).toEqual({ pointsUsed: 30, pointDiscount: 3000 });
  });
  it('dibatasi 50% dari belanja', () => {
    // belanja 20.000 -> maks 10.000 = 100 poin
    expect(calcPointRedemption(1000, 5000, 20000)).toEqual({ pointsUsed: 100, pointDiscount: 10000 });
  });
  it('tidak pernah negatif atau melebihi permintaan', () => {
    expect(calcPointRedemption(-5, 100, 50000).pointsUsed).toBe(0);
    expect(calcPointRedemption(10, 100, 50000).pointsUsed).toBe(10);
  });
});
