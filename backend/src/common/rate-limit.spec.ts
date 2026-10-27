import { describe, expect, it } from 'vitest';
import { RateLimiter } from './rate-limit.js';

describe('RateLimiter', () => {
  it('menolak setelah batas tercapai dan pulih setelah jendela lewat', () => {
    const rl = new RateLimiter(2, 1000);
    expect(rl.allow('a', 0)).toBe(true);
    expect(rl.allow('a', 100)).toBe(true);
    expect(rl.allow('a', 200)).toBe(false);
    expect(rl.allow('b', 200)).toBe(true); // kunci lain tidak terpengaruh
    expect(rl.allow('a', 1001)).toBe(true); // hit pertama sudah keluar jendela
  });
});
