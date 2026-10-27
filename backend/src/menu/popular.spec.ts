import { describe, expect, it } from 'vitest';
import { rankPopular } from './popular.js';

describe('rankPopular', () => {
  const sold = [
    { productId: 'c', qty: 5 },
    { productId: 'a', qty: 9 },
    { productId: 'b', qty: 5 },
    { productId: 'x', qty: 100 }, // tidak diizinkan (nonaktif/habis)
    { productId: 'z', qty: 0 },
  ];
  const allowed = new Set(['a', 'b', 'c', 'z']);

  it('urut qty menurun, seri diputus id, produk tak diizinkan dan qty 0 dibuang', () => {
    expect(rankPopular(sold, allowed)).toEqual(['a', 'b', 'c']);
  });
  it('dibatasi limit', () => {
    expect(rankPopular(sold, allowed, 2)).toEqual(['a', 'b']);
  });
  it('kosong bila belum ada penjualan', () => {
    expect(rankPopular([], allowed)).toEqual([]);
  });
});
