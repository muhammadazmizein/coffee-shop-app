import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/auth.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { isVoucherAvailable, voucherRemaining } from './vouchers.logic.js';

@Controller('vouchers')
@UseGuards(JwtAuthGuard)
export class VouchersController {
  constructor(private readonly prisma: PrismaService) {}

  /** Voucher yang bisa dipakai sekarang. Pembatasan akhir (minimum belanja, kuota atomik) tetap di server saat order. */
  @Get('active')
  async active() {
    const now = new Date();
    const rows = await this.prisma.voucher.findMany({
      where: { isActive: true, startsAt: { lte: now }, endsAt: { gte: now } },
      orderBy: { endsAt: 'asc' },
    });
    return rows
      .filter((v) => isVoucherAvailable(v, now))
      .map((v) => ({
        code: v.code,
        type: v.type,
        value: v.value,
        minSpend: v.minSpend,
        maxDiscount: v.maxDiscount,
        endsAt: v.endsAt,
        remaining: voucherRemaining(v.quota, v.used),
      }));
  }
}
