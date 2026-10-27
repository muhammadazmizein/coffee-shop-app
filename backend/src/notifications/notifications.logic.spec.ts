import { describe, expect, it } from 'vitest';
import { buildOrderNotification, checkInNotification, clip, levelUpNotification } from './notifications.logic.js';

const ctx = { code: 'KP123', type: 'PICKUP' as const };

describe('buildOrderNotification', () => {
  it('semua status yang dinotifikasikan menyebut kode pesanan', () => {
    for (const s of ['PAID', 'PREPARING', 'READY', 'ON_DELIVERY', 'COMPLETED', 'CANCELLED', 'EXPIRED']) {
      const n = buildOrderNotification(s, ctx)!;
      expect(n.type).toBe('ORDER');
      expect(n.body).toContain('KP123');
      expect(n.title.length).toBeLessThanOrEqual(80);
    }
  });
  it('PENDING_PAYMENT dan status tak dikenal tidak menghasilkan notifikasi', () => {
    expect(buildOrderNotification('PENDING_PAYMENT', ctx)).toBeNull();
    expect(buildOrderNotification('APA_SAJA', ctx)).toBeNull();
  });
  it('READY membedakan pickup dan delivery', () => {
    expect(buildOrderNotification('READY', ctx)!.title).toBe('Pesanan siap diambil');
    expect(buildOrderNotification('READY', { ...ctx, type: 'DELIVERY' })!.title).toBe('Pesanan siap dikirim');
  });
  it('ON_DELIVERY menyertakan nama kurir bila ada', () => {
    expect(buildOrderNotification('ON_DELIVERY', { ...ctx, type: 'DELIVERY', courierName: 'Pak Joko' })!.body).toContain('oleh Pak Joko');
    expect(buildOrderNotification('ON_DELIVERY', { ...ctx, type: 'DELIVERY' })!.body).not.toContain('oleh');
  });
  it('COMPLETED menyebut poin hanya bila ada', () => {
    expect(buildOrderNotification('COMPLETED', { ...ctx, pointsEarned: 6 })!.body).toContain('+6 poin');
    expect(buildOrderNotification('COMPLETED', { ...ctx, pointsEarned: 0 })!.body).not.toContain('poin');
  });
  it('CANCELLED menyebut pengembalian poin bila poin dipakai', () => {
    expect(buildOrderNotification('CANCELLED', { ...ctx, pointsUsed: 7 })!.body).toContain('dikembalikan');
    expect(buildOrderNotification('CANCELLED', ctx)!.body).not.toContain('dikembalikan');
  });
});

describe('notifikasi lain', () => {
  it('level', () => {
    const n = levelUpNotification('Gold');
    expect(n).toMatchObject({ type: 'LEVEL' });
    expect(n.title).toContain('Gold');
  });
  it('check-in', () => {
    expect(checkInNotification(3, 2)).toMatchObject({ type: 'CHECKIN', title: 'Check-in hari ke-3 berhasil' });
    expect(checkInNotification(3, 2).body).toContain('+2 poin');
    expect(checkInNotification(1, 0).body).not.toContain('+0');
  });
  it('clip memotong dengan elipsis', () => {
    expect(clip('abcdef', 4)).toBe('abc…');
    expect(clip('abc', 4)).toBe('abc');
  });
});
