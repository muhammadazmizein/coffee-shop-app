import { describe, expect, it } from 'vitest';
import {
  attemptId,
  buildChargePayload,
  buildItemDetails,
  canReuseCharge,
  deriveOrderCode,
  enabledMethods,
  isChargeCreated,
  mapStatus,
  methodKeyFromNotification,
  orderPayDeadline,
  parseChargeResponse,
  shouldSweep,
  toPaymentView,
  wibToDate,
  type PaymentRow,
} from './payments.logic.js';

const min = (n: number) => n * 60_000;

describe('kode percobaan', () => {
  it('attemptId dan deriveOrderCode saling berkebalikan', () => {
    expect(attemptId('KPABC123', 2)).toBe('KPABC123-2');
    expect(deriveOrderCode('KPABC123-2')).toBe('KPABC123');
    expect(deriveOrderCode('KPABC123-15')).toBe('KPABC123');
  });
  it('ID lama tanpa akhiran dibiarkan', () => {
    expect(deriveOrderCode('KPMVKIQ8KU0261')).toBe('KPMVKIQ8KU0261');
  });
});

describe('wibToDate', () => {
  it('membaca waktu WIB sebagai UTC+7', () => {
    expect(wibToDate('2026-10-23 14:46:32')?.toISOString()).toBe('2026-10-23T07:46:32.000Z');
  });
  it('menolak format lain', () => {
    expect(wibToDate('besok')).toBeNull();
    expect(wibToDate(undefined)).toBeNull();
  });
});

describe('buildItemDetails', () => {
  const base = { subtotal: 62000, discount: 6200, deliveryFee: 8000, total: 63800, items: [{ productId: 'p1', name: 'Kopi', qty: 2, unitPrice: 31000 }] };
  const sum = (rows: { price: number; quantity: number }[]) => rows.reduce((s, r) => s + r.price * r.quantity, 0);

  it('jumlah baris sama dengan total (diskon + ongkir)', () => {
    const rows = buildItemDetails(base);
    expect(sum(rows)).toBe(63800);
    expect(rows.map((r) => r.id)).toEqual(['p1-0', 'DISCOUNT', 'DELIVERY']);
  });
  it('menambah baris potongan poin dari selisih total', () => {
    const rows = buildItemDetails({ ...base, total: 63100 }); // 700 dibayar poin
    expect(sum(rows)).toBe(63100);
    expect(rows.find((r) => r.id === 'POINTS')?.price).toBe(-700);
  });
  it('jatuh ke satu baris bila data tidak konsisten', () => {
    // harga item (2 x 30.000) tidak cocok dengan subtotal 62.000
    const rows = buildItemDetails({ ...base, items: [{ productId: 'p1', name: 'Kopi', qty: 2, unitPrice: 30000 }] });
    expect(rows).toEqual([{ id: 'ORDER', name: 'Pesanan', price: 63800, quantity: 1 }]);
  });
  it('memotong nama yang terlalu panjang', () => {
    const rows = buildItemDetails({ ...base, discount: 0, total: 70000, items: [{ productId: 'p', name: 'x'.repeat(80), qty: 1, unitPrice: 62000 }] });
    expect(rows[0].name.length).toBe(50);
  });
});

describe('buildChargePayload', () => {
  const input = { midtransOrderId: 'KP1-1', amount: 25000, items: [], customer: { name: 'Budi', phone: '6281' }, returnUrl: 'kopiapp://payment/finish' };
  it('tiap metode memakai payment_type yang benar', () => {
    expect(buildChargePayload('qris', input)).toMatchObject({ payment_type: 'qris', qris: { acquirer: 'gopay' } });
    expect(buildChargePayload('gopay', input)).toMatchObject({ payment_type: 'gopay', gopay: { enable_callback: true, callback_url: 'kopiapp://payment/finish' } });
    expect(buildChargePayload('shopeepay', input)).toMatchObject({ payment_type: 'shopeepay', shopeepay: { callback_url: 'kopiapp://payment/finish' } });
    expect(buildChargePayload('bca_va', input)).toMatchObject({ payment_type: 'bank_transfer', bank_transfer: { bank: 'bca' } });
    expect(buildChargePayload('permata_va', input)).toMatchObject({ payment_type: 'bank_transfer', bank_transfer: { bank: 'permata' } });
    expect(buildChargePayload('mandiri_va', input)).toMatchObject({ payment_type: 'echannel' });
  });
  it('semua charge berlaku 30 menit dan memakai ID percobaan', () => {
    const p = buildChargePayload('qris', input) as { custom_expiry: unknown; transaction_details: unknown };
    expect(p.custom_expiry).toEqual({ expiry_duration: 30, unit: 'minute' });
    expect(p.transaction_details).toEqual({ order_id: 'KP1-1', gross_amount: 25000 });
  });
  it('ovo wajib nomor akun', () => {
    expect(() => buildChargePayload('ovo', input)).toThrow(/OVO/);
    expect(buildChargePayload('ovo', { ...input, ovoPhone: '6281299990001' })).toMatchObject({ payment_type: 'ovo', ovo: { payer_phone_number: '6281299990001' } });
  });
});

describe('parseChargeResponse (bentuk respons sandbox nyata)', () => {
  const exp = '2026-10-23 14:46:32';
  it('qris: qr_string wajib', () => {
    const r = parseChargeResponse('qris', { qr_string: '0002010102122662', expiry_time: exp, actions: [{ name: 'generate-qr-code-v2', url: 'https://x/qr.png' }] });
    expect(r.qrString).toBe('0002010102122662');
    expect(r.qrImageUrl).toBe('https://x/qr.png');
    expect(r.expiresAt?.toISOString()).toBe('2026-10-23T07:46:32.000Z');
    expect(() => parseChargeResponse('qris', { qr_string: '', expiry_time: exp })).toThrow(/qr_string/);
  });
  it('gopay: qr_string kosong tetap sah selama ada gambar QR / deeplink', () => {
    const r = parseChargeResponse('gopay', {
      qr_string: '',
      actions: [
        { name: 'generate-qr-code', url: 'https://api/qr' },
        { name: 'deeplink-redirect', url: 'https://sim/deeplink' },
      ],
    });
    expect(r.qrString).toBeNull();
    expect(r.qrImageUrl).toBe('https://api/qr');
    expect(r.deeplinkUrl).toBe('https://sim/deeplink');
    expect(() => parseChargeResponse('gopay', { qr_string: '', actions: [] })).toThrow();
  });
  it('shopeepay: deeplink wajib', () => {
    expect(parseChargeResponse('shopeepay', { actions: [{ name: 'deeplink-redirect', url: 'https://sim/pin' }] }).deeplinkUrl).toBe('https://sim/pin');
    expect(() => parseChargeResponse('shopeepay', {})).toThrow(/deeplink/);
  });
  it('ovo: nomor pembayar dari respons', () => {
    expect(parseChargeResponse('ovo', { payer_phone_number: '081299990001' }).payerPhone).toBe('081299990001');
  });
  it('va bank: nomor dari va_numbers sesuai bank', () => {
    const r = parseChargeResponse('bni_va', { va_numbers: [{ bank: 'bni', va_number: '9889513896940015' }] });
    expect([r.vaBank, r.vaNumber]).toEqual(['bni', '9889513896940015']);
    expect(() => parseChargeResponse('bca_va', { va_numbers: [] })).toThrow(/va_numbers/);
  });
  it('permata: nomor di permata_va_number', () => {
    const r = parseChargeResponse('permata_va', { permata_va_number: '9510004990286944' });
    expect([r.vaBank, r.vaNumber]).toEqual(['permata', '9510004990286944']);
  });
  it('mandiri: biller code + bill key', () => {
    const r = parseChargeResponse('mandiri_va', { bill_key: '807379488779', biller_code: '70012' });
    expect([r.billerCode, r.billKey]).toEqual(['70012', '807379488779']);
    expect(() => parseChargeResponse('mandiri_va', { biller_code: '70012' })).toThrow();
  });
  it('isChargeCreated membaca status_code di body', () => {
    expect(isChargeCreated({ status_code: '201' })).toBe(true);
    expect(isChargeCreated({ status_code: '406' })).toBe(false);
    expect(isChargeCreated({})).toBe(false);
  });
});

describe('status', () => {
  it('pemetaan status transaksi', () => {
    expect(mapStatus({ transaction_status: 'settlement' })).toBe('PAID');
    expect(mapStatus({ transaction_status: 'capture', fraud_status: 'accept' })).toBe('PAID');
    expect(mapStatus({ transaction_status: 'capture', fraud_status: 'challenge' })).toBe('PENDING');
    expect(mapStatus({ transaction_status: 'pending' })).toBe('PENDING');
    expect(mapStatus({ transaction_status: 'expire' })).toBe('EXPIRED');
    for (const s of ['cancel', 'deny', 'failure']) expect(mapStatus({ transaction_status: s })).toBe('FAILED');
  });
  it('kunci metode dari notifikasi', () => {
    expect(methodKeyFromNotification({ transaction_status: 'settlement', payment_type: 'qris' })).toBe('qris');
    expect(methodKeyFromNotification({ transaction_status: 'settlement', payment_type: 'echannel' })).toBe('mandiri_va');
    expect(methodKeyFromNotification({ transaction_status: 'settlement', payment_type: 'bank_transfer', va_numbers: [{ bank: 'bca' }] })).toBe('bca_va');
    expect(methodKeyFromNotification({ transaction_status: 'settlement', payment_type: 'bank_transfer', permata_va_number: '951' })).toBe('permata_va');
    expect(methodKeyFromNotification({ transaction_status: 'settlement', payment_type: 'credit_card' })).toBe('credit_card');
  });
});

describe('idempotensi & batas waktu', () => {
  const now = new Date('2026-10-23T08:00:00Z');
  const pending = (method: string, expiresInMin: number, status: 'PENDING' | 'PAID' | 'EXPIRED' = 'PENDING') =>
    ({ method, status, expiresAt: new Date(now.getTime() + min(expiresInMin)) });

  it('metode sama + PENDING + belum kedaluwarsa dipakai ulang', () => {
    expect(canReuseCharge(pending('qris', 10), 'qris', now)).toBe(true);
  });
  it('metode beda, kedaluwarsa, atau bukan PENDING tidak dipakai ulang', () => {
    expect(canReuseCharge(pending('qris', 10), 'gopay', now)).toBe(false);
    expect(canReuseCharge(pending('qris', -1), 'qris', now)).toBe(false);
    expect(canReuseCharge(pending('qris', 10, 'EXPIRED'), 'qris', now)).toBe(false);
    expect(canReuseCharge(null, 'qris', now)).toBe(false);
  });
  it('batas akhir pesanan = 30 menit sejak dibuat, atau charge terakhir bila lebih lama', () => {
    const created = new Date('2026-10-23T07:00:00Z');
    expect(orderPayDeadline(created, null).toISOString()).toBe('2026-10-23T07:30:00.000Z');
    expect(orderPayDeadline(created, new Date('2026-10-23T07:10:00Z')).toISOString()).toBe('2026-10-23T07:30:00.000Z'); // OVO yang cepat habis tidak memendekkan
    expect(orderPayDeadline(created, new Date('2026-10-23T07:50:00Z')).toISOString()).toBe('2026-10-23T07:50:00.000Z');
  });
  it('sweep menunggu batas akhir + 2 menit', () => {
    const created = new Date('2026-10-23T07:00:00Z');
    expect(shouldSweep(created, null, new Date('2026-10-23T07:31:00Z'))).toBe(false);
    expect(shouldSweep(created, null, new Date('2026-10-23T07:33:00Z'))).toBe(true);
    expect(shouldSweep(created, new Date('2026-10-23T07:50:00Z'), new Date('2026-10-23T07:40:00Z'))).toBe(false);
  });
});

describe('toPaymentView & daftar metode', () => {
  const row = (o: Partial<PaymentRow>): PaymentRow => ({
    method: 'qris', status: 'PENDING', amount: 25000, expiresAt: new Date('2026-10-23T07:46:32Z'), paidAt: null,
    qrString: null, qrImageUrl: null, deeplinkUrl: null, vaBank: null, vaNumber: null, billerCode: null, billKey: null, payerPhone: null, ...o,
  });
  it('hanya menyertakan field yang terisi', () => {
    const v = toPaymentView('o1', 25000, row({ qrString: '000201' }));
    expect(v).toEqual({ orderId: 'o1', method: 'qris', group: 'qris', status: 'PENDING', amount: 25000, expiresAt: '2026-10-23T07:46:32.000Z', paidAt: null, qrString: '000201' });
  });
  it('VA, bill, dan OVO dibentuk sesuai kontrak', () => {
    expect(toPaymentView('o', 1, row({ method: 'bca_va', vaBank: 'bca', vaNumber: '95' })).va).toEqual({ bank: 'bca', number: '95' });
    expect(toPaymentView('o', 1, row({ method: 'mandiri_va', billerCode: '70012', billKey: '807' })).bill).toEqual({ billerCode: '70012', billKey: '807' });
    expect(toPaymentView('o', 1, row({ method: 'ovo', payerPhone: '6281' })).ovo).toEqual({ phone: '6281' });
  });
  it('baris lama (kartu/Snap) tetap terbaca dengan group other dan amount dari pesanan', () => {
    const v = toPaymentView('o', 46800, row({ method: 'credit_card', status: 'PAID', amount: null, expiresAt: null }));
    expect([v.group, v.amount, v.expiresAt]).toEqual(['other', 46800, null]);
  });
  it('daftar metode berurutan dan bisa dimatikan lewat env', () => {
    expect(enabledMethods('').map((m) => m.key)).toEqual(['qris', 'gopay', 'shopeepay', 'ovo', 'bca_va', 'bni_va', 'bri_va', 'mandiri_va', 'permata_va']);
    expect(enabledMethods('ovo, shopeepay').map((m) => m.key)).not.toContain('ovo');
    expect(enabledMethods('ovo, shopeepay').map((m) => m.key)).not.toContain('shopeepay');
  });
});
