import { Body, Controller, Delete, Get, HttpCode, NotFoundException, Param, Post, UseGuards } from '@nestjs/common';
import { IsLatitude, IsLongitude, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { CurrentUser, JwtAuthGuard } from '../common/auth.js';
import type { AuthUser } from '../common/auth.js';
import { normalizePhone } from '../common/phone.js';
import { PrismaService } from '../prisma/prisma.service.js';

class CreateAddressDto {
  @IsString() @MaxLength(30) label: string;
  @IsString() @MinLength(2) @MaxLength(60) recipient: string;
  @IsString() @Matches(/^[+\d\s-]{9,16}$/) phone: string;
  @IsString() @MinLength(5) @MaxLength(300) detail: string;
  @IsLatitude() lat: number;
  @IsLongitude() lng: number;
}

@Controller('addresses')
@UseGuards(JwtAuthGuard)
export class AddressesController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.prisma.address.findMany({ where: { userId: user.id }, orderBy: { id: 'desc' } });
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateAddressDto) {
    return this.prisma.address.create({
      data: { ...dto, phone: normalizePhone(dto.phone) ?? dto.phone, userId: user.id },
    });
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const res = await this.prisma.address.deleteMany({ where: { id, userId: user.id, orders: { none: {} } } });
    if (res.count === 0) throw new NotFoundException('Alamat tidak ditemukan atau sudah dipakai pesanan');
  }
}
