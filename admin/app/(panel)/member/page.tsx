'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { api, rupiah } from '@/lib/api';
import { useMe } from '../layout';
import CheckinRewards from './checkin-rewards';

interface Tier { id: string; name: string; minSpend: number; earnMultiplierPct: number; discountPct: number; maxDiscount: number | null }
interface Row { key: number; name: string; minSpend: string; earn: string; disc: string; max: string }

const MAX_TIERS = 6;
const HIGH_DISCOUNT = 10; // peringatan margin mulai dari persentase ini
let seq = 0;

const toRow = (t: Tier): Row => ({ key: ++seq, name: t.name, minSpend: String(t.minSpend), earn: String(t.earnMultiplierPct), disc: String(t.discountPct), max: t.maxDiscount == null ? '' : String(t.maxDiscount) });
const blankRow = (prevMin: number): Row => ({ key: ++seq, name: '', minSpend: String(prevMin + 1_000_000), earn: '100', disc: '0', max: '' });
const num = (s: string) => (s.trim() === '' ? NaN : Number(s));
const times = (pct: number) => `${(pct / 100).toString().replace('.', ',')}×`;

/** Pesan server berprefiks "tiers.0." diubah jadi "Level 1: ..." agar mudah dibaca. */
function friendly(msg: string) {
  return msg.split(' | ').map((m) => m.replace(/^tiers\.(\d+)\./, (_, i) => `Level ${Number(i) + 1}: `)).join('\n');
}

export default function MemberPage() {
  const me = useMe();
  const router = useRouter();
  const [rows, setRows] = useState<Row[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  useEffect(() => { if (me.role !== 'ADMIN') router.replace('/'); }, [me.role, router]);

  const load = useCallback(async () => {
    try {
      setRows((await api<Tier[]>('/admin/tiers')).map(toRow));
      setError(null);
      setLoaded(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat');
    }
  }, []);
  useEffect(() => { if (me.role === 'ADMIN') load(); }, [load, me.role]);

  const set = (key: number, patch: Partial<Row>) => { setSaved(false); setRows((rs) => rs.map((r) => (r.key === key ? { ...r, ...patch } : r))); };

  async function save() {
    setBusy(true);
    setError(null);
    setSaved(false);
    try {
      const tiers = rows.map((r, i) => ({
        name: r.name.trim(),
        minSpend: i === 0 ? 0 : num(r.minSpend),
        earnMultiplierPct: num(r.earn),
        discountPct: num(r.disc),
        maxDiscount: r.max.trim() === '' ? null : num(r.max),
      }));
      const out = await api<Tier[]>('/admin/tiers', { method: 'PUT', body: { tiers } });
      setRows(out.map(toRow));
      setSaved(true);
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Gagal menyimpan';
      setError(friendly(msg));
    } finally {
      setBusy(false);
    }
  }

  if (me.role !== 'ADMIN') return null;

  const preview = rows.map((r, i) => {
    const min = i === 0 ? 0 : num(r.minSpend), earn = num(r.earn), disc = num(r.disc), max = r.max.trim() === '' ? null : num(r.max);
    if ([min, earn, disc].some((x) => Number.isNaN(x))) return { key: r.key, text: `${r.name || '(tanpa nama)'}: lengkapi angka di tabel`, example: '' };
    const diskonPesanan = Math.min(Math.floor((100_000 * disc) / 100), max ?? Infinity);
    const poin = Math.floor(((100_000 - diskonPesanan) * earn) / 1_000_000);
    return {
      key: r.key,
      text: `${r.name.trim() || '(tanpa nama)'}: belanja ≥ ${rupiah(min)} • poin ${times(earn)} • ${disc > 0 ? `diskon ${disc}%${max != null ? ` maks ${rupiah(max)}` : ' tanpa batas'}` : 'tanpa diskon'}`,
      example: `Contoh pesanan Rp100.000: ${diskonPesanan > 0 ? `hemat ${rupiah(diskonPesanan)}, ` : ''}dapat ${poin} poin`,
    };
  });

  const field = (r: Row, k: keyof Row, props: React.InputHTMLAttributes<HTMLInputElement> = {}) => (
    <input value={r[k] as string} onChange={(e) => set(r.key, { [k]: e.target.value } as Partial<Row>)} style={{ width: '100%', minWidth: 0 }} {...props} />
  );

  return (
    <div className="dash">
      <h1 style={{ margin: 0 }}>Level member</h1>
      <p className="muted" style={{ margin: 0, maxWidth: 760 }}>
        Level pelanggan ditentukan dari <strong>total belanja terbayar seumur akun</strong>. Diskon level berlaku otomatis di setiap pesanan
        (sebelum voucher dan tukar poin); pengali poin mengalikan poin yang didapat (1,0× = 1 poin tiap Rp10.000). Level hanya turun bila
        pesanan yang sudah dibayar dibatalkan.
      </p>
      {error && <p className="error" style={{ whiteSpace: 'pre-line', margin: 0 }}>{error}</p>}
      {saved && <p style={{ margin: 0, color: 'var(--ok)' }}>✓ Tersimpan. Berlaku untuk pesanan baru; pesanan yang sudah dibuat memakai level saat dibuat.</p>}

      {loaded && (
        <>
          <div className="card scroll-x">
            <table>
              <thead>
                <tr><th style={{ width: 150 }}>Nama level</th><th>Minimal belanja (Rp)</th><th style={{ width: 130 }}>Pengali poin (%)</th><th style={{ width: 110 }}>Diskon (%)</th><th>Maks. diskon/pesanan (Rp)</th><th /></tr>
              </thead>
              <tbody>
                {rows.map((r, i) => {
                  const disc = num(r.disc);
                  const warn = disc >= HIGH_DISCOUNT ? (r.max.trim() === '' ? 'Diskon tinggi tanpa batas: margin bisa tergerus pesanan besar.' : 'Diskon tinggi: pastikan margin cukup.') : disc > 0 && r.max.trim() === '' ? 'Tanpa batas diskon per pesanan.' : null;
                  return (
                    <tr key={r.key}>
                      <td>{field(r, 'name', { maxLength: 20, placeholder: 'mis. Gold' })}</td>
                      <td>{i === 0 ? <input value="0" disabled style={{ width: '100%' }} title="Level pertama selalu mulai dari Rp0" /> : field(r, 'minSpend', { type: 'number', min: 1, step: 50000 })}</td>
                      <td>{field(r, 'earn', { type: 'number', min: 100, max: 500, step: 5 })}</td>
                      <td>{field(r, 'disc', { type: 'number', min: 0, max: 50, step: 1 })}</td>
                      <td>
                        {field(r, 'max', { type: 'number', min: 1, step: 1000, placeholder: 'tanpa batas' })}
                        {warn && <div style={{ fontSize: 12, color: 'var(--warn)', marginTop: 4 }}>⚠ {warn}</div>}
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <button className="danger" disabled={rows.length <= 1} onClick={() => { setSaved(false); setRows((rs) => rs.filter((x) => x.key !== r.key)); }}>Hapus</button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            <div className="row" style={{ marginTop: 12 }}>
              <button disabled={rows.length >= MAX_TIERS} onClick={() => { setSaved(false); setRows((rs) => [...rs, blankRow(Math.max(0, ...rs.map((x) => num(x.minSpend) || 0)))]); }}>+ Tambah level</button>
              <button className="primary" disabled={busy} onClick={save}>{busy ? 'Menyimpan…' : 'Simpan perubahan'}</button>
              <button disabled={busy} onClick={load}>Batalkan perubahan</button>
              <span className="muted">Maksimal {MAX_TIERS} level. Level pertama selalu dari Rp0.</span>
            </div>
          </div>

          <figure className="viz">
            <figcaption><strong>Pratinjau untuk pelanggan</strong><div className="muted" style={{ fontSize: 13 }}>Ringkasan tiap level sesuai isi tabel (belum disimpan bila Anda baru mengubahnya)</div></figcaption>
            <ul style={{ margin: '8px 0 0', padding: 0, listStyle: 'none', display: 'grid', gap: 10 }}>
              {preview.map((p) => (
                <li key={p.key}>
                  <div style={{ fontWeight: 600 }}>{p.text}</div>
                  {p.example && <div className="muted" style={{ fontSize: 13 }}>{p.example}</div>}
                </li>
              ))}
            </ul>
          </figure>
        </>
      )}
      {!loaded && !error && <p className="muted">Memuat…</p>}

      <CheckinRewards />
    </div>
  );
}
