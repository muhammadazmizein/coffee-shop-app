import { describe, expect, it } from 'vitest';
import { addDays, checkInState, completeRewards, computeStreak, DEFAULT_REWARDS, validateRewards } from './checkin.logic.js';

const R = DEFAULT_REWARDS;
const T = '2026-10-26';
const claimedFlags = (s: ReturnType<typeof checkInState>) => s.rewards.map((r) => r.claimed);

describe('checkInState', () => {
  it('belum pernah check-in: hari 1, belum klaim, tidak ada penanda', () => {
    const s = checkInState(T, null, R);
    expect(s).toMatchObject({ claimedToday: false, streak: 0, dayInCycle: 1, nextPoints: 1 });
    expect(claimedFlags(s).every((c) => !c)).toBe(true);
  });

  it('klaim terakhir kemarin hari ke-2: sekarang hari ke-3 (2 poin), hari 1-2 sudah ditandai', () => {
    const s = checkInState(T, { date: '2026-10-25', day: 2 }, R, ['2026-10-25', '2026-10-24']);
    expect(s).toMatchObject({ claimedToday: false, dayInCycle: 3, nextPoints: 2, streak: 2 });
    expect(claimedFlags(s)).toEqual([true, true, false, false, false, false, false]);
  });

  it('sudah klaim hari ini: claimedToday, hari yang diklaim ikut ditandai', () => {
    const s = checkInState(T, { date: T, day: 3 }, R, [T, '2026-10-25', '2026-10-24']);
    expect(s).toMatchObject({ claimedToday: true, dayInCycle: 3, nextPoints: 2, streak: 3 });
    expect(claimedFlags(s)).toEqual([true, true, true, false, false, false, false]);
  });

  it('setelah hari ke-7 kembali ke hari 1 (penanda kosong, hadiah 1 poin)', () => {
    const s = checkInState(T, { date: '2026-10-25', day: 7 }, R, ['2026-10-25']);
    expect(s).toMatchObject({ claimedToday: false, dayInCycle: 1, nextPoints: 1 });
    expect(claimedFlags(s).every((c) => !c)).toBe(true);
  });

  it('hari ke-7 diklaim hari ini: semua ditandai, hadiah 5 poin', () => {
    const s = checkInState(T, { date: T, day: 7 }, R, [T]);
    expect(s).toMatchObject({ claimedToday: true, dayInCycle: 7, nextPoints: 5 });
    expect(claimedFlags(s).every((c) => c)).toBe(true);
  });

  it('streak putus (lewat kemarin): kembali hari 1, streak 0, penanda kosong', () => {
    const s = checkInState(T, { date: '2026-10-23', day: 5 }, R, ['2026-10-23']);
    expect(s).toMatchObject({ claimedToday: false, streak: 0, dayInCycle: 1 });
    expect(claimedFlags(s).every((c) => !c)).toBe(true);
  });

  it('batas tengah malam: tanggal berikutnya dihitung dari hari WIB yang diberikan', () => {
    // klaim 25 Okt; "hari ini" 26 Okt (setelah tengah malam WIB) = kemarin -> lanjut
    expect(checkInState('2026-10-26', { date: '2026-10-25', day: 1 }, R).dayInCycle).toBe(2);
    // masih 25 Okt (sebelum tengah malam) = sudah klaim hari ini
    expect(checkInState('2026-10-25', { date: '2026-10-25', day: 1 }, R).claimedToday).toBe(true);
  });

  it('memakai hadiah dari admin dan melengkapi yang hilang dengan bawaan', () => {
    const s = checkInState(T, null, [{ day: 1, points: 9 }]);
    expect(s.nextPoints).toBe(9);
    expect(s.rewards.find((r) => r.day === 7)!.points).toBe(5);
  });
});

describe('computeStreak', () => {
  it('menghitung hari berturut-turut dan berhenti di celah', () => {
    expect(computeStreak(T, [T, '2026-10-25', '2026-10-24', '2026-10-22'])).toBe(3);
  });
  it('berlaku bila klaim terakhir kemarin, 0 bila lebih lama', () => {
    expect(computeStreak(T, ['2026-10-25', '2026-10-24'])).toBe(2);
    expect(computeStreak(T, ['2026-10-24'])).toBe(0);
    expect(computeStreak(T, [])).toBe(0);
  });
  it('melewati batas bulan dan tahun', () => {
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
    expect(addDays('2026-01-01', -1)).toBe('2025-12-31');
    expect(computeStreak('2026-01-01', ['2026-01-01', '2025-12-31', '2025-12-30'])).toBe(3);
  });
});

describe('validateRewards', () => {
  const ok = R.map((r) => ({ ...r }));
  it('menerima 7 hadiah valid', () => expect(validateRewards(ok)).toBeNull());
  it('menolak jumlah salah, hari ganda/di luar rentang, poin tidak valid', () => {
    expect(validateRewards(ok.slice(0, 6))).toMatch(/tepat 7/);
    expect(validateRewards([...ok.slice(0, 6), { day: 6, points: 1 }])).toMatch(/dua kali/);
    expect(validateRewards([...ok.slice(0, 6), { day: 8, points: 1 }])).toMatch(/1 sampai 7/);
    expect(validateRewards([...ok.slice(0, 6), { day: 7, points: 101 }])).toMatch(/0 sampai 100/);
    expect(validateRewards([...ok.slice(0, 6), { day: 7, points: -1 }])).toMatch(/0 sampai 100/);
    expect(validateRewards([...ok.slice(0, 6), { day: 7, points: 1.5 }])).toMatch(/bilangan bulat/);
  });
  it('completeRewards selalu 7 baris', () => expect(completeRewards([]).length).toBe(7));
});
