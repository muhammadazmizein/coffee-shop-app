'use client';

import { useCallback, useEffect, useState } from 'react';
import DateRangeFilter from '@/components/DateRangeFilter';
import { api, getToken, rupiah } from '@/lib/api';
import { fmtDateTime, PRESETS, type Range } from '@/lib/date';
import { METHOD_LABEL, STATUS_ICON, STATUS_LABEL, statusTone, TYPE_LABEL } from '@/lib/status';
import { useMe } from '../layout';

interface Row {
  id: string; code: string; type: string; status: string; total: number; createdAt: string;
  outlet: { name: string }; user: { name: string | null; phone: string }; payment: { method: string | null } | null;
}
interface ListRes { items: Row[]; total: number; page: number; pageSize: number; salesTotal: number }
interface Detail {
  id: string; code: string; type: string; status: string; subtotal: number; discount: number; memberDiscount: number; tierName: string | null; pointsUsed: number; deliveryFee: number; total: number; note: string | null; createdAt: string;
  outlet: { name: string }; user: { name: string | null; phone: string };
  address: { recipient: string; phone: string; detail: string } | null;
  courier: { name: string; phone: string } | null;
  payment: { status: string; method: string | null; paidAt: string | null; midtransId: string } | null;
  voucher: { code: string } | null;
  items: { id: string; name: string; qty: number; unitPrice: number; note: string | null; options: { name: string }[] }[];
  events: { status: string; note: string | null; createdAt: string; actor: { name: string; role: string } | null }[];
}
interface Outlet { id: string; name: string }

const API = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000';

function StatusTag({ s }: { s: string }) {
  return <span className={`tag ${statusTone(s)}`}>{STATUS_ICON[s]} {STATUS_LABEL[s] ?? s}</span>;
}

export default function HistoryPage() {
  const me = useMe();
  const [range, setRange] = useState<Range>(PRESETS[1].range());
  const [status, setStatus] = useState('');
  const [type, setType] = useState('');
  const [outletId, setOutletId] = useState('');
  const [q, setQ] = useState('');
  const [debouncedQ, setDebouncedQ] = useState('');
  const [page, setPage] = useState(1);
  const [outlets, setOutlets] = useState<Outlet[]>([]);
  const [res, setRes] = useState<ListRes | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [detailId, setDetailId] = useState<string | null>(null);

  useEffect(() => { if (me.role === 'ADMIN') api<Outlet[]>('/admin/outlets').then(setOutlets).catch(() => {}); }, [me.role]);
  useEffect(() => { const t = setTimeout(() => setDebouncedQ(q), 300); return () => clearTimeout(t); }, [q]);
  useEffect(() => { setPage(1); }, [range, status, type, outletId, debouncedQ]);

  const query = useCallback((extra: Record<string, string> = {}) => new URLSearchParams({
    from: range.from, to: range.to,
    ...(status ? { status } : {}), ...(type ? { type } : {}), ...(outletId ? { outletId } : {}), ...(debouncedQ ? { q: debouncedQ } : {}),
    ...extra,
  }), [range, status, type, outletId, debouncedQ]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    api<ListRes>(`/admin/orders?${query({ page: String(page), pageSize: '25' })}`)
      .then((d) => { if (!cancelled) { setRes(d); setError(null); } })
      .catch((e) => { if (!cancelled) setError(e instanceof Error ? e.message : 'Gagal memuat'); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [query, page]);

  async function exportCsv() {
    try {
      const r = await fetch(`${API}/admin/orders/export?${query()}`, { headers: { Authorization: `Bearer ${getToken()}` } });
      if (!r.ok) throw new Error(`Gagal ekspor (${r.status})`);
      const url = URL.createObjectURL(await r.blob());
      const a = document.createElement('a');
      a.href = url;
      a.download = `pesanan_${range.from}_${range.to}.csv`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal ekspor');
    }
  }

  const pages = res ? Math.max(1, Math.ceil(res.total / res.pageSize)) : 1;

  return (
    <div className="dash">
      <h1 style={{ margin: 0 }}>Riwayat pesanan</h1>
      <div className="filters">
        <DateRangeFilter value={range} onChange={setRange} />
        <select aria-label="Status" value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">Semua status</option>
          {Object.entries(STATUS_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>
        <select aria-label="Tipe" value={type} onChange={(e) => setType(e.target.value)}>
          <option value="">Pickup & delivery</option>
          <option value="PICKUP">Pickup</option>
          <option value="DELIVERY">Delivery</option>
        </select>
        {me.role === 'ADMIN' && (
          <select aria-label="Outlet" value={outletId} onChange={(e) => setOutletId(e.target.value)}>
            <option value="">Semua outlet</option>
            {outlets.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
          </select>
        )}
        <input type="search" placeholder="Cari kode / nama / HP" value={q} onChange={(e) => setQ(e.target.value)} />
        <button onClick={exportCsv}>Ekspor CSV</button>
      </div>
      {error && <p className="error">{error}</p>}

      {res && (
        <div className="card scroll-x" style={{ opacity: loading ? 0.55 : 1, transition: 'opacity .15s' }}>
          <div className="row between" style={{ marginBottom: 8 }}>
            <span>{res.total.toLocaleString('id-ID')} pesanan{status && !['COMPLETED', 'PAID', 'PREPARING', 'READY', 'ON_DELIVERY'].includes(status) ? '' : <> • penjualan <strong>{rupiah(res.salesTotal)}</strong></>}</span>
            <span className="muted">Ekspor CSV memuat hingga 5.000 baris</span>
          </div>
          <table>
            <thead>
              <tr><th>Waktu</th><th>Kode</th><th>Pelanggan</th>{me.role === 'ADMIN' && <th>Outlet</th>}<th>Tipe</th><th>Status</th><th>Bayar</th><th style={{ textAlign: 'right' }}>Total</th></tr>
            </thead>
            <tbody>
              {res.items.length === 0 && <tr><td colSpan={8} className="muted">Tidak ada pesanan pada filter ini</td></tr>}
              {res.items.map((o) => (
                <tr key={o.id} onClick={() => setDetailId(o.id)} style={{ cursor: 'pointer' }} tabIndex={0} onKeyDown={(e) => e.key === 'Enter' && setDetailId(o.id)}>
                  <td>{fmtDateTime(o.createdAt)}</td>
                  <td><strong>{o.code}</strong></td>
                  <td>{o.user.name ?? o.user.phone}</td>
                  {me.role === 'ADMIN' && <td>{o.outlet.name}</td>}
                  <td>{TYPE_LABEL[o.type]}</td>
                  <td><StatusTag s={o.status} /></td>
                  <td className="muted">{METHOD_LABEL(o.payment?.method)}</td>
                  <td style={{ textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{rupiah(o.total)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="row between" style={{ marginTop: 12 }}>
            <button disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>← Sebelumnya</button>
            <span className="muted">Halaman {page} dari {pages}</span>
            <button disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Berikutnya →</button>
          </div>
        </div>
      )}
      {!res && loading && <p className="muted">Memuat…</p>}
      {detailId && <OrderDrawer id={detailId} onClose={() => setDetailId(null)} />}
    </div>
  );
}

function OrderDrawer({ id, onClose }: { id: string; onClose: () => void }) {
  const [o, setO] = useState<Detail | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => { api<Detail>(`/admin/orders/${id}`).then(setO).catch((e) => setError(e instanceof Error ? e.message : 'Gagal memuat')); }, [id]);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="overlay" onClick={onClose}>
      <aside className="drawer" onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Detail pesanan">
        <div className="row between">
          <h2 style={{ margin: 0 }}>{o?.code ?? 'Detail pesanan'}</h2>
          <button onClick={onClose} aria-label="Tutup">✕</button>
        </div>
        {error && <p className="error">{error}</p>}
        {!o && !error && <p className="muted">Memuat…</p>}
        {o && (
          <div style={{ display: 'grid', gap: 16, marginTop: 12 }}>
            <div><StatusTag s={o.status} /> <span className="tag">{TYPE_LABEL[o.type]}</span></div>
            <div className="card">
              <div>{o.user.name ?? 'Tanpa nama'} • {o.user.phone}</div>
              <div className="muted">{o.outlet.name} • {fmtDateTime(o.createdAt)}</div>
              {o.address && <div style={{ marginTop: 6 }}>📍 {o.address.recipient} ({o.address.phone}) — {o.address.detail}</div>}
              {o.courier && <div>🛵 Kurir: {o.courier.name} ({o.courier.phone})</div>}
              {o.note && <div className="muted">Catatan: {o.note}</div>}
            </div>
            <div className="card">
              {o.items.map((i) => (
                <div key={i.id} className="row between" style={{ alignItems: 'flex-start', padding: '4px 0' }}>
                  <div>
                    <strong>{i.qty}×</strong> {i.name}
                    {i.options.length > 0 && <div className="muted">{i.options.map((x) => x.name).join(', ')}</div>}
                    {i.note && <div className="muted">“{i.note}”</div>}
                  </div>
                  <span style={{ fontVariantNumeric: 'tabular-nums' }}>{rupiah(i.qty * i.unitPrice)}</span>
                </div>
              ))}
              <hr style={{ border: 0, borderTop: '1px solid var(--line)' }} />
              <Line l="Subtotal" v={rupiah(o.subtotal)} />
              {o.memberDiscount > 0 && <Line l={`Diskon member${o.tierName ? ` (${o.tierName})` : ''}`} v={`-${rupiah(o.memberDiscount)}`} />}
              {o.discount > 0 && <Line l={`Diskon${o.voucher ? ` (${o.voucher.code})` : ''}`} v={`-${rupiah(o.discount)}`} />}
              {o.pointsUsed > 0 && <Line l={`Tukar ${o.pointsUsed} poin`} v={`-${rupiah(o.subtotal - o.memberDiscount - o.discount + o.deliveryFee - o.total)}`} />}
              {o.deliveryFee > 0 && <Line l="Ongkos kirim" v={rupiah(o.deliveryFee)} />}
              <Line l="Total" v={rupiah(o.total)} bold />
            </div>
            {o.payment && (
              <div className="card">
                <strong>Pembayaran</strong>
                <div className="muted">{METHOD_LABEL(o.payment.method)} • {o.payment.status}{o.payment.paidAt ? ` • ${fmtDateTime(o.payment.paidAt)}` : ''}</div>
                <div className="muted">ID Midtrans: {o.payment.midtransId}</div>
              </div>
            )}
            <div>
              <strong>Riwayat status</strong>
              <ol className="timeline">
                {o.events.map((e, i) => (
                  <li key={i}>
                    <div><StatusTag s={e.status} /> <span className="muted">{fmtDateTime(e.createdAt)}</span></div>
                    <div className="muted">{e.actor ? `oleh ${e.actor.name} (${e.actor.role === 'CUSTOMER' ? 'pelanggan' : e.actor.role.toLowerCase()})` : 'sistem'}{e.note ? ` • ${e.note}` : ''}</div>
                  </li>
                ))}
              </ol>
            </div>
          </div>
        )}
      </aside>
    </div>
  );
}

function Line({ l, v, bold }: { l: string; v: string; bold?: boolean }) {
  return <div className="row between" style={{ fontWeight: bold ? 700 : 400 }}><span>{l}</span><span style={{ fontVariantNumeric: 'tabular-nums' }}>{v}</span></div>;
}
