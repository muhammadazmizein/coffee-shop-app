import { Controller, Get, Query } from '@nestjs/common';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { PrismaService } from '../prisma/prisma.service.js';
import { POPULAR_DAYS, POPULAR_LIMIT, rankPopular } from './popular.js';

class PopularQuery {
  @IsOptional() @IsString() @MaxLength(40) outletId?: string;
}

/** Pesanan berstatus ini dihitung sebagai penjualan. */
const SALES_STATUSES = ['PAID', 'PREPARING', 'READY', 'ON_DELIVERY', 'COMPLETED'] as const;

@Controller()
export class MenuController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('outlets')
  outlets() {
    return this.prisma.outlet.findMany({ where: { isActive: true }, orderBy: { name: 'asc' } });
  }

  /** Menu per outlet: produk yang dimatikan di outlet tersebut tidak ditampilkan. */
  @Get('menu')
  async menu(@Query('outletId') outletId?: string) {
    const categories = await this.prisma.category.findMany({
      orderBy: { sort: 'asc' },
      include: {
        products: {
          where: {
            isActive: true,
            ...(outletId ? { stock: { none: { outletId, isAvailable: false } } } : {}),
          },
          include: { optionGroups: { include: { options: true } } },
        },
      },
    });
    return categories.filter((c) => c.products.length > 0);
  }

  /** ID produk terlaris 30 hari terakhir (maks 8), hanya yang aktif dan tersedia di outlet. */
  @Get('menu/popular')
  async popular(@Query() q: PopularQuery): Promise<string[]> {
    const since = new Date(Date.now() - POPULAR_DAYS * 86_400_000);
    const sums = await this.prisma.orderItem.groupBy({
      by: ['productId'],
      where: {
        order: {
          status: { in: [...SALES_STATUSES] },
          createdAt: { gte: since },
          ...(q.outletId ? { outletId: q.outletId } : {}),
        },
      },
      _sum: { qty: true },
      orderBy: { _sum: { qty: 'desc' } },
      take: 60, // cadangan: sebagian bisa tersaring (nonaktif/habis)
    });
    if (sums.length === 0) return [];
    const visible = await this.prisma.product.findMany({
      where: {
        id: { in: sums.map((s) => s.productId) },
        isActive: true,
        ...(q.outletId ? { stock: { none: { outletId: q.outletId, isAvailable: false } } } : {}),
      },
      select: { id: true },
    });
    return rankPopular(
      sums.map((s) => ({ productId: s.productId, qty: s._sum.qty ?? 0 })),
      new Set(visible.map((p) => p.id)),
      POPULAR_LIMIT,
    );
  }
}
