/** Teks contoh/placeholder yang tidak boleh dipakai sebagai rahasia sungguhan. */
const WEAK_PATTERNS = [/ganti-dengan/i, /change[-_ ]?me/i, /^secret$/i, /^password$/i, /rahasia-panjang-acak/i];

/**
 * Di production, JWT_SECRET harus panjang (>= 32 karakter) dan bukan teks contoh.
 * Rahasia yang lemah memungkinkan siapa pun memalsukan token login (termasuk admin).
 * Di luar production tidak ada pembatasan agar pengembangan lokal tetap mudah.
 */
export function assertStrongJwtSecret(secret: string | undefined, nodeEnv: string | undefined): void {
  if (nodeEnv !== 'production') return;
  if (!secret || secret.length < 32 || WEAK_PATTERNS.some((p) => p.test(secret))) {
    throw new Error('JWT_SECRET terlalu lemah untuk production: pakai string acak minimal 32 karakter (mis. `openssl rand -base64 48`).');
  }
}
