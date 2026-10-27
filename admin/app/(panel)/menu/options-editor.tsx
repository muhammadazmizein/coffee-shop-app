'use client';

import { useState } from 'react';
import { api, rupiah } from '@/lib/api';

export interface OptionItem { id: string; name: string; extraPrice: number }
export interface OptionGroupItem { id: string; name: string; required: boolean; maxSelect: number; options: OptionItem[] }

export default function OptionsEditor({ productId, groups, onChange }: { productId: string; groups: OptionGroupItem[]; onChange: () => Promise<void> }) {
  const [group, setGroup] = useState({ name: '', required: false, maxSelect: '1' });
  const [newOption, setNewOption] = useState<Record<string, { name: string; price: string }>>({});

  async function act(fn: () => Promise<unknown>) {
    try {
      await fn();
      await onChange();
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal menyimpan');
    }
  }

  function editOption(o: OptionItem) {
    const name = prompt('Nama opsi', o.name);
    if (name === null) return;
    const price = prompt('Tambahan harga (Rp)', String(o.extraPrice));
    if (price === null) return;
    const extraPrice = Number(price);
    if (!name.trim() || !Number.isInteger(extraPrice) || extraPrice < 0) return alert('Nama wajib diisi dan harga bilangan bulat ≥ 0');
    act(() => api(`/admin/options/${o.id}`, { method: 'PATCH', body: { name: name.trim(), extraPrice } }));
  }

  return (
    <div style={{ display: 'grid', gap: 12, padding: '8px 0' }}>
      {groups.length === 0 && <span className="muted">Belum ada opsi. Produk ini langsung masuk keranjang tanpa pilihan.</span>}
      {groups.map((g) => {
        const draft = newOption[g.id] ?? { name: '', price: '0' };
        return (
          <div key={g.id} className="card" style={{ background: 'transparent' }}>
            <div className="row between">
              <strong>{g.name}</strong>
              <div className="row">
                <button onClick={() => act(() => api(`/admin/option-groups/${g.id}`, { method: 'PATCH', body: { required: !g.required } }))}>
                  {g.required ? 'Wajib' : 'Opsional'}
                </button>
                <label className="muted">
                  Maks pilih{' '}
                  <input
                    type="number" min={1} max={10} defaultValue={g.maxSelect} style={{ width: 64 }}
                    onBlur={(e) => {
                      const v = Number(e.target.value);
                      if (v !== g.maxSelect && Number.isInteger(v) && v >= 1 && v <= 10) act(() => api(`/admin/option-groups/${g.id}`, { method: 'PATCH', body: { maxSelect: v } }));
                    }}
                  />
                </label>
                <button className="danger" onClick={() => confirm(`Hapus grup "${g.name}" beserta semua pilihannya?`) && act(() => api(`/admin/option-groups/${g.id}`, { method: 'DELETE' }))}>Hapus grup</button>
              </div>
            </div>
            <table>
              <tbody>
                {g.options.map((o) => (
                  <tr key={o.id}>
                    <td>{o.name}</td>
                    <td className="muted">{o.extraPrice > 0 ? `+${rupiah(o.extraPrice)}` : 'Gratis'}</td>
                    <td style={{ textAlign: 'right' }}>
                      <button onClick={() => editOption(o)}>Ubah</button>{' '}
                      <button className="danger" onClick={() => act(() => api(`/admin/options/${o.id}`, { method: 'DELETE' }))}>Hapus</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            <form
              className="row" style={{ marginTop: 8 }}
              onSubmit={(e) => {
                e.preventDefault();
                act(async () => {
                  await api(`/admin/option-groups/${g.id}/options`, { method: 'POST', body: { name: draft.name.trim(), extraPrice: Number(draft.price) } });
                  setNewOption({ ...newOption, [g.id]: { name: '', price: '0' } });
                });
              }}
            >
              <input required placeholder="Nama pilihan" value={draft.name} onChange={(e) => setNewOption({ ...newOption, [g.id]: { ...draft, name: e.target.value } })} />
              <input required type="number" min={0} placeholder="+Harga" style={{ width: 110 }} value={draft.price} onChange={(e) => setNewOption({ ...newOption, [g.id]: { ...draft, price: e.target.value } })} />
              <button>Tambah pilihan</button>
            </form>
          </div>
        );
      })}
      <form
        className="row"
        onSubmit={(e) => {
          e.preventDefault();
          act(async () => {
            await api(`/admin/products/${productId}/option-groups`, { method: 'POST', body: { name: group.name.trim(), required: group.required, maxSelect: Number(group.maxSelect) } });
            setGroup({ name: '', required: false, maxSelect: '1' });
          });
        }}
      >
        <input required placeholder="Grup baru (mis. Ukuran)" value={group.name} onChange={(e) => setGroup({ ...group, name: e.target.value })} />
        <label className="muted"><input type="checkbox" checked={group.required} onChange={(e) => setGroup({ ...group, required: e.target.checked })} /> Wajib</label>
        <label className="muted">Maks pilih <input type="number" min={1} max={10} style={{ width: 64 }} value={group.maxSelect} onChange={(e) => setGroup({ ...group, maxSelect: e.target.value })} /></label>
        <button className="primary">Tambah grup</button>
      </form>
    </div>
  );
}
