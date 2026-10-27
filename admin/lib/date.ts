const WIB_MS = 7 * 3600_000;
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/** Tanggal hari ini (atau `d`) di zona WIB, format YYYY-MM-DD. */
export const wibDate = (d = new Date()) => new Date(d.getTime() + WIB_MS).toISOString().slice(0, 10);

export function shiftDay(day: string, n: number): string {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/** '2026-10-23' -> '23 Okt' */
export function fmtDay(day: string): string {
  const [, m, d] = day.split('-').map(Number);
  return `${d} ${MONTHS[m - 1]}`;
}

export function fmtDayLong(day: string): string {
  const [y, m, d] = day.split('-').map(Number);
  return `${d} ${MONTHS[m - 1]} ${y}`;
}

export const fmtDateTime = (iso: string) =>
  new Date(iso).toLocaleString('id-ID', { timeZone: 'Asia/Jakarta', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', hour12: false });

export interface Range { from: string; to: string }

export const PRESETS: { key: string; label: string; range: () => Range }[] = [
  { key: 'today', label: 'Hari ini', range: () => ({ from: wibDate(), to: wibDate() }) },
  { key: '7d', label: '7 hari', range: () => ({ from: shiftDay(wibDate(), -6), to: wibDate() }) },
  { key: '30d', label: '30 hari', range: () => ({ from: shiftDay(wibDate(), -29), to: wibDate() }) },
  { key: 'month', label: 'Bulan ini', range: () => ({ from: wibDate().slice(0, 8) + '01', to: wibDate() }) },
];
