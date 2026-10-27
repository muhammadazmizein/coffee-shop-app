import {
  BadRequestException,
  HttpException,
  ServiceUnavailableException,
  HttpStatus,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { normalizePhone } from '../common/phone.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { SmsService } from './sms.service.js';

const OTP_TTL_MS = 5 * 60_000;
const OTP_MAX_ATTEMPTS = 5;
const OTP_MAX_PER_WINDOW = 3;
const OTP_WINDOW_MS = 10 * 60_000;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly sms: SmsService,
  ) {}

  private hash(phone: string, code: string) {
    return createHmac('sha256', process.env.JWT_SECRET!).update(`${phone}:${code}`).digest('hex');
  }

  async requestOtp(rawPhone: string) {
    const phone = normalizePhone(rawPhone);
    if (!phone) throw new BadRequestException('Nomor HP tidak valid');

    const recent = await this.prisma.otp.count({
      where: { phone, createdAt: { gt: new Date(Date.now() - OTP_WINDOW_MS) } },
    });
    if (recent >= OTP_MAX_PER_WINDOW) {
      throw new HttpException('Terlalu banyak permintaan OTP, coba lagi nanti', HttpStatus.TOO_MANY_REQUESTS);
    }

    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    const otp = await this.prisma.otp.create({
      data: { phone, codeHash: this.hash(phone, code), expiresAt: new Date(Date.now() + OTP_TTL_MS) },
    });

    const appName = process.env.APP_NAME ?? 'Kopi App';
    try {
      await this.sms.send(phone, `${appName}: kode OTP Anda ${code}. Berlaku 5 menit. Jangan bagikan kode ini ke siapa pun.`);
    } catch (err) {
      // Kode yang tidak sampai ke pengguna tidak boleh tetap berlaku; kegagalan juga tidak menghabiskan jatah permintaan.
      await this.prisma.otp.delete({ where: { id: otp.id } });
      this.logger.error(`Gagal kirim SMS OTP ke ${phone}: ${err instanceof Error ? err.message : err}`);
      throw new ServiceUnavailableException('Gagal mengirim SMS, coba lagi sebentar lagi');
    }
    return this.sms.exposesCodeInResponse ? { sent: true, devCode: code } : { sent: true };
  }

  async verifyOtp(rawPhone: string, code: string) {
    const phone = normalizePhone(rawPhone);
    if (!phone) throw new BadRequestException('Nomor HP tidak valid');

    const otp = await this.prisma.otp.findFirst({
      where: { phone, usedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp || otp.attempts >= OTP_MAX_ATTEMPTS) {
      throw new UnauthorizedException('Kode OTP salah atau kedaluwarsa');
    }

    const expected = Buffer.from(otp.codeHash, 'hex');
    const actual = Buffer.from(this.hash(phone, code), 'hex');
    if (!timingSafeEqual(expected, actual)) {
      await this.prisma.otp.update({ where: { id: otp.id }, data: { attempts: { increment: 1 } } });
      throw new UnauthorizedException('Kode OTP salah atau kedaluwarsa');
    }

    // Tandai terpakai secara atomik agar OTP tidak bisa dipakai dua kali bersamaan.
    const claimed = await this.prisma.otp.updateMany({
      where: { id: otp.id, usedAt: null },
      data: { usedAt: new Date() },
    });
    if (claimed.count === 0) throw new UnauthorizedException('Kode OTP salah atau kedaluwarsa');

    const user = await this.prisma.user.upsert({
      where: { phone },
      update: {},
      create: { phone },
    });
    const token = await this.jwt.signAsync({ sub: user.id, role: user.role });
    return { token, user: { id: user.id, phone: user.phone, name: user.name, points: user.points } };
  }
}
