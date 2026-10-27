'use client';

import { useCallback, useEffect, useState } from 'react';
import { api, rupiah } from '@/lib/api';

interface Reward { day: number; points: number }

const POINT_VALUE = 100; // 1 poin = Rp100 (sama dengan aturan tukar poin di checkout)

/** Hadiah poin check-in harian (siklus 7 hari). Poin bernilai uang, jadi total satu siklus ditampilkan dalam rupiah. */
export default function CheckinRewards() {
  const [vals, setVals] = useState<string[]>([]);
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const rows = await api<Reward[]>('/admin/checkin-rewards');
      setVals(rows.map((r) => String(r.points)));
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat hadiah check-in');
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  const nums = vals.map((v) => (v.trim() === '' ? NaN : Number(v)));
  const valid = nums.length === 7 && nums.every((n) => Number.isInteger(n) && n >= 0 && n <= 100);
  const total = nums.reduce((s, n) => s + (Number.isFinite(n) ? n : 0), 0);

  async function save() {
    setBusy(true);
    setError(null);
    setSaved(false);
    try {
      const rows = await api<Reward[]>('/admin/checkin-rewards', { method: 'PUT', body: { rewards: nums.map((points, i) => ({ day: i + 1, points })) } });
      setVals(rows.map((r) => String(r.points)));
      setSaved(true);
    } catch (e) {
      setError((e instanceof Error ? e.message : 'Gagal menyimpan').split(' | ').join('\n'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="card" style={{ display: 'grid', gap: 12 }}>
      <div>
        <h2 style={{ margin: 0, fontSize: 18 }}>Check-in harian</h2>
        <p className="muted" style={{ margin: '4px 0 0', maxWidth: 760 }}>
          Pelanggan check-in sekali sehari (hari WIB) dan mendapat poin sesuai hari ke berapa dalam siklus 7 hari. Bila melewatkan satu hari, siklus kembali ke hari 1;
          setelah hari ke-7 siklus mulai lagi dari hari 1.
        </p>
      </div>
      {error && <p className="error" style={{ whiteSpace: 'pre-line', margin: 0 }}>{error}</p>}
      {saved && <p style={{ margin: 0, color: 'var(--ok)' }}>✓ Tersimpan. Berlaku untuk check-in berikutnya.</p>}
      {vals.length === 7 && (
        <>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(92px, 1fr))', gap: 10 }}>
            {vals.map((v, i) => (
              <label key={i} className="muted" style={{ display: 'grid', gap: 4, fontSize: 13 }}>
                Hari ke-{i + 1}{i === 6 ? ' ★' : ''}
                <input
                  type="number" min={0} max={100} step={1} value={v} aria-label={`Poin hari ke-${i + 1}`}
                  onChange={(e) => { setSaved(false); setVals((vs) => vs.map((x, j) => (j === i ? e.target.value : x))); }}
                  style={{ width: '100%', minWidth: 0 }}
                />
              </label>
            ))}
          </div>
          <p className="muted" style={{ margin: 0 }}>
            1 poin = {rupiah(POINT_VALUE)}. Total hadiah satu siklus penuh = <strong>{total} poin = {rupiah(total * POINT_VALUE)}</strong> per pelanggan yang check-in 7 hari berturut-turut.
          </p>
          {valid && total >= 40 && <p style={{ margin: 0, fontSize: 13, color: 'var(--warn)' }}>⚠ Hadiah cukup besar ({rupiah(total * POINT_VALUE)} per siklus). Pastikan sesuai anggaran promosi; satu orang bisa membuat banyak akun untuk mengumpulkannya.</p>}
          <div className="row">
            <button className="primary" disabled={busy || !valid} onClick={save}>{busy ? 'Menyimpan…' : 'Simpan hadiah check-in'}</button>
            <button disabled={busy} onClick={load}>Batalkan perubahan</button>
            {!valid && <span className="error">Isi 7 bilangan bulat 0 sampai 100.</span>}
          </div>
        </>
      )}
      {vals.length === 0 && !error && <p className="muted" style={{ margin: 0 }}>Memuat…</p>}
    </section>
  );
}
