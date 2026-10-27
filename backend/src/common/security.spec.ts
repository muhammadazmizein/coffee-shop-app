import { describe, expect, it } from 'vitest';
import { assertStrongJwtSecret } from './security.js';

describe('assertStrongJwtSecret', () => {
  const strong = 'k8Zr2mQw9XvT1nBy6LpHs4JdUe7GaCf0RoIx3WtYq5Vb';

  it('di luar production semua nilai diterima (pengembangan lokal)', () => {
    expect(() => assertStrongJwtSecret('ganti-dengan-rahasia-panjang-acak', undefined)).not.toThrow();
    expect(() => assertStrongJwtSecret('abc', 'development')).not.toThrow();
  });

  it('production menolak teks contoh, terlalu pendek, atau kosong', () => {
    expect(() => assertStrongJwtSecret('ganti-dengan-rahasia-panjang-acak', 'production')).toThrow(/terlalu lemah/);
    expect(() => assertStrongJwtSecret('pendek', 'production')).toThrow(/terlalu lemah/);
    expect(() => assertStrongJwtSecret(undefined, 'production')).toThrow(/terlalu lemah/);
    expect(() => assertStrongJwtSecret('changeme' + 'x'.repeat(30), 'production')).toThrow(/terlalu lemah/);
  });

  it('production menerima rahasia acak yang panjang', () => {
    expect(() => assertStrongJwtSecret(strong, 'production')).not.toThrow();
  });
});
