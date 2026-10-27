/** Logika murni notifikasi (tanpa akses database): teks per perubahan status pesanan, level, dan check-in. */

export type NotificationType = 'ORDER' | 'POINTS' | 'CHECKIN' | 'LEVEL' | 'PROMO';

export interface NotificationDraft {
  type: NotificationType;
  title: string;
  body: string;
}

export interface OrderNotifyContext {
  code: string;
  type: 'PICKUP' | 'DELIVERY';
  courierName?: string | null;
  pointsEarned?: number;
  pointsUsed?: number;
}

/** Notifikasi untuk perubahan status pesanan. null = tidak perlu (mis. PENDING_PAYMENT). */
export function buildOrderNotification(status: string, c: OrderNotifyContext): NotificationDraft | null {
  const order = { type: 'ORDER' as const };
  switch (status) {
    case 'PAID':
      return { ...order, title: 'Pembayaran diterima', body: `Pesanan ${c.code} sudah dibayar dan segera kami proses.` };
    case 'PREPARING':
      return { ...order, title: 'Pesanan sedang dibuat', body: `Barista sedang menyiapkan pesanan ${c.code}.` };
    case 'READY':
      return c.type === 'DELIVERY'
        ? { ...order, title: 'Pesanan siap dikirim', body: `Pesanan ${c.code} sudah siap dan menunggu kurir.` }
        : { ...order, title: 'Pesanan siap diambil', body: `Pesanan ${c.code} sudah siap, silakan ambil di outlet.` };
    case 'ON_DELIVERY':
      return { ...order, title: 'Pesanan dalam perjalanan', body: `Pesanan ${c.code} sedang diantar${c.courierName ? ` oleh ${c.courierName}` : ''}.` };
    case 'COMPLETED':
      return { ...order, title: 'Pesanan selesai', body: `Pesanan ${c.code} selesai. Terima kasih!${c.pointsEarned && c.pointsEarned > 0 ? ` Kamu mendapat +${c.pointsEarned} poin.` : ''}` };
    case 'CANCELLED':
      return { ...order, title: 'Pesanan dibatalkan', body: `Pesanan ${c.code} dibatalkan.${c.pointsUsed && c.pointsUsed > 0 ? ' Poin yang kamu pakai dikembalikan.' : ''}` };
    case 'EXPIRED':
      return { ...order, title: 'Waktu pembayaran habis', body: `Pesanan ${c.code} dibatalkan karena tidak dibayar tepat waktu.` };
    default:
      return null;
  }
}

export function levelUpNotification(tierName: string): NotificationDraft {
  return { type: 'LEVEL', title: `Naik level ke ${tierName}!`, body: `Selamat! Kamu naik ke level ${tierName}. Cek keuntungan barumu di tab Member.` };
}

export function checkInNotification(day: number, points: number): NotificationDraft {
  return {
    type: 'CHECKIN',
    title: `Check-in hari ke-${day} berhasil`,
    body: points > 0 ? `Check-in hari ke-${day} berhasil, +${points} poin. Kembali besok untuk hadiah berikutnya!` : `Check-in hari ke-${day} berhasil. Kembali besok untuk hadiah berikutnya!`,
  };
}

/** Teks yang aman dipotong agar muat kolom judul (maks 80 karakter). */
export const clip = (s: string, max: number): string => (s.length <= max ? s : `${s.slice(0, max - 1)}…`);
