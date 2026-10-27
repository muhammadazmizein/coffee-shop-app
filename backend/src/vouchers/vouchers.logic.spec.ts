import { describe, expect, it } from 'vitest';
import { isVoucherAvailable, voucherRemaining } from './vouchers.logic.js';

const now = new Date('2026-10-23T05:00:00Z');
const base = { isActive: true, startsAt: new Date('2026-10-01T00:00:00Z'), endsAt: new Date('2026-11-01T00:00:00Z'), quota: 10, used: 3 };

describe('voucherRemaining', () => {
  it('sisa kuota; null bila tanpa batas; tidak negatif', () => {
    expect(voucherRemaining(10, 3)).toBe(7);
    expect(voucherRemaining(0, 999)).toBeNull();
    expect(voucherRemaining(5, 9)).toBe(0);
  });
});

describe('isVoucherAvailable', () => {
  it('tersedia saat aktif, dalam periode, dan kuota tersisa', () => {
    expect(isVoucherAvailable(base, now)).toBe(true);
    expect(isVoucherAvailable({ ...base, quota: 0, used: 500 }, now)).toBe(true);
  });
  it('ditolak bila nonaktif, belum mulai, kedaluwarsa, atau kuota habis', () => {
    expect(isVoucherAvailable({ ...base, isActive: false }, now)).toBe(false);
    expect(isVoucherAvailable({ ...base, startsAt: new Date('2026-12-01T00:00:00Z'), endsAt: new Date('2027-01-01T00:00:00Z') }, now)).toBe(false);
    expect(isVoucherAvailable({ ...base, endsAt: new Date('2026-10-20T00:00:00Z') }, now)).toBe(false);
    expect(isVoucherAvailable({ ...base, used: 10 }, now)).toBe(false);
  });
});
