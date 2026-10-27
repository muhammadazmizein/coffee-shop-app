import { describe, expect, it } from 'vitest';
import { formatBirthDate, profileCompletion, validateBirthDate, wibToday } from './profile.logic.js';

describe('profileCompletion', () => {
  it('kosong = 0% dan semua item hilang', () => {
    expect(profileCompletion({}, 0)).toEqual({ percent: 0, missing: ['name', 'email', 'birthDate', 'gender', 'address'] });
  });
  it('tiap item bernilai 20%', () => {
    expect(profileCompletion({ name: 'Budi' }, 0).percent).toBe(20);
    expect(profileCompletion({ name: 'Budi', email: 'b@x.id' }, 0).percent).toBe(40);
    expect(profileCompletion({ name: 'Budi', email: 'b@x.id', birthDate: '2000-01-01' }, 0).percent).toBe(60);
    expect(profileCompletion({ name: 'Budi', email: 'b@x.id', birthDate: '2000-01-01', gender: 'MALE' }, 0).percent).toBe(80);
  });
  it('alamat tersimpan melengkapi 100%', () => {
    const r = profileCompletion({ name: 'Budi', email: 'b@x.id', birthDate: new Date('2000-01-01'), gender: 'FEMALE' }, 1);
    expect(r).toEqual({ percent: 100, missing: [] });
  });
  it('nama spasi saja dianggap kosong', () => {
    expect(profileCompletion({ name: '   ' }, 0).missing).toContain('name');
  });
});

describe('validateBirthDate', () => {
  const now = new Date('2026-10-26T05:00:00Z'); // 26 Okt 2026 12:00 WIB
  it('menerima tanggal wajar dan mengembalikan Date UTC tengah malam', () => {
    const r = validateBirthDate('1995-03-15', now);
    expect(r.ok).toBe(true);
    if (r.ok) expect(formatBirthDate(r.date)).toBe('1995-03-15');
  });
  it('menolak format salah dan tanggal yang tidak ada', () => {
    expect(validateBirthDate('15-03-1995', now).ok).toBe(false);
    expect(validateBirthDate('2020-02-31', now)).toEqual({ ok: false, error: 'Tanggal lahir tidak valid' });
    expect(validateBirthDate('2021-02-29', now).ok).toBe(false); // bukan tahun kabisat
    expect(validateBirthDate('2020-02-29', now).ok).toBe(true); // kabisat
  });
  it('menolak masa depan', () => {
    expect(validateBirthDate('2027-01-01', now)).toEqual({ ok: false, error: 'Tanggal lahir tidak boleh di masa depan' });
  });
  it('batas umur 5 dan 110 tahun dihitung ke hari', () => {
    expect(validateBirthDate('2021-10-26', now).ok).toBe(true); // tepat 5 tahun
    expect(validateBirthDate('2021-10-27', now)).toEqual({ ok: false, error: 'Umur minimal 5 tahun' });
    expect(validateBirthDate('1915-10-27', now).ok).toBe(true); // masih 110 tahun (ulang tahun ke-111 besok)
    expect(validateBirthDate('1915-10-26', now)).toEqual({ ok: false, error: 'Tanggal lahir tidak masuk akal' }); // tepat 111
  });
  it('memakai hari WIB, bukan UTC (tengah malam WIB)', () => {
    // 25 Okt 2026 17:30 UTC = 26 Okt 2026 00:30 WIB -> hari ini sudah 26
    const lateUtc = new Date('2026-10-25T17:30:00Z');
    expect(wibToday(lateUtc)).toBe('2026-10-26');
    expect(validateBirthDate('2026-10-26', lateUtc).ok).toBe(false); // hari ini: umur 0 -> terlalu muda, tapi bukan "masa depan"
    expect(validateBirthDate('2026-10-27', lateUtc)).toEqual({ ok: false, error: 'Tanggal lahir tidak boleh di masa depan' });
  });
});
