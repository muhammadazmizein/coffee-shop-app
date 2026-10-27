/** Ilustrasi bawaan app yang boleh dipakai slide promo. Kunci harus sama dengan PROMO_ART_KEYS di backend; file SVG-nya
 *  disalin dari mobile/assets/illustrations ke public/illustrations agar pratinjau tampil sama dengan di app. */
export const ART_OPTIONS: { key: string; label: string }[] = [
  { key: 'onboarding_1', label: 'Gelas & croissant' },
  { key: 'onboarding_2', label: 'Kurir skuter' },
  { key: 'onboarding_3', label: 'Koin poin' },
  { key: 'product_latte', label: 'Kopi susu es' },
  { key: 'product_matcha', label: 'Matcha' },
  { key: 'product_chocolate', label: 'Cokelat' },
  { key: 'product_boba', label: 'Boba' },
  { key: 'product_croissant', label: 'Croissant' },
  { key: 'product_donut', label: 'Donat' },
];

export const artLabel = (key: string | null | undefined) => ART_OPTIONS.find((a) => a.key === key)?.label ?? null;
export const artSrc = (key: string | null | undefined) => (key && artLabel(key) ? `/illustrations/${key}.svg` : null);
