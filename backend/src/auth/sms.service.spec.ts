import { afterEach, describe, expect, it, vi } from 'vitest';
import { SmsService } from './sms.service.js';

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

function mockFetch(status: number, body: unknown) {
  const fn = vi.fn(async () => new Response(JSON.stringify(body), { status }));
  vi.stubGlobal('fetch', fn);
  return fn;
}

describe('SmsService konfigurasi', () => {
  it('production menolak penyedia console', () => {
    vi.stubEnv('NODE_ENV', 'production');
    vi.stubEnv('SMS_PROVIDER', 'console');
    expect(() => new SmsService()).toThrow(/wajib diisi/);
  });
  it('menolak konfigurasi twilio yang belum lengkap', () => {
    vi.stubEnv('SMS_PROVIDER', 'twilio');
    vi.stubEnv('TWILIO_ACCOUNT_SID', 'ACxxx');
    expect(() => new SmsService()).toThrow(/TWILIO_AUTH_TOKEN/);
  });
  it('kode OTP hanya boleh muncul di respons pada mode console non-production', () => {
    vi.stubEnv('SMS_PROVIDER', 'console');
    vi.stubEnv('NODE_ENV', 'development');
    expect(new SmsService().exposesCodeInResponse).toBe(true);
  });
});

describe('SmsService twilio', () => {
  const env = () => {
    vi.stubEnv('SMS_PROVIDER', 'twilio');
    vi.stubEnv('TWILIO_ACCOUNT_SID', 'ACtest');
    vi.stubEnv('TWILIO_AUTH_TOKEN', 'tok');
    vi.stubEnv('TWILIO_FROM', '+15005550006');
  };

  it('mengirim form ke API Twilio dengan nomor E.164', async () => {
    env();
    const fetchFn = mockFetch(201, { sid: 'SM1' });
    await new SmsService().send('6281234567890', 'halo');
    const [url, init] = fetchFn.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://api.twilio.com/2010-04-01/Accounts/ACtest/Messages.json');
    const body = init.body as URLSearchParams;
    expect(body.get('To')).toBe('+6281234567890');
    expect(body.get('From')).toBe('+15005550006');
    expect((init.headers as Record<string, string>).Authorization).toBe('Basic ' + Buffer.from('ACtest:tok').toString('base64'));
  });

  it('memakai Messaging Service bila pengirim berawalan MG', async () => {
    env();
    vi.stubEnv('TWILIO_FROM', 'MG123');
    const fetchFn = mockFetch(201, {});
    await new SmsService().send('6281234567890', 'halo');
    const body = (fetchFn.mock.calls[0] as unknown as [string, RequestInit])[1].body as URLSearchParams;
    expect(body.get('MessagingServiceSid')).toBe('MG123');
    expect(body.has('From')).toBe(false);
  });

  it('melempar error saat Twilio menolak', async () => {
    env();
    mockFetch(400, { message: 'invalid number', code: 21211 });
    await expect(new SmsService().send('6281234567890', 'halo')).rejects.toThrow(/21211/);
  });
});

describe('SmsService zenziva', () => {
  const env = () => {
    vi.stubEnv('SMS_PROVIDER', 'zenziva');
    vi.stubEnv('ZENZIVA_USERKEY', 'uk');
    vi.stubEnv('ZENZIVA_PASSKEY', 'pk');
  };

  it('sukses bila status = 1', async () => {
    env();
    const fetchFn = mockFetch(200, { status: '1', text: 'Success' });
    await new SmsService().send('6281234567890', 'halo');
    const init = (fetchFn.mock.calls[0] as unknown as [string, RequestInit])[1];
    expect(JSON.parse(init.body as string)).toEqual({ userkey: 'uk', passkey: 'pk', to: '6281234567890', message: 'halo' });
  });

  it('gagal walau HTTP 200 bila status bukan 1', async () => {
    env();
    mockFetch(200, { status: '0', text: 'Invalid userkey' });
    await expect(new SmsService().send('6281234567890', 'halo')).rejects.toThrow(/Invalid userkey/);
  });
});
