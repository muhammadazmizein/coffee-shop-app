import { BadRequestException, Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { Transform } from 'class-transformer';
import { IsEmail, IsIn, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { CurrentUser, JwtAuthGuard } from '../common/auth.js';
import type { AuthUser } from '../common/auth.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { formatBirthDate, GENDERS, profileCompletion, validateBirthDate } from './profile.logic.js';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
const trimLower = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim().toLowerCase() : value);

export class UpdateProfileDto {
  @IsOptional()
  @Transform(trim)
  @IsString({ message: 'Nama harus berupa teks' })
  @MinLength(2, { message: 'Nama minimal 2 karakter' })
  @MaxLength(60, { message: 'Nama maksimal 60 karakter' })
  name?: string;

  @IsOptional()
  @Transform(trimLower)
  @IsEmail({}, { message: 'Format email tidak valid' })
  @MaxLength(100, { message: 'Email maksimal 100 karakter' })
  email?: string;

  @IsOptional()
  @IsString({ message: 'Tanggal lahir harus berupa teks YYYY-MM-DD' })
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'Format tanggal lahir harus YYYY-MM-DD' })
  birthDate?: string;

  @IsOptional()
  @IsIn(GENDERS, { message: 'Jenis kelamin harus MALE atau FEMALE' })
  gender?: string;
}

@Controller()
export class ProfileController {
  constructor(private readonly prisma: PrismaService) {}

  /** Profil lengkap + jumlah notifikasi belum dibaca + kelengkapan profil. */
  private async profile(userId: string) {
    const [u, addressCount, unread] = await Promise.all([
      this.prisma.user.findUniqueOrThrow({
        where: { id: userId },
        select: { id: true, phone: true, name: true, points: true, role: true, email: true, birthDate: true, gender: true, createdAt: true },
      }),
      this.prisma.address.count({ where: { userId } }),
      this.prisma.notification.count({ where: { userId, readAt: null } }),
    ]);
    return {
      id: u.id,
      phone: u.phone,
      name: u.name,
      points: u.points,
      role: u.role,
      email: u.email,
      birthDate: formatBirthDate(u.birthDate),
      gender: u.gender,
      createdAt: u.createdAt,
      unreadNotifications: unread,
      profileCompletion: profileCompletion(u, addressCount),
    };
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@CurrentUser() user: AuthUser) {
    return this.profile(user.id);
  }

  @Patch('me')
  @UseGuards(JwtAuthGuard)
  async updateMe(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    if (dto.name === undefined && dto.email === undefined && dto.birthDate === undefined && dto.gender === undefined) {
      throw new BadRequestException('Tidak ada data yang diubah');
    }
    let birthDate: Date | undefined;
    if (dto.birthDate !== undefined) {
      const r = validateBirthDate(dto.birthDate);
      if (!r.ok) throw new BadRequestException(r.error);
      birthDate = r.date;
    }
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        ...(dto.name !== undefined ? { name: dto.name } : {}),
        ...(dto.email !== undefined ? { email: dto.email } : {}),
        ...(birthDate ? { birthDate } : {}),
        ...(dto.gender !== undefined ? { gender: dto.gender } : {}),
      },
    });
    return this.profile(user.id);
  }

  /** Riwayat poin (50 terbaru): belanja, penukaran, pengembalian, check-in. */
  @Get('me/points')
  @UseGuards(JwtAuthGuard)
  points(@CurrentUser() user: AuthUser) {
    return this.prisma.pointLedger.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: { id: true, delta: true, reason: true, createdAt: true },
    });
  }
}
