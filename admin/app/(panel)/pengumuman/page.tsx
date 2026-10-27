'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { useMe } from '../layout';

const MAX_TITLE = 80;
const MAX_BODY = 500;

export default function AnnouncementPage() {
  const me = useMe();
  const router = useRouter();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState<number | null>(null);

  useEffect(() => { if (me.role !== 'ADMIN') router.replace('/'); }, [me.role, router]);
  if (me.role !== 'ADMIN') return null;

  const t = title.trim(), b = body.trim();
  const ready = t.length > 0 && b.length > 0 && !busy;

  async function send() {
    if (!confirm(`Kirim "${t}" ke semua pelanggan?\n\nPengumuman muncul di kotak masuk app mereka dan tidak bisa ditarik kembali.`)) return;
    setBusy(true);
    setError(null);
    setSent(null);
    try {
      const r = await api<{ sent: number }>('/admin/notifications/broadcast', { method: 'POST', body: { title: t, body: b } });
      setSent(r.sent);
      setTitle('');
      setBody('');
    } catch (e) {
      setError((e instanceof Error ? e.message : 'Gagal mengirim').split(' | ').join('\n'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="dash">
      <h1 style={{ margin: 0 }}>Pengumuman</h1>
      <p className="muted" style={{ margin: 0, maxWidth: 760 }}>
        Kirim pengumuman ke kotak masuk <strong>semua pelanggan</strong> (bukan staff atau admin). Cocok untuk promo, jam operasional khusus, atau menu baru.
        Dibatasi 5 pengumuman per hari per admin agar pelanggan tidak kebanjiran.
      </p>
      {error && <p className="error" style={{ whiteSpace: 'pre-line', margin: 0 }}>{error}</p>}
      {sent !== null && <p style={{ margin: 0, color: 'var(--ok)' }}>✓ Terkirim ke {sent.toLocaleString('id-ID')} pelanggan.</p>}

      <div className="two" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 16, alignItems: 'start' }}>
        <form className="card" style={{ display: 'grid', gap: 12 }} onSubmit={(e) => { e.preventDefault(); if (ready) send(); }}>
          <label className="muted" style={{ display: 'grid', gap: 4 }}>
            Judul
            <input value={title} maxLength={MAX_TITLE} placeholder="mis. Diskon 20% akhir pekan" onChange={(e) => setTitle(e.target.value)} />
            <span style={{ fontSize: 12, textAlign: 'right' }}>{title.length}/{MAX_TITLE}</span>
          </label>
          <label className="muted" style={{ display: 'grid', gap: 4 }}>
            Isi pengumuman
            <textarea value={body} maxLength={MAX_BODY} rows={6} placeholder="Tulis isi pengumuman yang singkat dan jelas." onChange={(e) => setBody(e.target.value)} />
            <span style={{ fontSize: 12, textAlign: 'right' }}>{body.length}/{MAX_BODY}</span>
          </label>
          <div><button type="submit" className="primary" disabled={!ready}>{busy ? 'Mengirim…' : 'Kirim ke semua pelanggan'}</button></div>
        </form>

        <figure className="viz">
          <figcaption><strong>Pratinjau di app pelanggan</strong><div className="muted" style={{ fontSize: 13 }}>Seperti inilah pengumuman tampil di kotak masuk</div></figcaption>
          <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start', marginTop: 10, padding: 14, borderRadius: 14, border: '1px solid var(--line)', background: 'var(--card)' }}>
            <div aria-hidden style={{ width: 40, height: 40, flex: 'none', borderRadius: 999, display: 'grid', placeItems: 'center', background: 'color-mix(in srgb, var(--brand) 14%, transparent)', fontSize: 20 }}>📣</div>
            <div style={{ minWidth: 0 }}>
              <div style={{ fontWeight: 700, overflowWrap: 'anywhere' }}>{t || 'Judul pengumuman'}</div>
              <div className="muted" style={{ marginTop: 2, whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>{b || 'Isi pengumuman akan tampil di sini.'}</div>
              <div className="muted" style={{ fontSize: 12, marginTop: 6 }}>Baru saja • Promo</div>
            </div>
          </div>
        </figure>
      </div>
    </div>
  );
}
