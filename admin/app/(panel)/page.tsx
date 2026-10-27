'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { api, rupiah } from '@/lib/api';

interface Item {
  id: string;
  name: string;
  qty: number;
  note: string | null;
  options: { name: string }[];
}
interface Order {
  id: string;
  code: string;
  type: 'PICKUP' | 'DELIVERY';
  status: string;
  total: number;
  note: string | null;
  createdAt: string;
  items: Item[];
  address: { recipient: string; phone: string; detail: string } | null;
  user: { name: string | null; phone: string };
  outletId: string;
  courier: { id: string; name: string; phone: string } | null;
}
interface Courier { id: string; outletId: string; name: string; phone: string; isActive: boolean }

type Next = { to: string; label: string };

const COLUMNS: { status: string; title: string }[] = [
  { status: 'PAID', title: 'Baru masuk' },
  { status: 'PREPARING', title: 'Diproses' },
  { status: 'READY', title: 'Siap' },
  { status: 'ON_DELIVERY', title: 'Diantar' },
];

function nextAction(o: Order): Next | null {
  switch (o.status) {
    case 'PAID': return { to: 'PREPARING', label: 'Mulai buat' };
    case 'PREPARING': return { to: 'READY', label: 'Tandai siap' };
    case 'READY': return o.type === 'DELIVERY' ? { to: 'ON_DELIVERY', label: 'Kirim' } : { to: 'COMPLETED', label: 'Sudah diambil' };
    case 'ON_DELIVERY': return { to: 'COMPLETED', label: 'Selesai' };
    default: return null;
  }
}

const time = (iso: string) => new Date(iso).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });

export default function OrdersPage() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [couriers, setCouriers] = useState<Courier[]>([]);
  const [picking, setPicking] = useState<string | null>(null);
  const [courierId, setCourierId] = useState('');
  const seen = useRef<Set<string> | null>(null);
  const [fresh, setFresh] = useState<Set<string>>(new Set());

  const load = useCallback(async () => {
    try {
      const all = await api<Order[]>('/staff/orders');
      const active = all.filter((o) => COLUMNS.some((c) => c.status === o.status));
      // Tandai pesanan yang baru muncul sejak polling sebelumnya (bukan saat load pertama).
      if (seen.current) {
        const added = active.filter((o) => !seen.current!.has(o.id)).map((o) => o.id);
        if (added.length) setFresh((f) => new Set([...f, ...added]));
      }
      seen.current = new Set(active.map((o) => o.id));
      setOrders(active);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat');
    }
  }, []);

  useEffect(() => { api<Courier[]>('/admin/couriers').then(setCouriers).catch(() => {}); }, []);

  useEffect(() => {
    load();
    const t = setInterval(load, 5000);
    return () => clearInterval(t);
  }, [load]);

  async function move(o: Order, status: string, courier?: string) {
    if (status === 'CANCELLED' && !confirm(`Batalkan ${o.code}? Pesanan sudah dibayar, refund harus diproses manual di dashboard Midtrans.`)) return;
    setBusyId(o.id);
    try {
      await api(`/staff/orders/${o.id}/status`, { method: 'PATCH', body: { status, ...(courier ? { courierId: courier } : {}) } });
      setPicking(null);
      await load();
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal mengubah status');
      await load();
    } finally {
      setBusyId(null);
    }
  }

  return (
    <>
      <h1>Pesanan aktif</h1>
      {error && <p className="error">{error}</p>}
      <div className="board">
        {COLUMNS.map((col) => {
          const list = orders.filter((o) => o.status === col.status);
          return (
            <section key={col.status} className="col">
              <h2>
                {col.title} <span className="tag">{list.length}</span>
              </h2>
              <div className="stack">
                {list.length === 0 && <span className="muted">Kosong</span>}
                {list.map((o) => {
                  const next = nextAction(o);
                  return (
                    <article key={o.id} className="card" style={fresh.has(o.id) ? { borderColor: 'var(--brand)', borderWidth: 2 } : undefined} onClick={() => setFresh((f) => { const n = new Set(f); n.delete(o.id); return n; })}>
                      <div className="row between">
                        <strong>{o.code}</strong>
                        <span className="tag">{o.type === 'PICKUP' ? 'Pickup' : 'Delivery'} • {time(o.createdAt)}</span>
                      </div>
                      <div className="muted">{o.user.name ?? o.user.phone}</div>
                      {o.courier && <div className="muted">🛵 {o.courier.name} ({o.courier.phone})</div>}
                      <ul style={{ paddingLeft: 18, margin: '8px 0' }}>
                        {o.items.map((i) => (
                          <li key={i.id}>
                            <strong>{i.qty}×</strong> {i.name}
                            {i.options.length > 0 && <span className="muted"> — {i.options.map((x) => x.name).join(', ')}</span>}
                            {i.note && <div className="muted">“{i.note}”</div>}
                          </li>
                        ))}
                      </ul>
                      {o.note && <div className="muted">Catatan: {o.note}</div>}
                      {o.address && (
                        <div className="muted">
                          📍 {o.address.recipient} ({o.address.phone}) — {o.address.detail}
                        </div>
                      )}
                      <div className="row between" style={{ marginTop: 10 }}>
                        <strong>{rupiah(o.total)}</strong>
                        <div className="row">
                          {(o.status === 'PAID' || o.status === 'PREPARING') && (
                            <button className="danger" disabled={busyId === o.id} onClick={(e) => { e.stopPropagation(); move(o, 'CANCELLED'); }}>Batalkan</button>
                          )}
                          {next && next.to !== 'ON_DELIVERY' && (
                            <button className="primary" disabled={busyId === o.id} onClick={(e) => { e.stopPropagation(); move(o, next.to); }}>{next.label}</button>
                          )}
                          {next && next.to === 'ON_DELIVERY' && picking !== o.id && (
                            <button className="primary" disabled={busyId === o.id} onClick={(e) => { e.stopPropagation(); setPicking(o.id); setCourierId(''); }}>{next.label}</button>
                          )}
                        </div>
                      </div>
                      {picking === o.id && (
                        <div className="row" style={{ marginTop: 10 }} onClick={(e) => e.stopPropagation()}>
                          <select value={courierId} onChange={(e) => setCourierId(e.target.value)} aria-label="Pilih kurir">
                            <option value="">Pilih kurir…</option>
                            {couriers.filter((c) => c.isActive && c.outletId === o.outletId).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                          </select>
                          <button className="primary" disabled={!courierId || busyId === o.id} onClick={() => move(o, 'ON_DELIVERY', courierId)}>Berangkat</button>
                          <button onClick={() => setPicking(null)}>Batal</button>
                          {couriers.filter((c) => c.isActive && c.outletId === o.outletId).length === 0 && <span className="error">Belum ada kurir aktif di outlet ini</span>}
                        </div>
                      )}
                    </article>
                  );
                })}
              </div>
            </section>
          );
        })}
      </div>
    </>
  );
}
