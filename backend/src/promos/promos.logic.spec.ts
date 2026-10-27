import { describe, expect, it } from 'vitest';
import { isPromoLive, moveInOrder, selectWelcomePromos } from './promos.logic.js';

const now = new Date('2026-10-23T05:00:00Z');
const day = (d: string) => new Date(`${d}T00:00:00Z`);
const promo = (over: Partial<{ isActive: boolean; startsAt: Date | null; endsAt: Date | null; voucherCode: string | null; id: string }> = {}) => ({
  id: 'p', isActive: true, startsAt: null, endsAt: null, voucherCode: null, ...over,
});

describe('isPromoLive', () => {
  it('aktif tanpa batas periode = tayang', () => expect(isPromoLive(promo(), now)).toBe(true));
  it('nonaktif tidak tayang', () => expect(isPromoLive(promo({ isActive: false }), now)).toBe(false));
  it('belum mulai / sudah berakhir tidak tayang', () => {
    expect(isPromoLive(promo({ startsAt: day('2026-10-24') }), now)).toBe(false);
    expect(isPromoLive(promo({ endsAt: day('2026-10-22') }), now)).toBe(false);
  });
  it('di dalam periode tayang', () => {
    expect(isPromoLive(promo({ startsAt: day('2026-10-01'), endsAt: day('2026-10-31') }), now)).toBe(true);
  });
});

describe('selectWelcomePromos', () => {
  it('promo ber-voucher hanya tayang bila voucher masih valid', () => {
    const list = [promo({ id: 'a' }), promo({ id: 'b', voucherCode: 'HEMAT10' }), promo({ id: 'c', voucherCode: 'MATI' })];
    const out = selectWelcomePromos(list, new Set(['HEMAT10']), now);
    expect(out.map((p) => p.id)).toEqual(['a', 'b']);
  });
  it('membatasi jumlah dan mempertahankan urutan', () => {
    const list = Array.from({ length: 12 }, (_, i) => promo({ id: String(i) }));
    const out = selectWelcomePromos(list, new Set(), now);
    expect(out).toHaveLength(8);
    expect(out[0].id).toBe('0');
  });
});

describe('moveInOrder', () => {
  it('menukar dengan tetangga dan merapikan nomor', () => {
    expect(moveInOrder(['a', 'b', 'c'], 'c', 'up')).toEqual([{ id: 'a', sort: 10 }, { id: 'c', sort: 20 }, { id: 'b', sort: 30 }]);
  });
  it('di ujung tidak bergeser tapi tetap dirapikan', () => {
    expect(moveInOrder(['a', 'b'], 'a', 'up')).toEqual([{ id: 'a', sort: 10 }, { id: 'b', sort: 20 }]);
  });
  it('id tidak dikenal -> null', () => expect(moveInOrder(['a'], 'x', 'down')).toBeNull());
});
