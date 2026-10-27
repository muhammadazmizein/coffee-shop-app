import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  ForbiddenException,
  HttpCode,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Put,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Type } from 'class-transformer';
import {
  IsLatitude,
  IsLongitude,
  IsBoolean,
  IsDate,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  ValidateIf,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { CurrentUser, JwtAuthGuard, Roles, RolesGuard } from '../common/auth.js';
import type { AuthUser } from '../common/auth.js';
import { MAX_IMAGE_BYTES, removeStoredImage, saveUploadedImage } from '../common/image.js';
import { normalizeContactPhone, normalizePhone } from '../common/phone.js';
import { PrismaService } from '../prisma/prisma.service.js';

class CreateProductDto {
  @IsString() categoryId: string;
  @IsString() @MinLength(2) @MaxLength(100) name: string;
  @IsInt() @Min(0) price: number;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
}

class UpdateProductDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(100) name?: string;
  @IsOptional() @IsInt() @Min(0) price?: number;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

class CreateGroupDto {
  @IsString() @MinLength(1) @MaxLength(50) name: string;
  @IsBoolean() required: boolean;
  @IsInt() @Min(1) @Max(10) maxSelect: number;
}

class UpdateGroupDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(50) name?: string;
  @IsOptional() @IsBoolean() required?: boolean;
  @IsOptional() @IsInt() @Min(1) @Max(10) maxSelect?: number;
}

class CreateOptionDto {
  @IsString() @MinLength(1) @MaxLength(50) name: string;
  @IsInt() @Min(0) extraPrice: number;
}

class UpdateOptionDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(50) name?: string;
  @IsOptional() @IsInt() @Min(0) extraPrice?: number;
}

class UpdateOutletDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(100) name?: string;
  @IsOptional() @IsString() @MinLength(5) @MaxLength(300) address?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
  /** Koordinat outlet: titik asal perhitungan jarak pengantaran. */
  @IsOptional() @IsLatitude() lat?: number;
  @IsOptional() @IsLongitude() lng?: number;
  @IsOptional() @IsInt() @Min(0) @Max(23) openHour?: number;
  @IsOptional() @IsInt() @Min(1) @Max(24) closeHour?: number;
  /** Jarak maksimum pengantaran (km). 0 = delivery dimatikan. */
  @IsOptional() @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) @Max(50) deliveryRadiusKm?: number;
  @IsOptional() @IsInt() @Min(0) @Max(1_000_000) deliveryBaseFee?: number;
  @IsOptional() @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) @Max(50) deliveryBaseKm?: number;
  @IsOptional() @IsInt() @Min(0) @Max(1_000_000) deliveryPerKmFee?: number;
  /** Telepon outlet. Kosong ("") atau null = hapus; selain itu harus nomor yang valid. */
  @ValidateIf((_, v) => v !== undefined && v !== null && v !== '')
  @IsString()
  @Matches(/^[+\d\s()-]{9,20}$/, { message: 'Nomor telepon tidak valid' })
  phone?: string | null;
}

class CreateCourierDto {
  @IsString() outletId: string;
  @IsString() @MinLength(2) @MaxLength(60) name: string;
  @IsString() @Matches(/^[+\d\s-]{9,16}$/, { message: 'Nomor HP tidak valid' }) phone: string;
}

class UpdateCourierDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(60) name?: string;
  @IsOptional() @IsString() @Matches(/^[+\d\s-]{9,16}$/, { message: 'Nomor HP tidak valid' }) phone?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

class AvailabilityDto {
  @IsBoolean() isAvailable: boolean;
}

class CreateVoucherDto {
  @IsString() @Matches(/^[A-Z0-9]{3,20}$/, { message: 'Kode 3-20 karakter huruf besar/angka' }) code: string;
  @IsEnum(['PERCENT', 'FIXED']) type: 'PERCENT' | 'FIXED';
  @IsInt() @Min(1) value: number;
  @IsInt() @Min(0) minSpend: number;
  @IsOptional() @IsInt() @Min(1) maxDiscount?: number;
  @IsInt() @Min(0) quota: number; // 0 = tanpa batas
  @Type(() => Date) @IsDate() startsAt: Date;
  @Type(() => Date) @IsDate() endsAt: Date;
}

class UpdateVoucherDto {
  @IsBoolean() isActive: boolean;
}

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminController {
  constructor(private readonly prisma: PrismaService) {}

  /** Outlet yang boleh dikelola: admin semua, staff hanya outletnya. */
  private async scopedOutletId(user: AuthUser): Promise<string | undefined> {
    if (user.role === 'ADMIN') return undefined;
    const u = await this.prisma.user.findUniqueOrThrow({ where: { id: user.id } });
    if (!u.outletId) throw new ForbiddenException('Akun staff belum terhubung ke outlet');
    return u.outletId;
  }

  @Get('outlets')
  @Roles('STAFF', 'ADMIN')
  async outlets(@CurrentUser() user: AuthUser) {
    const id = await this.scopedOutletId(user);
    return this.prisma.outlet.findMany({ where: id ? { id } : {}, orderBy: { name: 'asc' } });
  }

  @Patch('outlets/:id')
  @Roles('ADMIN')
  async updateOutlet(@Param('id') id: string, @Body() dto: UpdateOutletDto) {
    const current = await this.prisma.outlet.findUnique({ where: { id } });
    if (!current) throw new NotFoundException('Outlet tidak ditemukan');
    const open = dto.openHour ?? current.openHour;
    const close = dto.closeHour ?? current.closeHour;
    if (open === close) throw new BadRequestException('Jam buka dan tutup tidak boleh sama');
    const { phone, ...rest } = dto;
    let phoneData: { phone: string | null } | undefined;
    if (phone !== undefined) {
      if (phone === null || phone.trim() === '') phoneData = { phone: null };
      else {
        const normalized = normalizeContactPhone(phone);
        if (!normalized) throw new BadRequestException('Nomor telepon tidak valid. Contoh: 0812 3456 7890 atau (021) 555 1234');
        phoneData = { phone: normalized };
      }
    }
    return this.prisma.outlet.update({ where: { id }, data: { ...rest, ...phoneData } });
  }

  /** Kurir milik kafe (bukan pihak ketiga). Staff hanya melihat kurir outletnya. */
  @Get('couriers')
  @Roles('STAFF', 'ADMIN')
  async couriers(@CurrentUser() user: AuthUser) {
    const outletId = await this.scopedOutletId(user);
    return this.prisma.courier.findMany({
      where: outletId ? { outletId } : {},
      orderBy: [{ outletId: 'asc' }, { name: 'asc' }],
    });
  }

  @Post('couriers')
  @Roles('ADMIN')
  async createCourier(@Body() dto: CreateCourierDto) {
    if (!(await this.prisma.outlet.findUnique({ where: { id: dto.outletId } }))) throw new NotFoundException('Outlet tidak ditemukan');
    return this.prisma.courier.create({ data: { ...dto, phone: normalizePhone(dto.phone) ?? dto.phone } });
  }

  @Patch('couriers/:id')
  @Roles('ADMIN')
  async updateCourier(@Param('id') id: string, @Body() dto: UpdateCourierDto) {
    const data = { ...dto, ...(dto.phone ? { phone: normalizePhone(dto.phone) ?? dto.phone } : {}) };
    const res = await this.prisma.courier.updateMany({ where: { id }, data });
    if (res.count === 0) throw new NotFoundException('Kurir tidak ditemukan');
    return this.prisma.courier.findUniqueOrThrow({ where: { id } });
  }

  @Get('categories')
  @Roles('ADMIN')
  categories() {
    return this.prisma.category.findMany({ orderBy: { sort: 'asc' } });
  }

  @Get('products')
  @Roles('STAFF', 'ADMIN')
  products() {
    return this.prisma.product.findMany({
      orderBy: [{ categoryId: 'asc' }, { name: 'asc' }],
      include: {
        category: { select: { name: true } },
        stock: true,
        optionGroups: { include: { options: { orderBy: { name: 'asc' } } }, orderBy: { name: 'asc' } },
      },
    });
  }

  @Post('products')
  @Roles('ADMIN')
  async createProduct(@Body() dto: CreateProductDto) {
    const category = await this.prisma.category.findUnique({ where: { id: dto.categoryId } });
    if (!category) throw new NotFoundException('Kategori tidak ditemukan');
    return this.prisma.product.create({ data: dto });
  }

  @Patch('products/:id')
  @Roles('ADMIN')
  async updateProduct(@Param('id') id: string, @Body() dto: UpdateProductDto) {
    const res = await this.prisma.product.updateMany({ where: { id }, data: dto });
    if (res.count === 0) throw new NotFoundException('Produk tidak ditemukan');
    return this.prisma.product.findUniqueOrThrow({ where: { id } });
  }

  @Post('products/:id/image')
  @Roles('ADMIN')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_IMAGE_BYTES, files: 1 } }))
  async uploadImage(@Param('id') id: string, @UploadedFile() file?: Express.Multer.File) {
    const product = await this.prisma.product.findUnique({ where: { id } });
    if (!product) throw new NotFoundException('Produk tidak ditemukan');
    const imageUrl = await saveUploadedImage(file);
    try {
      await this.prisma.product.update({ where: { id }, data: { imageUrl } });
    } catch (err) {
      await removeStoredImage(imageUrl);
      throw err;
    }
    await removeStoredImage(product.imageUrl);
    return { imageUrl };
  }

  @Delete('products/:id/image')
  @Roles('ADMIN')
  @HttpCode(204)
  async deleteImage(@Param('id') id: string) {
    const product = await this.prisma.product.findUnique({ where: { id } });
    if (!product) throw new NotFoundException('Produk tidak ditemukan');
    await this.prisma.product.update({ where: { id }, data: { imageUrl: null } });
    await removeStoredImage(product.imageUrl);
  }

  @Post('products/:id/option-groups')
  @Roles('ADMIN')
  async createGroup(@Param('id') id: string, @Body() dto: CreateGroupDto) {
    if (!(await this.prisma.product.findUnique({ where: { id } }))) throw new NotFoundException('Produk tidak ditemukan');
    return this.prisma.optionGroup.create({ data: { ...dto, productId: id }, include: { options: true } });
  }

  @Patch('option-groups/:id')
  @Roles('ADMIN')
  async updateGroup(@Param('id') id: string, @Body() dto: UpdateGroupDto) {
    const res = await this.prisma.optionGroup.updateMany({ where: { id }, data: dto });
    if (res.count === 0) throw new NotFoundException('Grup opsi tidak ditemukan');
    return this.prisma.optionGroup.findUniqueOrThrow({ where: { id }, include: { options: true } });
  }

  /** Riwayat pesanan aman: item pesanan menyimpan salinan nama dan harga opsi. */
  @Delete('option-groups/:id')
  @Roles('ADMIN')
  @HttpCode(204)
  async deleteGroup(@Param('id') id: string) {
    const res = await this.prisma.optionGroup.deleteMany({ where: { id } });
    if (res.count === 0) throw new NotFoundException('Grup opsi tidak ditemukan');
  }

  @Post('option-groups/:id/options')
  @Roles('ADMIN')
  async createOption(@Param('id') id: string, @Body() dto: CreateOptionDto) {
    if (!(await this.prisma.optionGroup.findUnique({ where: { id } }))) throw new NotFoundException('Grup opsi tidak ditemukan');
    return this.prisma.option.create({ data: { ...dto, groupId: id } });
  }

  @Patch('options/:id')
  @Roles('ADMIN')
  async updateOption(@Param('id') id: string, @Body() dto: UpdateOptionDto) {
    const res = await this.prisma.option.updateMany({ where: { id }, data: dto });
    if (res.count === 0) throw new NotFoundException('Opsi tidak ditemukan');
    return this.prisma.option.findUniqueOrThrow({ where: { id } });
  }

  @Delete('options/:id')
  @Roles('ADMIN')
  @HttpCode(204)
  async deleteOption(@Param('id') id: string) {
    const res = await this.prisma.option.deleteMany({ where: { id } });
    if (res.count === 0) throw new NotFoundException('Opsi tidak ditemukan');
  }

  /** Tandai produk habis/tersedia di satu outlet. Staff hanya untuk outletnya sendiri. */
  @Put('outlets/:outletId/products/:productId')
  @Roles('STAFF', 'ADMIN')
  async setAvailability(
    @CurrentUser() user: AuthUser,
    @Param('outletId') outletId: string,
    @Param('productId') productId: string,
    @Body() dto: AvailabilityDto,
  ) {
    const scope = await this.scopedOutletId(user);
    if (scope && scope !== outletId) throw new ForbiddenException();
    const [outlet, product] = await Promise.all([
      this.prisma.outlet.findUnique({ where: { id: outletId } }),
      this.prisma.product.findUnique({ where: { id: productId } }),
    ]);
    if (!outlet || !product) throw new NotFoundException();
    return this.prisma.outletProduct.upsert({
      where: { outletId_productId: { outletId, productId } },
      update: { isAvailable: dto.isAvailable },
      create: { outletId, productId, isAvailable: dto.isAvailable },
    });
  }

  @Get('vouchers')
  @Roles('ADMIN')
  vouchers() {
    return this.prisma.voucher.findMany({ orderBy: { endsAt: 'desc' } });
  }

  @Post('vouchers')
  @Roles('ADMIN')
  createVoucher(@Body() dto: CreateVoucherDto) {
    if (dto.endsAt <= dto.startsAt) throw new BadRequestException('Tanggal berakhir harus setelah tanggal mulai');
    if (dto.type === 'PERCENT' && dto.value > 100) throw new BadRequestException('Persen maksimal 100');
    return this.prisma.voucher.create({ data: { ...dto, maxDiscount: dto.maxDiscount ?? null } });
  }

  @Patch('vouchers/:id')
  @Roles('ADMIN')
  async updateVoucher(@Param('id') id: string, @Body() dto: UpdateVoucherDto) {
    const res = await this.prisma.voucher.updateMany({ where: { id }, data: { isActive: dto.isActive } });
    if (res.count === 0) throw new NotFoundException('Voucher tidak ditemukan');
    return this.prisma.voucher.findUniqueOrThrow({ where: { id } });
  }
}
