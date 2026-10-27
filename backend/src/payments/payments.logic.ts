/**
 * Logika murni pembayaran Midtrans Core API: daftar metode, bentuk payload charge, parsing respons,
 * pemetaan status, dan bentuk PaymentView untuk client. Tanpa akses DB/jaringan agar mudah diuji.
 */

export type PayMethod =
  | 'qris'
  | 'gopay'
  | 'shopeepay'
  | 'ovo'
  | 'bca_va'
  | 'bni_va'
  | 'bri_va'
  | 'mandiri_va'
  | 'permata_va';

export type PayGroup = 'qris' | 'ewallet' | 'va';

export const PAY_METHODS: { key: PayMethod; label: string; group: PayGroup }[] = [
  { key: 'qris', label: 'QRIS', group: 'qris' },
  { key: 'gopay', label: 'GoPay', group: 'ewallet' },
  { key: 'shopeepay', label: 'ShopeePay', group: 'ewallet' },
  { key: 'ovo', label: 'OVO', group: 'ewallet' },
  { key: 'bca_va', label: 'BCA Virtual Account', group: 'va' },
  { key: 'bni_va', label: 'BNI Virtual Account', group: 'va' },
  { key: 'bri_va', label: 'BRI Virtual Account', group: 'va' },
  { key: 'mandiri_va', label: 'Mandiri Virtual Account', group: 'va' },
  { key: 'permata_va', label: 'Permata Virtual Account', group: 'va' },
];

export const METHOD_KEYS = PAY_METHODS.map((m) => m.key);

/** Masa berlaku charge dan batas waktu bayar per pesanan (menit). */
export const CHARGE_TTL_MIN = 30;
export const ORDER_PAY_WINDOW_MS = CHARGE_TTL_MIN * 60_000;
/** Toleransi sebelum pesanan dibatalkan otomatis, memberi waktu notifikasi Midtrans yang terlambat. */
export const SWEEP_GRACE_MS = 2 * 60_000;

/** Metode yang dimatikan lewat env PAYMENT_DISABLED_METHODS (daftar dipisah koma), mis. bila belum aktif di akun production. */
export function enabledMethods(disabledEnv = process.env.PAYMENT_DISABLED_METHODS) {
  const disabled = new Set((disabledEnv ?? '').split(',').map((s) => s.trim()).filter(Boolean));
  return PAY_METHODS.filter((m) => !disabled.has(m.key));
}

export const methodInfo = (key: string | null | undefined) => PAY_METHODS.find((m) => m.key === key);

/** ID transaksi per percobaan di Midtrans. */
export const attemptId = (orderCode: string, attempt: number) => `${orderCode}-${attempt}`;

/** Kode order dari ID transaksi Midtrans: membuang akhiran `-<angka>` (percobaan). Tanpa akhiran = apa adanya (baris lama). */
export function deriveOrderCode(midtransId: string): string {
  return midtransId.replace(/-\d+$/, '');
}

/** 'YYYY-MM-DD HH:mm:ss' (WIB, format Midtrans) -> Date. */
export function wibToDate(s: string | undefined | null): Date | null {
  if (!s || !/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(s)) return null;
  const d = new Date(`${s.replace(' ', 'T')}+07:00`);
  return Number.isNaN(d.getTime()) ? null : d;
}

// ---------- item_details ----------

export interface ItemDetail {
  id: string;
  name: string;
  price: number;
  quantity: number;
}

export interface OrderForCharge {
  subtotal: number;
  discount: number;
  deliveryFee: number;
  total: number;
  items: { productId: string; name: string; qty: number; unitPrice: number }[];
}

/**
 * Baris rincian untuk Midtrans. Jumlahnya HARUS sama dengan gross_amount; bila tidak (data tak terduga),
 * jatuh ke satu baris total agar charge tidak ditolak.
 */
export function buildItemDetails(o: OrderForCharge): ItemDetail[] {
  const rows: ItemDetail[] = o.items.map((i, idx) => ({
    id: `${i.productId}-${idx}`.slice(0, 50),
    name: i.name.slice(0, 50),
    price: i.unitPrice,
    quantity: i.qty,
  }));
  if (o.discount > 0) rows.push({ id: 'DISCOUNT', name: 'Diskon voucher', price: -o.discount, quantity: 1 });
  const pointDiscount = o.subtotal - o.discount + o.deliveryFee - o.total;
  if (pointDiscount > 0) rows.push({ id: 'POINTS', name: 'Tukar poin', price: -pointDiscount, quantity: 1 });
  if (o.deliveryFee > 0) rows.push({ id: 'DELIVERY', name: 'Ongkos kirim', price: o.deliveryFee, quantity: 1 });
  const sum = rows.reduce((s, r) => s + r.price * r.quantity, 0);
  return sum === o.total ? rows : [{ id: 'ORDER', name: 'Pesanan', price: o.total, quantity: 1 }];
}

// ---------- payload charge ----------

export interface ChargeInput {
  midtransOrderId: string;
  amount: number;
  items: ItemDetail[];
  customer: { name?: string | null; phone: string };
  returnUrl: string;
  /** Nomor akun OVO (62… atau 08…). Wajib untuk metode ovo. */
  ovoPhone?: string;
}

export function buildChargePayload(method: PayMethod, input: ChargeInput): Record<string, unknown> {
  const common = {
    transaction_details: { order_id: input.midtransOrderId, gross_amount: input.amount },
    item_details: input.items,
    customer_details: { first_name: (input.customer.name ?? 'Pelanggan').slice(0, 50), phone: input.customer.phone },
    custom_expiry: { expiry_duration: CHARGE_TTL_MIN, unit: 'minute' },
  };
  switch (method) {
    case 'qris':
      return { ...common, payment_type: 'qris', qris: { acquirer: 'gopay' } };
    case 'gopay':
      return { ...common, payment_type: 'gopay', gopay: { enable_callback: true, callback_url: input.returnUrl } };
    case 'shopeepay':
      return { ...common, payment_type: 'shopeepay', shopeepay: { callback_url: input.returnUrl } };
    case 'ovo':
      if (!input.ovoPhone) throw new Error('Nomor OVO wajib untuk metode ovo');
      return { ...common, payment_type: 'ovo', ovo: { payer_phone_number: input.ovoPhone } };
    case 'bca_va':
      return { ...common, payment_type: 'bank_transfer', bank_transfer: { bank: 'bca' } };
    case 'bni_va':
      return { ...common, payment_type: 'bank_transfer', bank_transfer: { bank: 'bni' } };
    case 'bri_va':
      return { ...common, payment_type: 'bank_transfer', bank_transfer: { bank: 'bri' } };
    case 'permata_va':
      return { ...common, payment_type: 'bank_transfer', bank_transfer: { bank: 'permata' } };
    case 'mandiri_va':
      return { ...common, payment_type: 'echannel', echannel: { bill_info1: 'Pembayaran:', bill_info2: 'Pesanan' } };
  }
}

// ---------- respons charge ----------

export interface ChargeResponse {
  status_code?: string;
  status_message?: string;
  transaction_id?: string;
  expiry_time?: string;
  qr_string?: string;
  actions?: { name: string; method?: string; url: string }[];
  va_numbers?: { bank: string; va_number: string }[];
  permata_va_number?: string;
  bill_key?: string;
  biller_code?: string;
  payer_phone_number?: string;
}

export interface ChargeResult {
  transactionId: string | null;
  expiresAt: Date | null;
  qrString: string | null;
  qrImageUrl: string | null;
  deeplinkUrl: string | null;
  vaBank: string | null;
  vaNumber: string | null;
  billerCode: string | null;
  billKey: string | null;
  payerPhone: string | null;
}

const VA_BANK: Partial<Record<PayMethod, string>> = { bca_va: 'bca', bni_va: 'bni', bri_va: 'bri', permata_va: 'permata' };

/** Charge dianggap berhasil dibuat bila status_code 200/201 (Midtrans sering membalas HTTP 200 dengan status_code 4xx di body). */
export const isChargeCreated = (b: ChargeResponse) => b.status_code === '201' || b.status_code === '200';

/** Ambil data yang dibutuhkan client dari respons charge. Melempar Error bila respons tidak lengkap untuk metode itu. */
export function parseChargeResponse(method: PayMethod, b: ChargeResponse): ChargeResult {
  const action = (name: string) => b.actions?.find((a) => a.name === name)?.url ?? null;
  const out: ChargeResult = {
    transactionId: b.transaction_id ?? null,
    expiresAt: wibToDate(b.expiry_time),
    qrString: null,
    qrImageUrl: null,
    deeplinkUrl: null,
    vaBank: null,
    vaNumber: null,
    billerCode: null,
    billKey: null,
    payerPhone: null,
  };
  const need = (cond: unknown, what: string) => {
    if (!cond) throw new Error(`Respons Midtrans untuk ${method} tidak berisi ${what}`);
  };

  switch (method) {
    case 'qris':
      out.qrString = b.qr_string || null;
      out.qrImageUrl = action('generate-qr-code-v2') ?? action('generate-qr-code');
      need(out.qrString, 'qr_string');
      break;
    case 'gopay':
      // qr_string GoPay kosong di sandbox; QR tersedia sebagai gambar PNG publik.
      out.qrString = b.qr_string || null;
      out.qrImageUrl = action('generate-qr-code-v2') ?? action('generate-qr-code');
      out.deeplinkUrl = action('deeplink-redirect');
      need(out.qrString || out.qrImageUrl || out.deeplinkUrl, 'QR atau deeplink');
      break;
    case 'shopeepay':
      out.deeplinkUrl = action('deeplink-redirect');
      need(out.deeplinkUrl, 'deeplink');
      break;
    case 'ovo':
      out.payerPhone = b.payer_phone_number ?? null;
      break;
    case 'bca_va':
    case 'bni_va':
    case 'bri_va': {
      const bank = VA_BANK[method];
      const va = b.va_numbers?.find((v) => v.bank === bank) ?? b.va_numbers?.[0];
      need(va?.va_number, 'va_numbers');
      out.vaBank = va!.bank;
      out.vaNumber = va!.va_number;
      break;
    }
    case 'permata_va':
      need(b.permata_va_number, 'permata_va_number');
      out.vaBank = 'permata';
      out.vaNumber = b.permata_va_number!;
      break;
    case 'mandiri_va':
      need(b.bill_key && b.biller_code, 'bill_key/biller_code');
      out.billerCode = b.biller_code!;
      out.billKey = b.bill_key!;
      break;
  }
  return out;
}

// ---------- status ----------

export interface NotificationLike {
  transaction_status: string;
  fraud_status?: string;
  payment_type?: string;
  va_numbers?: { bank: string }[];
  permata_va_number?: string;
}

export type Outcome = 'PAID' | 'PENDING' | 'FAILED' | 'EXPIRED';

export function mapStatus(n: Pick<NotificationLike, 'transaction_status' | 'fraud_status'>): Outcome {
  switch (n.transaction_status) {
    case 'settlement':
      return 'PAID';
    case 'capture':
      return n.fraud_status === 'accept' ? 'PAID' : 'PENDING';
    case 'expire':
      return 'EXPIRED';
    case 'deny':
    case 'cancel':
    case 'failure':
      return 'FAILED';
    default:
      return 'PENDING';
  }
}

/** Kunci metode kita dari notifikasi (dipakai untuk percobaan lama yang tidak tercatat sebagai metode terbaru). */
export function methodKeyFromNotification(n: NotificationLike): string | null {
  switch (n.payment_type) {
    case 'qris':
    case 'gopay':
    case 'shopeepay':
    case 'ovo':
      return n.payment_type;
    case 'echannel':
      return 'mandiri_va';
    case 'bank_transfer': {
      if (n.permata_va_number) return 'permata_va';
      const bank = n.va_numbers?.[0]?.bank;
      return bank ? `${bank}_va` : null;
    }
    default:
      return n.payment_type ?? null; // mis. credit_card pada pembayaran Snap lama
  }
}

// ---------- idempotensi & batas waktu ----------

export interface ChargeState {
  method: string | null;
  status: 'PENDING' | 'PAID' | 'FAILED' | 'EXPIRED' | 'REFUNDED';
  expiresAt: Date | null;
}

/** Charge yang ada dipakai ulang bila metodenya sama, masih PENDING, dan belum kedaluwarsa. */
export function canReuseCharge(existing: ChargeState | null, method: string, now = new Date()): boolean {
  return !!existing && existing.method === method && existing.status === 'PENDING' && !!existing.expiresAt && existing.expiresAt > now;
}

/** Batas akhir pesanan boleh menunggu bayar: 30 menit sejak dibuat, atau sampai charge terakhir kedaluwarsa bila lebih lama. */
export function orderPayDeadline(createdAt: Date, paymentExpiresAt: Date | null): Date {
  const base = createdAt.getTime() + ORDER_PAY_WINDOW_MS;
  return new Date(Math.max(base, paymentExpiresAt?.getTime() ?? 0));
}

/** Kapan job kedaluwarsa boleh membatalkan pesanan: lewat batas akhir + toleransi. */
export const shouldSweep = (createdAt: Date, paymentExpiresAt: Date | null, now = new Date()) =>
  now.getTime() > orderPayDeadline(createdAt, paymentExpiresAt).getTime() + SWEEP_GRACE_MS;

// ---------- PaymentView ----------

export interface PaymentRow {
  method: string | null;
  status: 'PENDING' | 'PAID' | 'FAILED' | 'EXPIRED' | 'REFUNDED';
  amount: number | null;
  expiresAt: Date | null;
  paidAt: Date | null;
  qrString: string | null;
  qrImageUrl: string | null;
  deeplinkUrl: string | null;
  vaBank: string | null;
  vaNumber: string | null;
  billerCode: string | null;
  billKey: string | null;
  payerPhone: string | null;
}

export interface PaymentView {
  orderId: string;
  method: string | null;
  group: PayGroup | 'other';
  status: PaymentRow['status'];
  amount: number;
  expiresAt: string | null;
  paidAt: string | null;
  qrString?: string;
  qrImageUrl?: string;
  deeplinkUrl?: string;
  va?: { bank: string; number: string };
  bill?: { billerCode: string; billKey: string };
  ovo?: { phone: string };
}

/** Bentuk respons ke client; field kosong dihilangkan. `group` 'other' untuk baris lama (Snap/kartu). */
export function toPaymentView(orderId: string, orderTotal: number, p: PaymentRow): PaymentView {
  const view: PaymentView = {
    orderId,
    method: p.method,
    group: methodInfo(p.method)?.group ?? 'other',
    status: p.status,
    amount: p.amount ?? orderTotal,
    expiresAt: p.expiresAt?.toISOString() ?? null,
    paidAt: p.paidAt?.toISOString() ?? null,
  };
  if (p.qrString) view.qrString = p.qrString;
  if (p.qrImageUrl) view.qrImageUrl = p.qrImageUrl;
  if (p.deeplinkUrl) view.deeplinkUrl = p.deeplinkUrl;
  if (p.vaBank && p.vaNumber) view.va = { bank: p.vaBank, number: p.vaNumber };
  if (p.billerCode && p.billKey) view.bill = { billerCode: p.billerCode, billKey: p.billKey };
  if (p.method === 'ovo' && p.payerPhone) view.ovo = { phone: p.payerPhone };
  return view;
}
