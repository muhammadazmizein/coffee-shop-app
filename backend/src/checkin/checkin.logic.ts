/** Logika murni check-in harian 7 hari (tanpa akses database). Semua tanggal berupa hari WIB 'YYYY-MM-DD'. */

export const CYCLE_DAYS = 7;

/** Hadiah bawaan (1 poin = Rp100, sengaja kecil); dipakai bila tabel kosong/tidak lengkap. */
export const DEFAULT_REWARDS: { day: number; points: number }[] = [
  { day: 1, points: 1 },
  { day: 2, points: 1 },
  { day: 3, points: 2 },
  { day: 4, points: 1 },
  { day: 5, points: 1 },
  { day: 6, points: 2 },
  { day: 7, points: 5 },
];

export function addDays(day: string, n: number): string {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/** Gabungkan hadiah dari database dengan bawaan agar selalu tepat 7 hari. */
export function completeRewards(rows: { day: number; points: number }[]): { day: number; points: number }[] {
  return DEFAULT_REWARDS.map((d) => ({ day: d.day, points: rows.find((r) => r.day === d.day)?.points ?? d.points }));
}

/**
 * Jumlah hari berturut-turut yang berlaku. `datesDesc` = tanggal klaim, terbaru dulu (tanpa duplikat).
 * Streak berlaku bila klaim terakhir hari ini atau kemarin; selain itu 0.
 */
export function computeStreak(today: string, datesDesc: string[]): number {
  if (datesDesc.length === 0) return 0;
  let expected = datesDesc[0] === today ? today : datesDesc[0] === addDays(today, -1) ? addDays(today, -1) : null;
  if (expected === null) return 0;
  let n = 0;
  for (const d of datesDesc) {
    if (d !== expected) break;
    n++;
    expected = addDays(expected, -1);
  }
  return n;
}

export interface LastCheckIn {
  date: string;
  day: number;
}

export interface CheckInState {
  today: string;
  claimedToday: boolean;
  streak: number;
  dayInCycle: number;
  nextPoints: number;
  rewards: { day: number; points: number; claimed: boolean }[];
}

/**
 * Keadaan check-in. Klaim terakhir kemarin -> lanjut ke hari berikutnya ((hari % 7) + 1); lebih lama atau belum pernah -> hari 1;
 * klaim terakhir hari ini -> claimedToday.
 */
export function checkInState(today: string, last: LastCheckIn | null, rewards: { day: number; points: number }[], datesDesc: string[] = []): CheckInState {
  const full = completeRewards(rewards);
  const yesterday = addDays(today, -1);
  const claimedToday = last?.date === today;
  const continuing = last?.date === yesterday;

  let dayInCycle: number;
  if (claimedToday) dayInCycle = last!.day;
  else if (continuing) dayInCycle = (last!.day % CYCLE_DAYS) + 1;
  else dayInCycle = 1;

  // Penanda "sudah diklaim": hari <= hari ini bila sudah klaim; hari < hari berikutnya bila streak berlanjut; kosong bila putus.
  const claimedUpTo = claimedToday ? dayInCycle : continuing ? dayInCycle - 1 : 0;
  return {
    today,
    claimedToday,
    streak: computeStreak(today, datesDesc.length ? datesDesc : last ? [last.date] : []),
    dayInCycle,
    nextPoints: full.find((r) => r.day === dayInCycle)!.points,
    rewards: full.map((r) => ({ day: r.day, points: r.points, claimed: r.day <= claimedUpTo })),
  };
}

/** Validasi hadiah dari admin: tepat 7 item, hari 1..7 unik, poin bilangan bulat 0..100. Mengembalikan pesan error atau null. */
export function validateRewards(rewards: { day: number; points: number }[]): string | null {
  if (rewards.length !== CYCLE_DAYS) return `Hadiah harus tepat ${CYCLE_DAYS} hari`;
  const days = new Set<number>();
  for (const r of rewards) {
    if (!Number.isInteger(r.day) || r.day < 1 || r.day > CYCLE_DAYS) return 'Hari harus 1 sampai 7';
    if (days.has(r.day)) return `Hari ${r.day} terisi dua kali`;
    days.add(r.day);
    if (!Number.isInteger(r.points) || r.points < 0 || r.points > 100) return `Poin hari ${r.day} harus bilangan bulat 0 sampai 100`;
  }
  return null;
}
