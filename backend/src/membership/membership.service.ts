import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { membershipProgress, sortTiers, tierFor, validateTierSet, type TierInput, type TierRule } from './membership.logic.js';

@Injectable()
export class MembershipService {
  constructor(private readonly prisma: PrismaService) {}

  /** Semua level, urut minSpend naik. */
  async tiers(): Promise<TierRule[]> {
    return sortTiers(await this.prisma.tier.findMany());
  }

  /** Level saat ini milik user (dipakai saat menghitung pesanan). */
  async tierForUser(userId: string): Promise<{ tier: TierRule; lifetimeSpend: number }> {
    const [user, tiers] = await Promise.all([this.prisma.user.findUniqueOrThrow({ where: { id: userId }, select: { lifetimeSpend: true } }), this.tiers()]);
    return { tier: tierFor(tiers, user.lifetimeSpend), lifetimeSpend: user.lifetimeSpend };
  }

  async membership(userId: string) {
    const [user, tiers] = await Promise.all([this.prisma.user.findUniqueOrThrow({ where: { id: userId }, select: { lifetimeSpend: true } }), this.tiers()]);
    const p = membershipProgress(tiers, user.lifetimeSpend);
    return { lifetimeSpend: user.lifetimeSpend, current: p.current, next: p.next, remainingToNext: p.remainingToNext, progressPct: p.progressPct, tiers };
  }

  /** Mengganti seluruh daftar level secara transaksional: upsert menurut nama (id stabil), hapus yang tidak ada lagi. */
  async replaceTiers(inputs: TierInput[]): Promise<TierRule[]> {
    const clean = inputs.map((t) => ({ ...t, name: t.name.trim(), maxDiscount: t.maxDiscount ?? null }));
    const error = validateTierSet(clean);
    if (error) throw new BadRequestException(error);

    await this.prisma.$transaction(async (tx) => {
      const existing = await tx.tier.findMany();
      const keep = new Set(clean.map((t) => t.name.toLowerCase())); // collation MySQL tidak membedakan huruf besar/kecil
      const stale = existing.filter((e) => !keep.has(e.name.toLowerCase())).map((e) => e.id);
      if (stale.length) await tx.tier.deleteMany({ where: { id: { in: stale } } });
      for (const [i, t] of clean.entries()) {
        const data = { name: t.name, minSpend: t.minSpend, earnMultiplierPct: t.earnMultiplierPct, discountPct: t.discountPct, maxDiscount: t.maxDiscount, sort: i };
        const found = existing.find((e) => e.name.toLowerCase() === t.name.toLowerCase());
        if (found) await tx.tier.update({ where: { id: found.id }, data });
        else await tx.tier.create({ data });
      }
    });
    return this.tiers();
  }
}
