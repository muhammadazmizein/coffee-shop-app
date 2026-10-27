/** Normalisasi nomor HP Indonesia ke format 62xxxxxxxxxx. Mengembalikan null jika tidak valid. */
export function normalizePhone(input: string): string | null {
  let digits = input.replace(/\D/g, '');
  if (digits.startsWith('0')) digits = '62' + digits.slice(1);
  else if (digits.startsWith('8')) digits = '62' + digits;
  if (!/^628\d{8,11}$/.test(digits)) return null;
  return digits;
}

/**
 * Normalisasi nomor kontak outlet ke 62xxxxxxxxxx. Nomor seluler memakai normalizePhone; nomor tetap
 * (mis. "(021) 555 1234") dengan awalan 0 atau 62 juga diterima. Mengembalikan null jika tidak valid.
 */
export function normalizeContactPhone(input: string): string | null {
  const mobile = normalizePhone(input);
  if (mobile) return mobile;
  const digits = input.replace(/\D/g, '');
  const intl = digits.startsWith('0') ? '62' + digits.slice(1) : digits;
  return /^62[1-9]\d{7,11}$/.test(intl) ? intl : null;
}
