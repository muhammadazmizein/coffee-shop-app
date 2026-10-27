import { Body, Controller, Get, HttpException, HttpStatus, Logger, NotFoundException, Param, Post, UseGuards, HttpCode } from '@nestjs/common';
import { Transform } from 'class-transformer';
import { IsString, MaxLength, MinLength } from 'class-validator';
import { CurrentUser, JwtAuthGuard, Roles, RolesGuard } from '../common/auth.js';
import type { AuthUser } from '../common/auth.js';
import { RateLimiter } from '../common/rate-limit.js';
import { PrismaService } from '../prisma/prisma.service.js';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

class BroadcastDto {
  @Transform(trim)
  @IsString({ message: 'Judul harus berupa teks' })
  @MinLength(1, { message: 'Judul wajib diisi' })
  @MaxLength(80, { message: 'Judul maksimal 80 karakter' })
  title: string;

  @Transform(trim)
  @IsString({ message: 'Isi harus berupa teks' })
  @MinLength(1, { message: 'Isi pengumuman wajib diisi' })
  @MaxLength(500, { message: 'Isi maksimal 500 karakter' })
  body: string;
}

/** Maks 5 pengumuman per admin per 24 jam (dalam memori: reset saat backend restart; cukup untuk satu instance). */
export const BROADCASTS_PER_DAY = 5;
const broadcastLimiter = new RateLimiter(BROADCASTS_PER_DAY, 24 * 3600_000);
const CHUNK = 1000;

@Controller()
export class NotificationsController {
  private readonly logger = new Logger(NotificationsController.name);

  constructor(private readonly prisma: PrismaService) {}

  private unread(userId: string) {
    return this.prisma.notification.count({ where: { userId, readAt: null } });
  }

  @Get('me/notifications')
  @UseGuards(JwtAuthGuard)
  async list(@CurrentUser() user: AuthUser) {
    const [rows, unread] = await Promise.all([
      this.prisma.notification.findMany({ where: { userId: user.id }, orderBy: { createdAt: 'desc' }, take: 50 }),
      this.unread(user.id),
    ]);
    return {
      unread,
      items: rows.map((n) => ({ id: n.id, type: n.type, title: n.title, body: n.body, orderId: n.orderId, read: n.readAt !== null, createdAt: n.createdAt })),
    };
  }

  @Post('me/notifications/read-all')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard)
  async readAll(@CurrentUser() user: AuthUser) {
    await this.prisma.notification.updateMany({ where: { userId: user.id, readAt: null }, data: { readAt: new Date() } });
    return { unread: 0 };
  }

  @Post('me/notifications/:id/read')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard)
  async readOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    // Hanya milik sendiri: notifikasi orang lain diperlakukan seolah tidak ada.
    const n = await this.prisma.notification.findFirst({ where: { id, userId: user.id }, select: { id: true } });
    if (!n) throw new NotFoundException('Notifikasi tidak ditemukan');
    await this.prisma.notification.updateMany({ where: { id, userId: user.id, readAt: null }, data: { readAt: new Date() } });
    return { unread: await this.unread(user.id) };
  }

  /** Pengumuman ke semua pelanggan (role CUSTOMER), dikirim bertahap agar aman untuk ribuan pengguna. */
  @Post('admin/notifications/broadcast')
  @HttpCode(200)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('ADMIN')
  async broadcast(@CurrentUser() admin: AuthUser, @Body() dto: BroadcastDto) {
    if (!broadcastLimiter.allow(admin.id)) {
      throw new HttpException(`Maksimal ${BROADCASTS_PER_DAY} pengumuman per hari. Coba lagi besok.`, HttpStatus.TOO_MANY_REQUESTS);
    }
    let sent = 0;
    let cursor: string | undefined;
    for (;;) {
      const users = await this.prisma.user.findMany({
        where: { role: 'CUSTOMER' },
        select: { id: true },
        orderBy: { id: 'asc' },
        take: CHUNK,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      });
      if (users.length === 0) break;
      await this.prisma.notification.createMany({ data: users.map((u) => ({ userId: u.id, type: 'PROMO', title: dto.title, body: dto.body })) });
      sent += users.length;
      cursor = users[users.length - 1].id;
      if (users.length < CHUNK) break;
    }
    this.logger.log(`Pengumuman oleh admin ${admin.id} terkirim ke ${sent} pelanggan: "${dto.title}"`);
    return { sent };
  }
}
