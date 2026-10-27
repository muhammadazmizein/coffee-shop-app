import { Injectable, Logger } from '@nestjs/common';

type Provider = 'console' | 'twilio' | 'zenziva';

/**
 * Pengiriman SMS. Penyedia dipilih lewat SMS_PROVIDER:
 *  - console : hanya mencatat ke log (khusus development)
 *  - twilio  : TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM (nomor pengirim atau Messaging Service SID "MG...")
 *  - zenziva : ZENZIVA_USERKEY, ZENZIVA_PASSKEY
 * Di production penyedia asli wajib dikonfigurasi; aplikasi menolak start jika tidak.
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);
  readonly provider: Provider;

  constructor() {
    const name = (process.env.SMS_PROVIDER ?? 'console').toLowerCase();
    if (name !== 'console' && name !== 'twilio' && name !== 'zenziva') {
      throw new Error(`SMS_PROVIDER tidak dikenal: ${name}`);
    }
    this.provider = name;
    if (process.env.NODE_ENV === 'production' && name === 'console') {
      throw new Error('SMS_PROVIDER wajib diisi (twilio/zenziva) di production');
    }
    const required: Record<Provider, string[]> = {
      console: [],
      twilio: ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_FROM'],
      zenziva: ['ZENZIVA_USERKEY', 'ZENZIVA_PASSKEY'],
    };
    const missing = required[name].filter((k) => !process.env[k]);
    if (missing.length) throw new Error(`Env SMS belum diisi: ${missing.join(', ')}`);
  }

  /** true jika kode OTP boleh dikembalikan di respons API (hanya mode console non-production). */
  get exposesCodeInResponse() {
    return this.provider === 'console' && process.env.NODE_ENV !== 'production';
  }

  /** `to` dalam format 62xxxxxxxxxx. Melempar error jika penyedia menolak. */
  async send(to: string, text: string): Promise<void> {
    switch (this.provider) {
      case 'console':
        this.logger.log(`[DEV SMS → ${to}] ${text}`);
        return;
      case 'twilio':
        return this.sendTwilio(to, text);
      case 'zenziva':
        return this.sendZenziva(to, text);
    }
  }

  private async sendTwilio(to: string, text: string) {
    const sid = process.env.TWILIO_ACCOUNT_SID!;
    const from = process.env.TWILIO_FROM!;
    const body = new URLSearchParams({ To: `+${to}`, Body: text });
    body.set(from.startsWith('MG') ? 'MessagingServiceSid' : 'From', from);
    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: 'POST',
      headers: {
        Authorization: 'Basic ' + Buffer.from(`${sid}:${process.env.TWILIO_AUTH_TOKEN}`).toString('base64'),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) {
      const err = (await res.json().catch(() => ({}))) as { message?: string; code?: number };
      throw new Error(`Twilio ${res.status}: ${err.message ?? 'gagal'} (code ${err.code ?? '-'})`);
    }
  }

  private async sendZenziva(to: string, text: string) {
    const res = await fetch('https://console.zenziva.net/reguler/api/sendsms/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userkey: process.env.ZENZIVA_USERKEY,
        passkey: process.env.ZENZIVA_PASSKEY,
        to,
        message: text,
      }),
      signal: AbortSignal.timeout(10_000),
    });
    const data = (await res.json().catch(() => ({}))) as { status?: string | number; text?: string };
    if (!res.ok || String(data.status) !== '1') {
      throw new Error(`Zenziva ${res.status}: ${data.text ?? 'gagal'}`);
    }
  }
}
