import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Header,
  HttpCode,
  NotFoundException,
  Param,
  Patch,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard, Roles, RolesGuard } from '../common/auth.js';
import { MAX_IMAGE_BYTES, removeStoredImage, saveUploadedImage } from '../common/image.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { isVoucherAvailable } from '../vouchers/vouchers.logic.js';
import { CreatePromoDto, MovePromoDto, UpdatePromoDto } from './promos.dto.js';
import { moveInOrder, selectWelcomePromos } from './promos.logic.js';

/** Publik: slide promo untuk layar welcome app. */
@Controller('promos')
export class PromosController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('welcome')
  @Header('Cache-Control', 'public, max-age=60')
  async welcome() {
    const now = new Date();
    const promos = await this.prisma.promo.findMany({
      where: { isActive: true },
      orderBy: [{ sort: 'asc' }, { createdAt: 'asc' }],
      take: 100,
    });
    const codes = [...new Set(promos.map((p) => p.voucherCode).filter((c): c is string => !!c))];
    const vouchers = codes.length ? await this.prisma.voucher.findMany({ where: { code: { in: codes } } }) : [];
    const available = new Set(vouchers.filter((v) => isVoucherAvailable(v, now)).map((v) => v.code));
    return selectWelcomePromos(promos, available, now).map((p) => ({
      id: p.id,
      title: p.title,
      body: p.body,
      imageUrl: p.imageUrl,
      art: p.art,
      ctaLabel: p.ctaLabel,
      voucherCode: p.voucherCode,
    }));
  }
}

@Controller('admin/promos')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminPromosController {
  constructor(private readonly prisma: PrismaService) {}

  private list() {
    return this.prisma.promo.findMany({ orderBy: [{ sort: 'asc' }, { createdAt: 'asc' }] });
  }

  private assertPeriod(startsAt?: Date | null, endsAt?: Date | null) {
    if (startsAt && endsAt && endsAt <= startsAt) throw new BadRequestException('Tanggal berakhir harus setelah tanggal mulai');
  }

  private async find(id: string) {
    const promo = await this.prisma.promo.findUnique({ where: { id } });
    if (!promo) throw new NotFoundException('Promo tidak ditemukan');
    return promo;
  }

  @Get()
  all() {
    return this.list();
  }

  @Post()
  async create(@Body() dto: CreatePromoDto) {
    this.assertPeriod(dto.startsAt, dto.endsAt);
    const sort = dto.sort ?? ((await this.prisma.promo.aggregate({ _max: { sort: true } }))._max.sort ?? 0) + 10;
    return this.prisma.promo.create({ data: { ...dto, sort } });
  }

  @Patch(':id')
  async update(@Param('id') id: string, @Body() dto: UpdatePromoDto) {
    const current = await this.find(id);
    this.assertPeriod(dto.startsAt !== undefined ? dto.startsAt : current.startsAt, dto.endsAt !== undefined ? dto.endsAt : current.endsAt);
    return this.prisma.promo.update({ where: { id }, data: dto });
  }

  /** Geser urutan satu langkah; nomor urut dirapikan dalam satu transaksi. */
  @Post(':id/move')
  @HttpCode(200)
  async move(@Param('id') id: string, @Body() dto: MovePromoDto) {
    await this.find(id);
    const order = moveInOrder((await this.list()).map((p) => p.id), id, dto.direction);
    if (order) await this.prisma.$transaction(order.map((o) => this.prisma.promo.update({ where: { id: o.id }, data: { sort: o.sort } })));
    return this.list();
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(@Param('id') id: string) {
    const promo = await this.find(id);
    await this.prisma.promo.delete({ where: { id } });
    await removeStoredImage(promo.imageUrl);
  }

  @Post(':id/image')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_IMAGE_BYTES, files: 1 } }))
  async uploadImage(@Param('id') id: string, @UploadedFile() file?: Express.Multer.File) {
    const promo = await this.find(id);
    const imageUrl = await saveUploadedImage(file);
    try {
      await this.prisma.promo.update({ where: { id }, data: { imageUrl } });
    } catch (err) {
      await removeStoredImage(imageUrl);
      throw err;
    }
    await removeStoredImage(promo.imageUrl);
    return { imageUrl };
  }

  @Delete(':id/image')
  @HttpCode(204)
  async deleteImage(@Param('id') id: string) {
    const promo = await this.find(id);
    await this.prisma.promo.update({ where: { id }, data: { imageUrl: null } });
    await removeStoredImage(promo.imageUrl);
  }
}
