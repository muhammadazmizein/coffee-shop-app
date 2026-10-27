'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { api, assetUrl, uploadFile } from '@/lib/api';
import { fmtDay, wibDate } from '@/lib/date';
import { ART_OPTIONS, artLabel, artSrc } from '@/lib/promo';
import { useMe } from '../layout';

interface Promo {
  id: string; title: string; body: string; imageUrl: string | null; art: string | null; ctaLabel: string | null;
  voucherCode: string | null; sort: number; isActive: boolean; startsAt: string | null; endsAt: string | null;
}
interface Voucher { code: string; isActive: boolean; startsAt: string; endsAt: string; quota: number; used: number }

const MAX_BYTES = 3 * 1024 * 1024;
const WELCOME_MAX = 8;

const voucherLive = (v: Voucher, now = new Date()) =>
  v.isActive && new Date(v.startsAt) <= now && new Date(v.endsAt) >= now && (v.quota === 0 || v.used < v.quota);

/** Status tayang berdasarkan aktif + periode (tanpa voucher; voucher dicek terpisah). */
function schedule(p: Promo, now = new Date()): { label: string; tone: '' | 'ok' | 'off' } {
  if (!p.isActive) return { label: 'Nonaktif', tone: 'off' };
  if (p.startsAt && new Date(p.startsAt) > now) return { label: `Terjadwal • mulai ${fmtDay(wibDate(new Date(p.startsAt)))}`, tone: '' };
  if (p.endsAt && new Date(p.endsAt) < now) return { label: 'Berakhir', tone: 'off' };
  return { label: 'Aktif', tone: 'ok' };
}

function Slide({ title, body, cta, voucher, img }: { title: string; body: string; cta?: string; voucher?: string; img: string | null }) {
  return (
    <div style={{ width: 240, border: '1px solid var(--line)', borderRadius: 18, overflow: 'hidden', background: 'var(--card)' }} aria-label="Pratinjau slide">
      <div style={{ height: 150, background: '#FBF5EC', display: 'grid', placeItems: 'center', overflow: 'hidden' }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        {img ? <img src={img} alt="" style={{ width: '100%', height: '100%', objectFit: 'contain' }} /> : <span className="muted">Tanpa gambar</span>}
      </div>
      <div style={{ padding: 12, display: 'grid', gap: 6, textAlign: 'center' }}>
        <strong style={{ lineHeight: 1.2 }}>{title || 'Judul promo'}</strong>
        <span className="muted" style={{ fontSize: 13 }}>{body || 'Teks singkat promo'}</span>
        {voucher && <span className="tag" style={{ justifySelf: 'center' }}>Kode {voucher}</span>}
        <button className="primary" type="button" style={{ marginTop: 4 }}>{cta || 'Lanjut'}</button>
      </div>
    </div>
  );
}

export default function PromoPage() {
  const me = useMe();
  const router = useRouter();
  const [list, setList] = useState<Promo[]>([]);
  const [vouchers, setVouchers] = useState<Voucher[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<Promo | 'new' | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  useEffect(() => { if (me.role !== 'ADMIN') router.replace('/'); }, [me.role, router]);

  const load = useCallback(async () => {
    try {
      const [p, v] = await Promise.all([api<Promo[]>('/admin/promos'), api<Voucher[]>('/admin/vouchers')]);
      setList(p);
      setVouchers(v);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat');
    }
  }, []);
  useEffect(() => { if (me.role === 'ADMIN') load(); }, [load, me.role]);

  const voucherByCode = useMemo(() => new Map(vouchers.map((v) => [v.code, v])), [vouchers]);

  async function act(id: string, fn: () => Promise<unknown>) {
    setBusy(id);
    try { await fn(); await load(); } catch (e) { alert(e instanceof Error ? e.message : 'Gagal menyimpan'); } finally { setBusy(null); }
  }

  if (me.role !== 'ADMIN') return null;
  const now = new Date();
  const liveCount = list.filter((p) => schedule(p, now).label === 'Aktif' && (!p.voucherCode || (voucherByCode.get(p.voucherCode) && voucherLive(voucherByCode.get(p.voucherCode)!, now)))).length;

  return (
    <div className="dash">
      <div className="row between">
        <h1 style={{ margin: 0 }}>Promo welcome</h1>
        <button className="primary" onClick={() => setEditing('new')}>Tambah promo</button>
      </div>
      <p className="muted" style={{ margin: 0 }}>
        Slide ini tampil di layar welcome setiap kali pelanggan membuka app, sesuai urutan di bawah. Maksimal {WELCOME_MAX} slide tayang;
        promo ber-voucher otomatis disembunyikan bila vouchernya nonaktif, berakhir, atau kuotanya habis.
        Sekarang tayang: <strong>{liveCount}</strong>{liveCount > WELCOME_MAX && <span className="error"> (hanya {WELCOME_MAX} pertama yang ditampilkan)</span>}.
      </p>
      {error && <p className="error">{error}</p>}

      <div style={{ display: 'grid', gap: 10 }}>
        {list.length === 0 && !error && <div className="card muted">Belum ada promo. Layar welcome app akan memakai slide bawaan.</div>}
        {list.map((p, i) => {
          const s = schedule(p, now);
          const v = p.voucherCode ? voucherByCode.get(p.voucherCode) : undefined;
          const img = assetUrl(p.imageUrl) ?? artSrc(p.art);
          return (
            <article key={p.id} className="card row" style={{ gap: 14, alignItems: 'center', opacity: busy === p.id ? 0.6 : 1 }}>
              <div style={{ width: 72, height: 72, borderRadius: 12, background: '#FBF5EC', display: 'grid', placeItems: 'center', overflow: 'hidden', flex: 'none' }}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                {img ? <img src={img} alt="" style={{ width: '100%', height: '100%', objectFit: p.imageUrl ? 'cover' : 'contain' }} /> : <span className="muted" style={{ fontSize: 11 }}>Kosong</span>}
              </div>
              <div style={{ flex: 1, minWidth: 180 }}>
                <div className="row" style={{ gap: 6 }}>
                  <strong>{p.title}</strong>
                  <span className={`tag ${s.tone}`}>{s.label}</span>
                  {p.imageUrl ? <span className="tag">Foto</span> : p.art && <span className="tag">{artLabel(p.art)}</span>}
                  {p.voucherCode && <span className="tag">Kode {p.voucherCode}</span>}
                  {p.voucherCode && !v && <span className="tag off">⚠ Voucher tidak ditemukan • slide disembunyikan</span>}
                  {p.voucherCode && v && !voucherLive(v, now) && <span className="tag off">⚠ Voucher tidak aktif • slide disembunyikan</span>}
                </div>
                <div className="muted" style={{ fontSize: 13 }}>{p.body}</div>
              </div>
              <div className="row" style={{ gap: 6 }}>
                <button disabled={i === 0 || !!busy} aria-label="Naikkan" onClick={() => act(p.id, () => api(`/admin/promos/${p.id}/move`, { method: 'POST', body: { direction: 'up' } }))}>↑</button>
                <button disabled={i === list.length - 1 || !!busy} aria-label="Turunkan" onClick={() => act(p.id, () => api(`/admin/promos/${p.id}/move`, { method: 'POST', body: { direction: 'down' } }))}>↓</button>
                <button disabled={!!busy} onClick={() => act(p.id, () => api(`/admin/promos/${p.id}`, { method: 'PATCH', body: { isActive: !p.isActive } }))}>{p.isActive ? 'Nonaktifkan' : 'Aktifkan'}</button>
                <button disabled={!!busy} onClick={() => setEditing(p)}>Ubah</button>
                <button className="danger" disabled={!!busy} onClick={() => confirm(`Hapus promo "${p.title}"? Foto yang terunggah ikut terhapus.`) && act(p.id, () => api(`/admin/promos/${p.id}`, { method: 'DELETE' }))}>Hapus</button>
              </div>
            </article>
          );
        })}
      </div>

      {editing && (
        <PromoEditor
          promo={editing === 'new' ? null : editing}
          vouchers={vouchers}
          onClose={() => setEditing(null)}
          onSaved={async () => { await load(); }}
        />
      )}
    </div>
  );
}

function PromoEditor({ promo, vouchers, onClose, onSaved }: { promo: Promo | null; vouchers: Voucher[]; onClose: () => void; onSaved: () => Promise<void> }) {
  const [saved, setSaved] = useState<Promo | null>(promo); // setelah dibuat, editor beralih ke mode ubah
  const [f, setF] = useState({
    title: promo?.title ?? '', body: promo?.body ?? '', art: promo?.art ?? '', ctaLabel: promo?.ctaLabel ?? '',
    voucherCode: promo?.voucherCode ?? '', isActive: promo?.isActive ?? true,
    startsAt: promo?.startsAt ? wibDate(new Date(promo.startsAt)) : '', endsAt: promo?.endsAt ? wibDate(new Date(promo.endsAt)) : '',
  });
  const [pendingFile, setPendingFile] = useState<File | null>(null);
  const [pendingUrl, setPendingUrl] = useState<string | null>(null);
  const [imageUrl, setImageUrl] = useState<string | null>(promo?.imageUrl ?? null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => () => { if (pendingUrl) URL.revokeObjectURL(pendingUrl); }, [pendingUrl]);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  const code = f.voucherCode.trim().toUpperCase();
  const voucher = vouchers.find((v) => v.code === code);
  const voucherWarning = !code ? null : !voucher ? 'Kode ini tidak ada di daftar voucher; slide tidak akan tampil di app.' : !voucherLive(voucher) ? 'Voucher ini sedang tidak aktif/berakhir/kuota habis; slide disembunyikan sampai voucher aktif.' : null;
  const previewImg = pendingUrl ?? assetUrl(imageUrl) ?? artSrc(f.art || null);

  function pick(file: File | undefined) {
    if (!file) return;
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) return setError('Foto harus JPEG, PNG, atau WebP');
    if (file.size > MAX_BYTES) return setError('Ukuran foto melebihi 3 MB');
    setError(null);
    if (saved) {
      // Promo sudah ada: unggah langsung.
      setBusy(true);
      uploadFile<{ imageUrl: string }>(`/admin/promos/${saved.id}/image`, file)
        .then(async (r) => { setImageUrl(r.imageUrl); await onSaved(); })
        .catch((e) => setError(e instanceof Error ? e.message : 'Gagal mengunggah'))
        .finally(() => setBusy(false));
    } else {
      if (pendingUrl) URL.revokeObjectURL(pendingUrl);
      setPendingFile(file);
      setPendingUrl(URL.createObjectURL(file));
    }
  }

  async function removeImage() {
    setError(null);
    if (!saved) { setPendingFile(null); setPendingUrl(null); return; }
    setBusy(true);
    try { await api(`/admin/promos/${saved.id}/image`, { method: 'DELETE' }); setImageUrl(null); await onSaved(); }
    catch (e) { setError(e instanceof Error ? e.message : 'Gagal menghapus foto'); }
    finally { setBusy(false); }
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (code && !/^[A-Z0-9]{3,20}$/.test(code)) return setError('Kode voucher 3-20 karakter huruf besar/angka');
    if (f.startsAt && f.endsAt && f.endsAt < f.startsAt) return setError('Tanggal berakhir tidak boleh sebelum tanggal mulai');
    const body = {
      title: f.title.trim(), body: f.body.trim(), art: f.art || null, ctaLabel: f.ctaLabel.trim() || null, voucherCode: code || null, isActive: f.isActive,
      // Hari penuh WIB: mulai 00:00, berakhir 23:59:59 (sama seperti halaman Voucher).
      startsAt: f.startsAt ? new Date(`${f.startsAt}T00:00:00+07:00`).toISOString() : null,
      endsAt: f.endsAt ? new Date(`${f.endsAt}T23:59:59+07:00`).toISOString() : null,
    };
    setBusy(true);
    try {
      const p = saved ? await api<Promo>(`/admin/promos/${saved.id}`, { method: 'PATCH', body }) : await api<Promo>('/admin/promos', { method: 'POST', body });
      setSaved(p);
      if (pendingFile) {
        try {
          const r = await uploadFile<{ imageUrl: string }>(`/admin/promos/${p.id}/image`, pendingFile);
          setImageUrl(r.imageUrl); setPendingFile(null); setPendingUrl(null);
        } catch (err) {
          await onSaved();
          setError(`Promo tersimpan, tetapi foto gagal diunggah: ${err instanceof Error ? err.message : 'error'}. Coba unggah lagi.`);
          return;
        }
      }
      await onSaved();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal menyimpan');
    } finally {
      setBusy(false);
    }
  }

  const field = (label: string, node: React.ReactNode, hint?: string) => (
    <label style={{ display: 'grid', gap: 4 }}><span className="muted">{label}</span>{node}{hint && <span className="muted" style={{ fontSize: 12 }}>{hint}</span>}</label>
  );

  return (
    <div className="overlay" onClick={onClose}>
      <aside className="drawer" style={{ width: 'min(620px, 100%)' }} onClick={(e) => e.stopPropagation()} role="dialog" aria-label={saved ? 'Ubah promo' : 'Tambah promo'}>
        <div className="row between">
          <h2 style={{ margin: 0 }}>{saved ? 'Ubah promo' : 'Tambah promo'}</h2>
          <button onClick={onClose} aria-label="Tutup">✕</button>
        </div>
        <form onSubmit={save} style={{ display: 'grid', gap: 14, marginTop: 14 }}>
          {field(`Judul (${f.title.length}/60)`, <input required maxLength={60} value={f.title} onChange={(e) => setF({ ...f, title: e.target.value })} />)}
          {field(`Teks (${f.body.length}/160)`, <textarea required maxLength={160} rows={3} value={f.body} onChange={(e) => setF({ ...f, body: e.target.value })} style={{ font: 'inherit', padding: '8px 10px', border: '1px solid var(--line)', borderRadius: 8, background: 'var(--card)', color: 'var(--ink)' }} />)}

          <div className="card" style={{ display: 'grid', gap: 10 }}>
            <strong>Gambar</strong>
            {field('Ilustrasi bawaan', (
              <select value={f.art} onChange={(e) => setF({ ...f, art: e.target.value })}>
                <option value="">Tanpa ilustrasi</option>
                {ART_OPTIONS.map((a) => <option key={a.key} value={a.key}>{a.label}</option>)}
              </select>
            ), 'Dipakai bila tidak ada foto.')}
            <div className="row">
              <label className="btn" style={{ cursor: busy ? 'not-allowed' : 'pointer' }}>
                {imageUrl || pendingFile ? 'Ganti foto' : 'Unggah foto'}
                <input type="file" accept="image/jpeg,image/png,image/webp" hidden disabled={busy} onChange={(e) => { pick(e.target.files?.[0]); e.target.value = ''; }} />
              </label>
              {(imageUrl || pendingFile) && <button type="button" className="danger" disabled={busy} onClick={removeImage}>Hapus foto</button>}
              <span className="muted" style={{ fontSize: 12 }}>JPEG/PNG/WebP ≤ 3 MB. Disarankan persegi atau portrait. Foto menggantikan ilustrasi.</span>
            </div>
            {pendingFile && <span className="muted" style={{ fontSize: 12 }}>Foto &ldquo;{pendingFile.name}&rdquo; akan diunggah saat Anda menyimpan.</span>}
          </div>

          <div className="grid2">
            {field('Label tombol (opsional)', <input maxLength={30} placeholder="mis. Pakai voucher" value={f.ctaLabel} onChange={(e) => setF({ ...f, ctaLabel: e.target.value })} />)}
            {field('Kode voucher (opsional)', (
              <>
                <input list="voucher-codes" maxLength={20} placeholder="mis. HEMAT10" value={f.voucherCode} onChange={(e) => setF({ ...f, voucherCode: e.target.value })} />
                <datalist id="voucher-codes">{vouchers.map((v) => <option key={v.code} value={v.code} />)}</datalist>
              </>
            ))}
            {field('Mulai (opsional)', <input type="date" value={f.startsAt} onChange={(e) => setF({ ...f, startsAt: e.target.value })} />)}
            {field('Berakhir (opsional)', <input type="date" min={f.startsAt || undefined} value={f.endsAt} onChange={(e) => setF({ ...f, endsAt: e.target.value })} />)}
          </div>
          {voucherWarning && <p className="error" style={{ margin: 0 }}>⚠ {voucherWarning}</p>}
          <label className="row" style={{ gap: 8 }}><input type="checkbox" checked={f.isActive} onChange={(e) => setF({ ...f, isActive: e.target.checked })} /> Aktif</label>

          <div>
            <span className="muted">Pratinjau</span>
            <div style={{ marginTop: 6 }}><Slide title={f.title} body={f.body} cta={f.ctaLabel.trim() || (code ? 'Pakai voucher' : undefined)} voucher={code || undefined} img={previewImg} /></div>
          </div>

          {error && <p className="error" style={{ margin: 0 }}>{error}</p>}
          <div className="row">
            <button className="primary" disabled={busy}>{busy ? 'Menyimpan…' : saved ? 'Simpan perubahan' : 'Simpan promo'}</button>
            <button type="button" onClick={onClose}>Tutup</button>
          </div>
        </form>
      </aside>
    </div>
  );
}
