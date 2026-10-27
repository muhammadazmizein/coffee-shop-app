import { describe, expect, it } from 'vitest';
import { normalizeContactPhone, normalizePhone } from './phone.js';

describe('normalizePhone', () => {
  it('menyeragamkan berbagai format', () => {
    expect(normalizePhone('0812-3456-7890')).toBe('6281234567890');
    expect(normalizePhone('+62 812 3456 7890')).toBe('6281234567890');
    expect(normalizePhone('81234567890')).toBe('6281234567890');
  });
  it('menolak nomor tidak valid', () => {
    expect(normalizePhone('12345')).toBeNull();
    expect(normalizePhone('0212345678')).toBeNull();
  });
});

describe('normalizeContactPhone (telepon outlet)', () => {
  it('seluler: 08xx dan +62 menjadi 62xx', () => {
    expect(normalizeContactPhone('0812 3456 7890')).toBe('6281234567890');
    expect(normalizeContactPhone('+62 812-3456-7890')).toBe('6281234567890');
  });
  it('nomor tetap (telepon rumah/kantor) juga diterima', () => {
    expect(normalizeContactPhone('(021) 555 1234')).toBe('62215551234');
    expect(normalizeContactPhone('+62 21 5551234')).toBe('62215551234');
    expect(normalizeContactPhone('0274-889900')).toBe('62274889900');
  });
  it('menolak nomor yang tidak masuk akal', () => {
    expect(normalizeContactPhone('12345')).toBeNull();
    expect(normalizeContactPhone('abc')).toBeNull();
    expect(normalizeContactPhone('00000000000')).toBeNull();
    expect(normalizeContactPhone('+1 415 555 2671')).toBeNull();
  });
});
