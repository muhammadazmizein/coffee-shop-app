'use client';

import { PRESETS, type Range } from '@/lib/date';

export default function DateRangeFilter({ value, onChange }: { value: Range; onChange: (r: Range) => void }) {
  const active = PRESETS.find((p) => {
    const r = p.range();
    return r.from === value.from && r.to === value.to;
  })?.key;
  return (
    <div className="row" role="group" aria-label="Rentang tanggal">
      {PRESETS.map((p) => (
        <button key={p.key} className={active === p.key ? 'primary' : ''} onClick={() => onChange(p.range())}>
          {p.label}
        </button>
      ))}
      <input type="date" aria-label="Dari tanggal" value={value.from} max={value.to} onChange={(e) => e.target.value && onChange({ ...value, from: e.target.value })} />
      <span className="muted">–</span>
      <input type="date" aria-label="Sampai tanggal" value={value.to} min={value.from} onChange={(e) => e.target.value && onChange({ ...value, to: e.target.value })} />
    </div>
  );
}
