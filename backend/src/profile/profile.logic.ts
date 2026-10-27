/** Logika murni profil (tanpa akses database) agar mudah diuji. */

export const GENDERS = ['MALE', 'FEMALE'] as const;
export type Gender = (typeof GENDERS)[number];

export type ProfileItem = 'name' | 'email' | 'birthDate' | 'gender' | 'address';
export type CompletionPercent = 0 | 20 | 40 | 60 | 80 | 100;

const WIB_OFFSET_MS = 7 * 3600_000;

/** Hari ini di zona WIB, 'YYYY-MM-DD'. */
export const wibToday = (now = new Date()): string => new Date(now.getTime() + WIB_OFFSET_MS).toISOString().slice(0, 10);

export interface ProfileFields {
  name?: string | null;
  email?: string | null;
  birthDate?: Date | string | null;
  gender?: string | null;
}

/** Tiap item bernilai 20%: nama, email, tanggal lahir, jenis kelamin, dan minimal satu alamat tersimpan. */
export function profileCompletion(f: ProfileFields, addressCount: number): { percent: CompletionPercent; missing: ProfileItem[] } {
  const missing: ProfileItem[] = [];
  if (!f.name || f.name.trim().length === 0) missing.push('name');
  if (!f.email) missing.push('email');
  if (!f.birthDate) missing.push('birthDate');
  if (!f.gender) missing.push('gender');
  if (addressCount < 1) missing.push('address');
  return { percent: ((5 - missing.length) * 20) as CompletionPercent, missing };
}

/** Date (kolom DATE, UTC tengah malam) -> 'YYYY-MM-DD'. */
export const formatBirthDate = (d: Date | null | undefined): string | null => (d ? d.toISOString().slice(0, 10) : null);

export type BirthDateResult = { ok: true; date: Date } | { ok: false; error: string };

export const MIN_AGE = 5;
export const MAX_AGE = 110;

/** Validasi tanggal lahir 'YYYY-MM-DD': tanggal kalender nyata, bukan di masa depan, umur 5-110 tahun (dihitung dari hari ini WIB). */
export function validateBirthDate(input: string, now = new Date()): BirthDateResult {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(input)) return { ok: false, error: 'Format tanggal lahir harus YYYY-MM-DD' };
  const date = new Date(`${input}T00:00:00Z`);
  // Round-trip menolak tanggal yang tidak ada (mis. 2020-02-31 yang akan "meluber" ke Maret).
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== input) return { ok: false, error: 'Tanggal lahir tidak valid' };
  const today = wibToday(now);
  if (input > today) return { ok: false, error: 'Tanggal lahir tidak boleh di masa depan' };
  const [by, bm, bd] = input.split('-').map(Number);
  const [ty, tm, td] = today.split('-').map(Number);
  let age = ty - by;
  if (tm < bm || (tm === bm && td < bd)) age--;
  if (age < MIN_AGE) return { ok: false, error: `Umur minimal ${MIN_AGE} tahun` };
  if (age > MAX_AGE) return { ok: false, error: 'Tanggal lahir tidak masuk akal' };
  return { ok: true, date };
}
