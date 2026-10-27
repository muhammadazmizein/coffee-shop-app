import { BadRequestException, ConflictException, Injectable } from '@nestjs/common';
import { createNotification } from '../notifications/notify.js';
import { checkInNotification } from '../notifications/notifications.logic.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { wibToday } from '../profile/profile.logic.js';
import { checkInState, completeRewards, validateRewards } from './checkin.logic.js';

/** Pelanggaran kunci unik (klaim ganda/serentak). Dikenali dari kode Prisma atau pesan driver. */
const isUniqueViolation = (err: unknown): boolean => {
  const e = err as { code?: string; message?: string; cause?: { message?: string } };
  return e?.code === 'P2002' || /Unique constraint|Duplicate entry/i.test(`${e?.message ?? ''} ${e?.cause?.message ?? ''}`);
};

/** Deadlock/konflik tulis MySQL (P2034): terjadi bila beberapa transaksi serentak memasukkan kunci unik yang sama. */
const isDeadlock = (err: unknown): boolean => {
  const e = err as { code?: string; message?: string };
  return e?.code === 'P2034' || /deadlock|write conflict/i.test(e?.message ?? '');
};

@Injectable()
export class CheckinService {
  constructor(private readonly prisma: PrismaService) {}

  /** Antrean per pengguna: klaim serentak dari satu pengguna diproses berurutan (yang kedua langsung 409). Antar-instance dijaga kunci unik database. */
  private readonly locks = new Map<string, Promise<unknown>>();

  private async withUserLock<T>(userId: string, fn: () => Promise<T>): Promise<T> {
    const prev = this.locks.get(userId) ?? Promise.resolve();
    const next = prev.catch(() => undefined).then(fn);
    this.locks.set(userId, next);
    try {
      return await next;
    } finally {
      if (this.locks.get(userId) === next) this.locks.delete(userId);
    }
  }

  async rewards() {
    return completeRewards(await this.prisma.checkInReward.findMany({ orderBy: { day: 'asc' } }));
  }

  async state(userId: string) {
    const [history, rewards] = await Promise.all([
      this.prisma.checkIn.findMany({ where: { userId }, orderBy: { date: 'desc' }, take: 400, select: { date: true, day: true } }),
      this.rewards(),
    ]);
    return checkInState(wibToday(), history[0] ?? null, rewards, history.map((h) => h.date));
  }

  /**
   * Klaim check-in hari ini. Atomik: baris CheckIn (unik per user+hari) dibuat lebih dulu, baru poin ditambah;
   * permintaan serentak yang kalah ditolak database sehingga poin hanya diberikan sekali.
   */
  claim(userId: string) {
    return this.withUserLock(userId, () => this.claimLocked(userId));
  }

  private async claimLocked(userId: string) {
    const today = wibToday();
    const rewards = await this.rewards();
    let result: { day: number; points: number } | undefined;
    for (let attempt = 0; !result; attempt++) {
      try {
        result = await this.prisma.$transaction(async (tx) => {
          const last = await tx.checkIn.findFirst({ where: { userId }, orderBy: { date: 'desc' }, select: { date: true, day: true } });
          const st = checkInState(today, last, rewards);
          if (st.claimedToday) throw new ConflictException('Sudah check-in hari ini');
          await tx.checkIn.create({ data: { userId, date: today, day: st.dayInCycle, points: st.nextPoints } });
          if (st.nextPoints > 0) {
            await tx.user.update({ where: { id: userId }, data: { points: { increment: st.nextPoints } } });
            await tx.pointLedger.create({ data: { userId, delta: st.nextPoints, reason: 'CHECKIN' } });
          }
          return { day: st.dayInCycle, points: st.nextPoints };
        });
      } catch (err) {
        if (err instanceof ConflictException) throw err;
        if (isUniqueViolation(err)) throw new ConflictException('Sudah check-in hari ini');
        if (isDeadlock(err) && attempt < 3) {
          // Kalah balapan: bila klaim hari ini sudah ada, berarti permintaan lain yang menang; bila belum, ulangi.
          if (await this.prisma.checkIn.findUnique({ where: { userId_date: { userId, date: today } }, select: { id: true } })) {
            throw new ConflictException('Sudah check-in hari ini');
          }
          continue;
        }
        throw err;
      }
    }
    await createNotification(this.prisma, userId, checkInNotification(result.day, result.points));
    return { ...(await this.state(userId)), awarded: result.points };
  }

  async replaceRewards(rewards: { day: number; points: number }[]) {
    const error = validateRewards(rewards);
    if (error) throw new BadRequestException(error);
    await this.prisma.$transaction(
      rewards.map((r) => this.prisma.checkInReward.upsert({ where: { day: r.day }, update: { points: r.points }, create: { day: r.day, points: r.points } })),
    );
    return this.rewards();
  }
}
