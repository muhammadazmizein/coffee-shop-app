'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { api, setToken, type Me } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [sent, setSent] = useState(false);
  const [devCode, setDevCode] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Terjadi kesalahan');
    } finally {
      setBusy(false);
    }
  }

  const requestOtp = () =>
    run(async () => {
      const r = await api<{ devCode?: string }>('/auth/otp/request', { method: 'POST', body: { phone } });
      setDevCode(r.devCode ?? null);
      setSent(true);
    });

  const verify = () =>
    run(async () => {
      const r = await api<{ token: string }>('/auth/otp/verify', { method: 'POST', body: { phone, code } });
      setToken(r.token);
      const me = await api<Me>('/me');
      if (me.role === 'CUSTOMER') {
        setToken(null);
        throw new Error('Akun ini bukan staff atau admin');
      }
      router.replace('/');
    });

  return (
    <main style={{ maxWidth: 380, marginTop: 80 }}>
      <div className="card" style={{ display: 'grid', gap: 12 }}>
        <h1 style={{ margin: 0 }}>Kopi App Admin</h1>
        <input placeholder="Nomor HP staff" value={phone} disabled={sent || busy} onChange={(e) => setPhone(e.target.value)} />
        {sent && (
          <>
            <input placeholder="Kode OTP 6 digit" value={code} maxLength={6} inputMode="numeric" disabled={busy} onChange={(e) => setCode(e.target.value)} />
            {devCode && <span className="muted">Mode dev: kode {devCode}</span>}
          </>
        )}
        {error && <span className="error">{error}</span>}
        <button className="primary" disabled={busy || !phone || (sent && code.length !== 6)} onClick={sent ? verify : requestOtp}>
          {sent ? 'Masuk' : 'Kirim OTP'}
        </button>
        {sent && (
          <button disabled={busy} onClick={() => { setSent(false); setCode(''); setError(null); }}>
            Ganti nomor
          </button>
        )}
      </div>
    </main>
  );
}
