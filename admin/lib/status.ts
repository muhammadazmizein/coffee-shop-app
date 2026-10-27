export const STATUS_LABEL: Record<string, string> = {
  PENDING_PAYMENT: 'Menunggu bayar',
  PAID: 'Dibayar',
  PREPARING: 'Diproses',
  READY: 'Siap',
  ON_DELIVERY: 'Diantar',
  COMPLETED: 'Selesai',
  CANCELLED: 'Dibatalkan',
  EXPIRED: 'Kedaluwarsa',
};

/** Ikon + label: status tidak pernah dibawakan oleh warna saja. */
export const STATUS_ICON: Record<string, string> = {
  PENDING_PAYMENT: '⏳', PAID: '💳', PREPARING: '☕', READY: '✅', ON_DELIVERY: '🛵', COMPLETED: '✔', CANCELLED: '✕', EXPIRED: '⌛',
};

export const statusTone = (s: string) =>
  s === 'COMPLETED' ? 'ok' : s === 'CANCELLED' || s === 'EXPIRED' ? 'off' : '';

export const TYPE_LABEL: Record<string, string> = { PICKUP: 'Pickup', DELIVERY: 'Delivery' };

export const METHOD_LABEL = (m: string | null | undefined) =>
  ({
    qris: 'QRIS', gopay: 'GoPay', shopeepay: 'ShopeePay', ovo: 'OVO',
    bca_va: 'BCA VA', bni_va: 'BNI VA', bri_va: 'BRI VA', mandiri_va: 'Mandiri VA', permata_va: 'Permata VA',
    // pembayaran lama (Snap)
    credit_card: 'Kartu kredit', bank_transfer: 'Transfer bank', echannel: 'Mandiri Bill', cstore: 'Minimarket', akulaku: 'Akulaku', kredivo: 'Kredivo',
  } as Record<string, string>)[m ?? ''] ?? (m || '-');
