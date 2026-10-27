'use client';

import { useEffect, useState } from 'react';
import { BarList, compact, SeriesChart } from '@/components/charts';
import DateRangeFilter from '@/components/DateRangeFilter';
import { api, rupiah } from '@/lib/api';
import { fmtDay, fmtDayLong, PRESETS, type Range } from '@/lib/date';
import { METHOD_LABEL, STATUS_ICON, STATUS_LABEL, TYPE_LABEL } from '@/lib/status';
import { useMe } from '../layout';

interface Group { key: string; orders: number; revenue: number }
interface Summary {
  range: Range;
  totals: { orders: number; revenue: number; avgOrder: number; discount: number; memberDiscount: number; deliveryFees: number; pointsRedeemed: number };
  daily: { date: string; orders: number; revenue: number }[];
  hourly: { hour: number; orders: number }[];
  byType: Group[]; byOutlet: Group[]; byPayment: Group[];
  topProducts: { name: string; qty: number; revenue: number }[];
  byStatus: { status: string; count: number }[];
}
interface Outlet { id: string; name: string }

const n = (v: number) => v.toLocaleString('id-ID');

export default function ReportPage() {
  const me = useMe();
  const [range, setRange] = useState<Range>(PRESETS[1].range());
  const [outletId, setOutletId] = useState('');
  const [outlets, setOutlets] = useState<Outlet[]>([]);
  const [data, setData] = useState<Summary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (me.role === 'ADMIN') api<Outlet[]>('/admin/outlets').then(setOutlets).catch(() => {});
  }, [me.role]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    const qs = new URLSearchParams({ from: range.from, to: range.to, ...(outletId ? { outletId } : {}) });
    api<Summary>(`/admin/reports/summary?${qs}`)
      .then((d) => { if (!cancelled) { setData(d); setError(null); } })
      .catch((e) => { if (!cancelled) setError(e instanceof Error ? e.message : 'Gagal memuat'); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [range, outletId]);

  const t = data?.totals;
  const days = data?.daily.length ?? 0;

  return (
    <div className="dash">
      <h1 style={{ margin: 0 }}>Laporan penjualan</h1>
      <div className="filters">
        <DateRangeFilter value={range} onChange={setRange} />
        {me.role === 'ADMIN' && (
          <select aria-label="Outlet" value={outletId} onChange={(e) => setOutletId(e.target.value)}>
            <option value="">Semua outlet</option>
            {outlets.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
          </select>
        )}
      </div>
      {error && <p className="error">{error}</p>}

      {data && t && (
        <>
          <p className="muted" style={{ margin: 0 }}>
            {fmtDayLong(data.range.from)} – {fmtDayLong(data.range.to)} • penjualan = pesanan yang sudah dibayar dan tidak dibatalkan
          </p>
          <div className="kpis" style={{ opacity: loading ? 0.55 : 1 }}>
            <div className="kpi hero"><div className="label">Omzet</div><div className="value">{rupiah(t.revenue)}</div></div>
            <div className="kpi"><div className="label">Jumlah pesanan</div><div className="value">{n(t.orders)}</div></div>
            <div className="kpi"><div className="label">Rata-rata per pesanan</div><div className="value">{rupiah(t.avgOrder)}</div></div>
            <div className="kpi"><div className="label">Diskon voucher</div><div className="value">{rupiah(t.discount)}</div>{t.pointsRedeemed > 0 && <div className="muted" style={{ fontSize: 12 }}>+ {n(t.pointsRedeemed)} poin ditukar</div>}</div>
            <div className="kpi"><div className="label">Diskon member</div><div className="value">{rupiah(t.memberDiscount)}</div></div>
            <div className="kpi"><div className="label">Ongkir terkumpul</div><div className="value">{rupiah(t.deliveryFees)}</div></div>
          </div>

          <SeriesChart
            title="Omzet per hari"
            subtitle={days > 45 ? 'Rentang panjang ditampilkan sebagai garis' : undefined}
            points={data.daily.map((d) => ({ key: d.date, label: fmtDay(d.date), value: d.revenue, sub: `${d.orders} pesanan` }))}
            format={rupiah} peakFormat={(v) => compact(v, 2)} valueHeader="Omzet" rowHeader="Tanggal" loading={loading}
          />

          <div className="two">
            <SeriesChart
              title="Pesanan per jam" subtitle="Jam ramai (WIB)" height={220}
              points={data.hourly.map((h) => ({ key: String(h.hour), label: String(h.hour).padStart(2, '0'), value: h.orders }))}
              format={(v) => `${n(v)} pesanan`} axisFormat={(v) => String(v)} integerAxis valueHeader="Pesanan" rowHeader="Jam" loading={loading}
            />
            <BarList
              title="Produk terlaris" subtitle="Berdasarkan jumlah terjual" loading={loading}
              rows={data.topProducts.map((p) => ({ key: p.name, label: p.name, value: p.qty, sub: rupiah(p.revenue) }))}
              format={(v) => `${n(v)} terjual`}
            />
          </div>

          <div className="two">
            <BarList title="Tipe pesanan" loading={loading} rows={data.byType.map((g) => ({ key: g.key, label: TYPE_LABEL[g.key] ?? g.key, value: g.revenue, sub: `${g.orders} pesanan` }))} format={rupiah} />
            <BarList title="Metode pembayaran" loading={loading} rows={data.byPayment.map((g) => ({ key: g.key, label: METHOD_LABEL(g.key), value: g.revenue, sub: `${g.orders} pesanan` }))} format={rupiah} />
            {me.role === 'ADMIN' && !outletId && (
              <BarList title="Per outlet" loading={loading} rows={data.byOutlet.map((g) => ({ key: g.key, label: g.key, value: g.revenue, sub: `${g.orders} pesanan` }))} format={rupiah} />
            )}
          </div>

          <figure className="viz">
            <figcaption><strong>Status pesanan</strong><div className="muted" style={{ fontSize: 13 }}>Semua pesanan pada periode ini, termasuk yang tidak dihitung sebagai penjualan</div></figcaption>
            <div className="scroll-x">
              <table>
                <tbody>
                  {data.byStatus.map((s) => (
                    <tr key={s.status}><td>{STATUS_ICON[s.status]} {STATUS_LABEL[s.status]}</td><td style={{ textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{n(s.count)}</td></tr>
                  ))}
                </tbody>
              </table>
            </div>
          </figure>
        </>
      )}
      {!data && loading && <p className="muted">Memuat…</p>}
    </div>
  );
}
