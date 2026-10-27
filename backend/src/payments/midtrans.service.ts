import { BadGatewayException, Injectable, Logger } from '@nestjs/common';
import { createHash, timingSafeEqual } from 'node:crypto';
import { isChargeCreated, type ChargeResponse } from './payments.logic.js';

export interface MidtransNotification {
  order_id: string;
  status_code: string;
  gross_amount: string;
  signature_key: string;
  transaction_status: string;
  fraud_status?: string;
  payment_type?: string;
  va_numbers?: { bank: string; va_number?: string }[];
  permata_va_number?: string;
  biller_code?: string;
}

@Injectable()
export class MidtransService {
  private readonly logger = new Logger(MidtransService.name);

  private get serverKey() {
    const key = process.env.MIDTRANS_SERVER_KEY;
    if (!key) throw new BadGatewayException('Pembayaran belum dikonfigurasi');
    return key;
  }

  private get base() {
    return process.env.MIDTRANS_IS_PRODUCTION === 'true' ? 'https://api.midtrans.com' : 'https://api.sandbox.midtrans.com';
  }

  private get authHeader() {
    return 'Basic ' + Buffer.from(`${this.serverKey}:`).toString('base64');
  }

  /**
   * Buat charge lewat Core API. Detail kesalahan hanya masuk log server; client menerima pesan umum.
   * Core API sering membalas HTTP 200 dengan status_code 4xx di body, jadi keberhasilan dicek dari body.
   */
  async charge(payload: Record<string, unknown>): Promise<ChargeResponse> {
    let res: Response;
    try {
      res = await fetch(`${this.base}/v2/charge`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json', Authorization: this.authHeader },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(15_000),
      });
    } catch (err) {
      this.logger.error(`Charge gagal (jaringan): ${err instanceof Error ? err.message : err}`);
      throw new BadGatewayException('Gagal menghubungi layanan pembayaran, coba lagi');
    }
    const body = (await res.json().catch(() => ({}))) as ChargeResponse & { validation_messages?: string[] };
    if (!res.ok || !isChargeCreated(body)) {
      this.logger.error(`Charge ditolak (HTTP ${res.status}, status_code ${body.status_code}): ${body.status_message} ${JSON.stringify(body.validation_messages ?? '')}`);
      throw new BadGatewayException('Metode pembayaran ini sedang tidak tersedia, coba metode lain');
    }
    return body;
  }

  /** Batalkan transaksi pending. Best-effort: kegagalan hanya dicatat (mis. sudah dibayar atau tidak ada). */
  async cancel(midtransOrderId: string): Promise<void> {
    try {
      const res = await fetch(`${this.base}/v2/${encodeURIComponent(midtransOrderId)}/cancel`, {
        method: 'POST',
        headers: { Accept: 'application/json', Authorization: this.authHeader },
        signal: AbortSignal.timeout(10_000),
      });
      const b = (await res.json().catch(() => ({}))) as { status_code?: string; status_message?: string };
      if (b.status_code !== '200') this.logger.warn(`Cancel ${midtransOrderId}: ${b.status_code} ${b.status_message}`);
    } catch (err) {
      this.logger.warn(`Cancel ${midtransOrderId} gagal: ${err instanceof Error ? err.message : err}`);
    }
  }

  /** Ambil status transaksi langsung dari Midtrans (respons berbentuk sama dengan notifikasi webhook, termasuk signature_key). */
  async getStatus(midtransOrderId: string): Promise<MidtransNotification | null> {
    const res = await fetch(`${this.base}/v2/${encodeURIComponent(midtransOrderId)}/status`, {
      headers: { Accept: 'application/json', Authorization: this.authHeader },
      signal: AbortSignal.timeout(10_000),
    });
    const body = (await res.json().catch(() => null)) as (MidtransNotification & { status_code?: string }) | null;
    // 404 = transaksi belum ada di Midtrans; bukan error.
    if (!body || body.status_code === '404' || !body.transaction_status) return null;
    return body;
  }

  /** signature_key = SHA512(order_id + status_code + gross_amount + serverKey) */
  verifySignature(n: MidtransNotification): boolean {
    const expected = createHash('sha512')
      .update(n.order_id + n.status_code + n.gross_amount + this.serverKey)
      .digest();
    let given: Buffer;
    try {
      given = Buffer.from(n.signature_key ?? '', 'hex');
    } catch {
      return false;
    }
    return given.length === expected.length && timingSafeEqual(given, expected);
  }
}
