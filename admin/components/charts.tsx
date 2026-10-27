'use client';

import { useEffect, useRef, useState } from 'react';

export interface Point { key: string; label: string; value: number; sub?: string }

/** 1.200.000 -> "1,2jt"; 3.500 -> "3,5rb" */
export function compact(n: number, digits = 1): string {
  const k = Math.pow(10, digits);
  const f = (v: number, unit: string) => `${String(Math.round(v * k) / k).replace('.', ',')}${unit}`;
  if (n >= 1e9) return f(n / 1e9, 'M');
  if (n >= 1e6) return f(n / 1e6, 'jt');
  if (n >= 1e3) return f(n / 1e3, 'rb');
  return String(n);
}

/** Langkah sumbu "bersih" (1, 2, 2.5, 5 × 10^k) dengan ±4 garis bantu. */
function niceScale(max: number, integer = false): { step: number; top: number } {
  if (max <= 0) return { step: 1, top: 4 };
  const raw = max / 4;
  const e = Math.pow(10, Math.floor(Math.log10(raw)));
  const m = raw / e;
  // Sumbu hitungan (jumlah pesanan) hanya boleh berlangkah bilangan bulat; 2,5 dibuang dari pilihan.
  let step = (m <= 1 ? 1 : m <= 2 ? 2 : m <= 2.5 && !integer ? 2.5 : m <= 5 ? 5 : 10) * e;
  if (integer) step = Math.max(1, Math.ceil(step));
  return { step, top: step * Math.ceil(max / step) };
}

const M = { l: 46, r: 12, t: 22, b: 26 };
const MAX_BAR = 24; // tebal bar maksimum
const GAP = 2; // jarak antar bar (warna permukaan)
const LINE_THRESHOLD = 45; // lebih dari ini: bar terlalu rapat, pakai garis

function useWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [w, setW] = useState(640);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    setW(el.clientWidth || 640);
    const ro = new ResizeObserver(([e]) => setW(Math.max(240, Math.floor(e.contentRect.width))));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, w] as const;
}

/** Bar/kolom (≤45 titik) atau garis+area (>45 titik) untuk satu seri sepanjang urutan (waktu/jam). */
export function SeriesChart({
  title, subtitle, points, format, axisFormat = compact, height = 240, loading = false, valueHeader = 'Nilai', rowHeader = 'Kategori', integerAxis = false, peakFormat,
}: {
  title: string; subtitle?: string; points: Point[]; format: (n: number) => string; axisFormat?: (n: number) => string;
  height?: number; loading?: boolean; valueHeader?: string; rowHeader?: string; integerAxis?: boolean; peakFormat?: (n: number) => string;
}) {
  const [ref, width] = useWidth<HTMLDivElement>();
  const [hover, setHover] = useState<number | null>(null);
  const [table, setTable] = useState(false);

  const n = points.length;
  const plotW = Math.max(width - M.l - M.r, 10);
  const plotH = height - M.t - M.b;
  const maxV = Math.max(0, ...points.map((p) => p.value));
  const { step, top } = niceScale(maxV, integerAxis);
  const ticks = Array.from({ length: Math.round(top / step) + 1 }, (_, i) => i * step);
  const y = (v: number) => M.t + plotH - (v / top) * plotH;
  const base = y(0);
  const band = plotW / Math.max(n, 1);
  const line = n > LINE_THRESHOLD;
  const cx = (i: number) => M.l + band * (i + 0.5);
  const labelEvery = Math.max(1, Math.ceil(n / Math.max(1, Math.floor(plotW / 56))));
  const peak = maxV > 0 ? points.findIndex((p) => p.value === maxV) : -1;

  const barPath = (i: number, v: number) => {
    const w = Math.max(1, Math.min(MAX_BAR, band - GAP));
    const x = cx(i) - w / 2;
    const yt = y(v);
    const h = base - yt;
    if (h <= 0) return '';
    const r = Math.min(4, h, w / 2); // ujung data membulat 4px, sisi baseline lurus
    return `M${x},${base}L${x},${yt + r}Q${x},${yt} ${x + r},${yt}L${x + w - r},${yt}Q${x + w},${yt} ${x + w},${yt + r}L${x + w},${base}Z`;
  };

  const hp = hover !== null ? points[hover] : null;
  const tipLeft = hover !== null ? cx(hover) : 0;
  const flip = tipLeft > width / 2;

  const idxFromEvent = (e: React.PointerEvent<SVGRectElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    return Math.min(n - 1, Math.max(0, Math.floor(((e.clientX - rect.left) / rect.width) * n)));
  };

  return (
    <figure className="viz" style={{ opacity: loading ? 0.55 : 1, transition: 'opacity .15s' }}>
      <figcaption className="row between">
        <div>
          <strong>{title}</strong>
          {subtitle && <div className="muted" style={{ fontSize: 13 }}>{subtitle}</div>}
        </div>
        <button onClick={() => setTable((t) => !t)} aria-pressed={table}>{table ? 'Lihat grafik' : 'Lihat tabel'}</button>
      </figcaption>

      {table ? (
        <div className="scroll-x" style={{ maxHeight: height, overflowY: 'auto', marginTop: 8 }}>
          <table>
            <thead><tr><th>{rowHeader}</th><th style={{ textAlign: 'right' }}>{valueHeader}</th>{points.some((p) => p.sub) && <th>Keterangan</th>}</tr></thead>
            <tbody>
              {points.map((p) => (
                <tr key={p.key}><td>{p.label}</td><td style={{ textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{format(p.value)}</td>{points.some((q) => q.sub) && <td className="muted">{p.sub}</td>}</tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div ref={ref} style={{ position: 'relative', height }} onPointerLeave={() => setHover(null)}>
          <svg width={width} height={height} role="img" aria-label={`${title}. Puncak ${peak >= 0 ? `${points[peak].label}: ${format(maxV)}` : 'tidak ada data'}`}>
            {ticks.map((t) => (
              <g key={t}>
                <line x1={M.l} x2={width - M.r} y1={y(t)} y2={y(t)} stroke={t === 0 ? 'var(--viz-axis)' : 'var(--viz-grid)'} strokeWidth={1} />
                <text x={M.l - 8} y={y(t)} dy="0.32em" textAnchor="end" fontSize={11} fill="var(--viz-muted)" style={{ fontVariantNumeric: 'tabular-nums' }}>{axisFormat(t)}</text>
              </g>
            ))}
            {points.map((p, i) => i % labelEvery === 0 && (
              <text key={p.key} x={cx(i)} y={height - 8} textAnchor="middle" fontSize={11} fill="var(--viz-muted)">{p.label}</text>
            ))}

            {!line && points.map((p, i) => (
              <path key={p.key} d={barPath(i, p.value)} fill={hover === i ? 'var(--series-1-hover)' : 'var(--series-1)'} />
            ))}
            {line && n > 0 && (
              <>
                <path d={`M${cx(0)},${base} ${points.map((p, i) => `L${cx(i)},${y(p.value)}`).join(' ')} L${cx(n - 1)},${base}Z`} fill="var(--series-1)" opacity={0.1} />
                <path d={points.map((p, i) => `${i ? 'L' : 'M'}${cx(i)},${y(p.value)}`).join(' ')} fill="none" stroke="var(--series-1)" strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
              </>
            )}
            {line && hover !== null && (
              <>
                <line x1={cx(hover)} x2={cx(hover)} y1={M.t} y2={base} stroke="var(--viz-axis)" strokeWidth={1} />
                <circle cx={cx(hover)} cy={y(points[hover].value)} r={4} fill="var(--series-1)" stroke="var(--viz-surface)" strokeWidth={2} />
              </>
            )}

            {/* Label langsung hanya di puncak. */}
            {peak >= 0 && (
              <text x={Math.min(Math.max(cx(peak), M.l + 16), width - M.r - 16)} y={y(maxV) - 6} textAnchor="middle" fontSize={11} fontWeight={600} fill="var(--viz-ink-2)">{(peakFormat ?? axisFormat)(maxV)}</text>
            )}

            {/* Area hit penuh per pita: lebih besar dari tandanya, juga dapat fokus keyboard. */}
            {points.map((p, i) => (
              <rect key={p.key} x={M.l + band * i} y={M.t} width={band} height={plotH} fill="transparent" tabIndex={0} aria-label={`${p.label}: ${format(p.value)}`}
                onPointerEnter={() => setHover(i)} onPointerMove={line ? (e) => setHover(idxFromEvent(e)) : undefined} onFocus={() => setHover(i)} onBlur={() => setHover(null)} style={{ outline: 'none' }} />
            ))}
          </svg>
          {hp && (
            <div className="viz-tip" style={{ left: tipLeft, transform: `translateX(${flip ? 'calc(-100% - 10px)' : '10px'})`, top: Math.max(0, y(hp.value) - 44) }} role="status">
              <div className="muted">{hp.label}</div>
              <div><span className="key" /><strong>{format(hp.value)}</strong></div>
              {hp.sub && <div className="muted">{hp.sub}</div>}
            </div>
          )}
        </div>
      )}
    </figure>
  );
}

/** Daftar bar horizontal untuk perbandingan kategori; nilai ditulis di ujung bar. */
export function BarList({ title, subtitle, rows, format, empty = 'Belum ada data', loading = false }: {
  title: string; subtitle?: string; rows: Point[]; format: (n: number) => string; empty?: string; loading?: boolean;
}) {
  const max = Math.max(1, ...rows.map((r) => r.value));
  return (
    <figure className="viz" style={{ opacity: loading ? 0.55 : 1, transition: 'opacity .15s' }}>
      <figcaption>
        <strong>{title}</strong>
        {subtitle && <div className="muted" style={{ fontSize: 13 }}>{subtitle}</div>}
      </figcaption>
      {rows.length === 0 ? <p className="muted">{empty}</p> : (
        <ul className="barlist">
          {rows.map((r) => (
            <li key={r.key} title={r.sub ? `${r.label}: ${format(r.value)} • ${r.sub}` : `${r.label}: ${format(r.value)}`}>
              <span className="lbl">{r.label}</span>
              <span className="track">
                <span className="bar" style={{ width: `calc((100% - 96px) * ${r.value / max})` }} />
                <span className="val">{format(r.value)}</span>
              </span>
              {r.sub && <span className="sub muted">{r.sub}</span>}
            </li>
          ))}
        </ul>
      )}
    </figure>
  );
}
