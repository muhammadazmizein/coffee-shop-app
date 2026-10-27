'use client';

import { Fragment, useCallback, useEffect, useState } from 'react';
import { api, assetUrl, rupiah, uploadFile } from '@/lib/api';
import { useMe } from '../layout';
import OptionsEditor, { type OptionGroupItem } from './options-editor';

interface Outlet { id: string; name: string }
interface Category { id: string; name: string }
interface Product {
  id: string;
  name: string;
  price: number;
  isActive: boolean;
  imageUrl: string | null;
  category: { name: string };
  stock: { outletId: string; isAvailable: boolean }[];
  optionGroups: OptionGroupItem[];
}

export default function MenuPage() {
  const me = useMe();
  const isAdmin = me.role === 'ADMIN';
  const [products, setProducts] = useState<Product[]>([]);
  const [outlets, setOutlets] = useState<Outlet[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({ categoryId: '', name: '', price: '' });
  const [openId, setOpenId] = useState<string | null>(null);
  const [uploadingId, setUploadingId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [p, o] = await Promise.all([api<Product[]>('/admin/products'), api<Outlet[]>('/admin/outlets')]);
      setProducts(p);
      setOutlets(o);
      if (isAdmin) setCategories(await api<Category[]>('/admin/categories'));
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat');
    }
  }, [isAdmin]);

  useEffect(() => { load(); }, [load]);

  async function act(fn: () => Promise<unknown>) {
    try {
      await fn();
      await load();
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal menyimpan');
    }
  }

  async function changePhoto(p: Product, file: File | undefined) {
    if (!file) return;
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) return alert('Format foto harus JPEG, PNG, atau WebP');
    if (file.size > 3 * 1024 * 1024) return alert('Ukuran foto melebihi 3 MB');
    setUploadingId(p.id);
    await act(() => uploadFile(`/admin/products/${p.id}/image`, file));
    setUploadingId(null);
  }

  const available = (p: Product, outletId: string) => p.stock.find((s) => s.outletId === outletId)?.isAvailable ?? true;

  function editPrice(p: Product) {
    const v = prompt(`Harga baru untuk ${p.name} (Rp)`, String(p.price));
    if (v === null) return;
    const price = Number(v);
    if (!Number.isInteger(price) || price < 0) return alert('Harga harus bilangan bulat ≥ 0');
    act(() => api(`/admin/products/${p.id}`, { method: 'PATCH', body: { price } }));
  }

  return (
    <>
      <h1>Menu</h1>
      {error && <p className="error">{error}</p>}
      {isAdmin && (
        <form
          className="card row"
          style={{ marginBottom: 16 }}
          onSubmit={(e) => {
            e.preventDefault();
            act(async () => {
              await api('/admin/products', { method: 'POST', body: { categoryId: form.categoryId, name: form.name, price: Number(form.price) } });
              setForm({ ...form, name: '', price: '' });
            });
          }}
        >
          <select required value={form.categoryId} onChange={(e) => setForm({ ...form, categoryId: e.target.value })}>
            <option value="">Kategori…</option>
            {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
          <input required placeholder="Nama produk" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <input required type="number" min={0} placeholder="Harga" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} />
          <button className="primary">Tambah produk</button>
          <span className="muted">Setelah produk dibuat, klik “Opsi” untuk menambah ukuran, gula, atau topping.</span>
        </form>
      )}
      <div className="card scroll-x">
        <table>
          <thead>
            <tr>
              <th>Produk</th><th>Kategori</th><th>Harga</th>
              {isAdmin && <th>Foto</th>}
              {isAdmin && <th>Status</th>}
              {isAdmin && <th>Opsi</th>}
              {outlets.map((o) => <th key={o.id}>Tersedia di {o.name}</th>)}
            </tr>
          </thead>
          <tbody>
            {products.map((p) => (
              <Fragment key={p.id}>
              <tr style={p.isActive ? undefined : { opacity: 0.55 }}>
                <td>{p.name}</td>
                <td className="muted">{p.category.name}</td>
                <td>
                  {rupiah(p.price)} {isAdmin && <button onClick={() => editPrice(p)}>Ubah</button>}
                </td>
                {isAdmin && (
                  <td>
                    <div className="row" style={{ flexWrap: 'nowrap' }}>
                      {assetUrl(p.imageUrl) ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={assetUrl(p.imageUrl)!} alt={`Foto ${p.name}`} width={48} height={48} style={{ objectFit: 'cover', borderRadius: 8, flex: 'none' }} />
                      ) : (
                        <span className="muted" style={{ width: 48, textAlign: 'center', fontSize: 12, flex: 'none' }}>Belum ada</span>
                      )}
                      <label className="btn" style={{ opacity: uploadingId === p.id ? 0.5 : 1 }}>
                        {uploadingId === p.id ? 'Mengunggah…' : p.imageUrl ? 'Ganti' : 'Unggah'}
                        <input type="file" accept="image/jpeg,image/png,image/webp" hidden disabled={uploadingId === p.id}
                          onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ''; changePhoto(p, f); }} />
                      </label>
                      {p.imageUrl && (
                        <button className="danger" disabled={uploadingId === p.id} onClick={() => confirm(`Hapus foto ${p.name}?`) && act(() => api(`/admin/products/${p.id}/image`, { method: 'DELETE' }))}>Hapus foto</button>
                      )}
                    </div>
                  </td>
                )}
                {isAdmin && (
                  <td>
                    <button onClick={() => act(() => api(`/admin/products/${p.id}`, { method: 'PATCH', body: { isActive: !p.isActive } }))}>
                      {p.isActive ? 'Aktif' : 'Nonaktif'}
                    </button>
                  </td>
                )}
                {isAdmin && (
                  <td>
                    <button onClick={() => setOpenId(openId === p.id ? null : p.id)}>
                      {openId === p.id ? 'Tutup' : `Opsi (${p.optionGroups.length})`}
                    </button>
                  </td>
                )}
                {outlets.map((o) => {
                  const on = available(p, o.id);
                  return (
                    <td key={o.id}>
                      <button
                        className={on ? '' : 'danger'}
                        onClick={() => act(() => api(`/admin/outlets/${o.id}/products/${p.id}`, { method: 'PUT', body: { isAvailable: !on } }))}
                      >
                        {on ? 'Ada' : 'Habis'}
                      </button>
                    </td>
                  );
                })}
              </tr>
              {isAdmin && openId === p.id && (
                <tr>
                  <td colSpan={6 + outlets.length}>
                    <OptionsEditor productId={p.id} groups={p.optionGroups} onChange={load} />
                  </td>
                </tr>
              )}
              </Fragment>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
