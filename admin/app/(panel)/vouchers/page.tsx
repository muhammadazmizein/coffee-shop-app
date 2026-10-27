'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { api, rupiah } from '@/lib/api';
import { useMe } from '../layout';

interface Voucher {
  id: string;
  code: string;
  type: 'PERCENT' | 'FIXED';
  value: number;
  minSpend: number;
  maxDiscount: number | null;
  quota: number;
  used: number;
  startsAt: string;
  endsAt: string;
  isActive: boolean;
}

const day = (iso: string) => new Date(iso).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
const empty = { code: '', type: 'PERCENT', value: '', minSpend: '0', maxDiscount: '', quota: '0', startsAt: '', endsAt: '' };

export default function VouchersPage() {
  const me = useMe();
  const router = useRouter();
  const [list, setList] = useState<Voucher[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState(empty);

  useEffect(() => { if (me.role !== 'ADMIN') router.replace('/'); }, [me.role, router]);

  const load = useCallback(async () => {
    try {
      setList(await api<Voucher[]>('/admin/vouchers'));
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat');
    }
  }, []);

  useEffect(() => { if (me.role === 'ADMIN') load(); }, [load, me.role]);

  async function create(e: React.FormEvent) {
    e.preventDefault();
    try {
      await api('/admin/vouchers', {
        method: 'POST',
        body: {
          code: form.code.trim().toUpperCase(),
          type: form.type,
          value: Number(form.value),
          minSpend: Number(form.minSpend),
          ...(form.maxDiscount ? { maxDiscount: Number(form.maxDiscount) } : {}),
          quota: Number(form.quota),
          // Tanggal dipilih sebagai hari penuh WIB: mulai 00:00, berakhir 23:59:59.
          startsAt: new Date(form.startsAt + 'T00:00:00+07:00').toISOString(),
          endsAt: new Date(form.endsAt + 'T23:59:59+07:00').toISOString(),
        },
      });
      setForm(empty);
      await load();
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Gagal membuat voucher');
    }
  }

  async function toggle(v: Voucher) {
    try {
      await api(`/admin/vouchers/${v.id}`, { method: 'PATCH', body: { isActive: !v.isActive } });
      await load();
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Gagal menyimpan');
    }
  }

  if (me.role !== 'ADMIN') return null;

  return (
    <>
      <h1>Voucher</h1>
      {error && <p className="error">{error}</p>}
      <form className="card" style={{ marginBottom: 16, display: 'grid', gap: 10 }} onSubmit={create}>
        <div className="grid2">
          <input required placeholder="KODE (huruf besar/angka)" value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} />
          <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
            <option value="PERCENT">Persen (%)</option>
            <option value="FIXED">Nominal (Rp)</option>
          </select>
          <input required type="number" min={1} placeholder={form.type === 'PERCENT' ? 'Persen' : 'Nominal'} value={form.value} onChange={(e) => setForm({ ...form, value: e.target.value })} />
          <input type="number" min={0} placeholder="Min. belanja" value={form.minSpend} onChange={(e) => setForm({ ...form, minSpend: e.target.value })} />
          <input type="number" min={1} placeholder="Maks. diskon (opsional)" value={form.maxDiscount} onChange={(e) => setForm({ ...form, maxDiscount: e.target.value })} />
          <input type="number" min={0} placeholder="Kuota (0 = tanpa batas)" value={form.quota} onChange={(e) => setForm({ ...form, quota: e.target.value })} />
          <label className="muted">Mulai <input required type="date" value={form.startsAt} onChange={(e) => setForm({ ...form, startsAt: e.target.value })} /></label>
          <label className="muted">Berakhir <input required type="date" value={form.endsAt} onChange={(e) => setForm({ ...form, endsAt: e.target.value })} /></label>
        </div>
        <div><button className="primary">Buat voucher</button></div>
      </form>
      <div className="card scroll-x">
        <table>
          <thead><tr><th>Kode</th><th>Diskon</th><th>Min. belanja</th><th>Terpakai</th><th>Periode</th><th></th></tr></thead>
          <tbody>
            {list.map((v) => (
              <tr key={v.id} style={v.isActive ? undefined : { opacity: 0.55 }}>
                <td><strong>{v.code}</strong></td>
                <td>{v.type === 'PERCENT' ? `${v.value}%` : rupiah(v.value)}{v.maxDiscount ? ` (maks ${rupiah(v.maxDiscount)})` : ''}</td>
                <td>{rupiah(v.minSpend)}</td>
                <td>{v.used}{v.quota > 0 ? ` / ${v.quota}` : ' / ∞'}</td>
                <td>{day(v.startsAt)} – {day(v.endsAt)}</td>
                <td><button onClick={() => toggle(v)}>{v.isActive ? 'Nonaktifkan' : 'Aktifkan'}</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
