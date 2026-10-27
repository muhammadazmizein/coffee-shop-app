'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { api, rupiah } from '@/lib/api';
import { useMe } from '../layout';

interface Outlet {
  id: string; name: string; address: string; isActive: boolean; openHour: number; closeHour: number; lat: string; lng: string; phone: string | null;
  deliveryRadiusKm: string; deliveryBaseFee: number; deliveryBaseKm: string; deliveryPerKmFee: number;
}
interface Courier { id: string; outletId: string; name: string; phone: string; isActive: boolean }

/** Perkiraan saja untuk membantu pemilik menyetel tarif; hitungan resmi dilakukan server. */
function previewFee(km: number, base: number, baseKm: number, perKm: number) {
  return km <= baseKm ? base : base + Math.ceil(km - baseKm) * perKm;
}

export default function OutletPage() {
  const me = useMe();
  const router = useRouter();
  const [outlets, setOutlets] = useState<Outlet[]>([]);
  const [couriers, setCouriers] = useState<Courier[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => { if (me.role !== 'ADMIN') router.replace('/'); }, [me.role, router]);

  const load = useCallback(async () => {
    try {
      const [o, c] = await Promise.all([api<Outlet[]>('/admin/outlets'), api<Courier[]>('/admin/couriers')]);
      setOutlets(o);
      setCouriers(c);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat');
    }
  }, []);
  useEffect(() => { if (me.role === 'ADMIN') load(); }, [load, me.role]);

  if (me.role !== 'ADMIN') return null;
  return (
    <div className="dash">
      <h1 style={{ margin: 0 }}>Outlet & kurir</h1>
      <p className="muted" style={{ margin: 0 }}>Pengantaran memakai kurir kafe sendiri. Pelanggan hanya bisa memesan delivery jika alamatnya berada dalam jarak maksimum dari outlet.</p>
      {error && <p className="error">{error}</p>}
      {outlets.map((o) => (
        <OutletCard key={o.id} outlet={o} couriers={couriers.filter((c) => c.outletId === o.id)} onChange={load} />
      ))}
    </div>
  );
}

function OutletCard({ outlet, couriers, onChange }: { outlet: Outlet; couriers: Courier[]; onChange: () => Promise<void> }) {
  const [f, setF] = useState({
    name: outlet.name, address: outlet.address, phone: outlet.phone ? '0' + outlet.phone.replace(/^62/, '') : '', lat: String(Number(outlet.lat)), lng: String(Number(outlet.lng)), openHour: String(outlet.openHour), closeHour: String(outlet.closeHour),
    radius: String(Number(outlet.deliveryRadiusKm)), baseFee: String(outlet.deliveryBaseFee),
    baseKm: String(Number(outlet.deliveryBaseKm)), perKm: String(outlet.deliveryPerKmFee),
  });
  const [busy, setBusy] = useState(false);
  const [courier, setCourier] = useState({ name: '', phone: '' });

  const radius = Number(f.radius), baseKm = Number(f.baseKm), baseFee = Number(f.baseFee), perKm = Number(f.perKm);
  const samples = [0.5, baseKm, (baseKm + radius) / 2, radius].filter((v, i, a) => radius > 0 && v > 0 && a.indexOf(v) === i).map((v) => Math.round(v * 10) / 10);

  async function run(fn: () => Promise<unknown>) {
    setBusy(true);
    try { await fn(); await onChange(); } catch (e) { alert(e instanceof Error ? e.message : 'Gagal menyimpan'); } finally { setBusy(false); }
  }

  const save = () => run(async () => {
    const lat = Number(f.lat), lng = Number(f.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) throw new Error('Koordinat tidak valid');
    await api(`/admin/outlets/${outlet.id}`, {
    method: 'PATCH',
    body: {
      name: f.name.trim(), address: f.address.trim(), phone: f.phone.trim() === '' ? null : f.phone.trim(), lat, lng, openHour: Number(f.openHour), closeHour: Number(f.closeHour),
      deliveryRadiusKm: radius, deliveryBaseFee: baseFee, deliveryBaseKm: baseKm, deliveryPerKmFee: perKm,
    },
  });
  });

  const input = (k: keyof typeof f, label: string, props: React.InputHTMLAttributes<HTMLInputElement> = {}) => (
    <label className="muted" style={{ display: 'grid', gap: 4 }}>{label}
      <input value={f[k]} onChange={(e) => setF({ ...f, [k]: e.target.value })} {...props} />
    </label>
  );

  return (
    <section className="card" style={{ display: 'grid', gap: 16, opacity: outlet.isActive ? 1 : 0.7 }}>
      <div className="row between">
        <h2 style={{ margin: 0 }}>{outlet.name}</h2>
        <button className={outlet.isActive ? '' : 'danger'} disabled={busy} onClick={() => run(() => api(`/admin/outlets/${outlet.id}`, { method: 'PATCH', body: { isActive: !outlet.isActive } }))}>
          {outlet.isActive ? 'Outlet aktif' : 'Outlet nonaktif'}
        </button>
      </div>
      <div className="grid2">
        {input('name', 'Nama')}
        {input('address', 'Alamat')}
        {input('phone', 'Telepon outlet (opsional)', { type: 'tel', placeholder: '0812… atau (021) …' })}
        {input('lat', 'Latitude outlet', { type: 'number', step: 'any' })}
        {input('lng', 'Longitude outlet', { type: 'number', step: 'any' })}
        <div style={{ display: 'grid', alignContent: 'end' }}>
          <button type="button" onClick={() => {
            if (!navigator.geolocation) return alert('Browser tidak mendukung lokasi');
            navigator.geolocation.getCurrentPosition(
              (p) => setF((cur) => ({ ...cur, lat: p.coords.latitude.toFixed(6), lng: p.coords.longitude.toFixed(6) })),
              () => alert('Tidak bisa membaca lokasi. Izinkan akses lokasi di browser, atau isi koordinat manual (klik kanan titik di Google Maps).'),
            );
          }}>Pakai lokasi perangkat ini</button>
        </div>
        {input('openHour', 'Jam buka (0–23)', { type: 'number', min: 0, max: 23 })}
        {input('closeHour', 'Jam tutup (1–24)', { type: 'number', min: 1, max: 24 })}
      </div>

      <div>
        <strong>Pengantaran</strong>
        <div className="grid2" style={{ marginTop: 8 }}>
          {input('radius', 'Jarak maksimum (km) — 0 = tanpa delivery', { type: 'number', min: 0, max: 50, step: 0.1 })}
          {input('baseFee', 'Tarif dasar (Rp)', { type: 'number', min: 0, step: 500 })}
          {input('baseKm', 'Tarif dasar berlaku sampai (km)', { type: 'number', min: 0, max: 50, step: 0.1 })}
          {input('perKm', 'Tambahan per km berikutnya (Rp)', { type: 'number', min: 0, step: 500 })}
        </div>
        <p className="muted" style={{ margin: '8px 0 0' }}>
          {radius <= 0 ? 'Delivery dimatikan: pelanggan hanya bisa pickup.' : <>Perkiraan ongkir: {samples.map((km) => `${km} km → ${rupiah(previewFee(km, baseFee, baseKm, perKm))}`).join(' • ')}</>}
        </p>
      </div>
      <div><button className="primary" disabled={busy} onClick={save}>Simpan pengaturan</button></div>

      <div>
        <strong>Kurir</strong>
        <table>
          <tbody>
            {couriers.length === 0 && <tr><td className="muted">Belum ada kurir. Tanpa kurir, pesanan delivery tidak bisa dikirim.</td></tr>}
            {couriers.map((c) => (
              <tr key={c.id} style={c.isActive ? undefined : { opacity: 0.55 }}>
                <td>{c.name}</td><td className="muted">{c.phone}</td>
                <td style={{ textAlign: 'right' }}>
                  <button onClick={() => {
                    const name = prompt('Nama kurir', c.name); if (name === null) return;
                    const phone = prompt('Nomor HP', c.phone); if (phone === null) return;
                    run(() => api(`/admin/couriers/${c.id}`, { method: 'PATCH', body: { name: name.trim(), phone: phone.trim() } }));
                  }}>Ubah</button>{' '}
                  <button onClick={() => run(() => api(`/admin/couriers/${c.id}`, { method: 'PATCH', body: { isActive: !c.isActive } }))}>{c.isActive ? 'Aktif' : 'Nonaktif'}</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <form className="row" style={{ marginTop: 8 }} onSubmit={(e) => {
          e.preventDefault();
          run(async () => { await api('/admin/couriers', { method: 'POST', body: { outletId: outlet.id, name: courier.name.trim(), phone: courier.phone.trim() } }); setCourier({ name: '', phone: '' }); });
        }}>
          <input required placeholder="Nama kurir" value={courier.name} onChange={(e) => setCourier({ ...courier, name: e.target.value })} />
          <input required placeholder="No. HP (08…)" value={courier.phone} onChange={(e) => setCourier({ ...courier, phone: e.target.value })} />
          <button disabled={busy}>Tambah kurir</button>
        </form>
      </div>
    </section>
  );
}
