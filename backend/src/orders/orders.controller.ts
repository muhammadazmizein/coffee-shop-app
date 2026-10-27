import { Body, Controller, Get, HttpCode, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { CurrentUser, JwtAuthGuard, Roles, RolesGuard } from '../common/auth.js';
import type { AuthUser } from '../common/auth.js';
import type { OrderStatus } from '../generated/prisma/client.js';
import { PayDto } from '../payments/payments.dto.js';
import { CreateOrderDto, UpdateStatusDto } from './orders.dto.js';
import { OrdersService } from './orders.service.js';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Post('orders/quote')
  @HttpCode(200)
  quote(@CurrentUser() user: AuthUser, @Body() dto: CreateOrderDto) {
    return this.orders.quote(user.id, dto);
  }

  @Post('orders')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateOrderDto) {
    return this.orders.create(user.id, dto);
  }

  /** Pilih metode dan buat charge. Metode sama yang masih berlaku dikembalikan apa adanya (idempoten). */
  @Post('orders/:id/pay')
  @HttpCode(200)
  pay(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: PayDto) {
    return this.orders.pay(user.id, id, dto.method, dto.phone);
  }

  @Get('orders')
  listMine(@CurrentUser() user: AuthUser) {
    return this.orders.listMine(user.id);
  }

  @Get('orders/:id')
  getMine(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.orders.getMine(user.id, id);
  }

  @Get('staff/orders')
  @Roles('STAFF', 'ADMIN')
  listForStaff(@CurrentUser() user: AuthUser, @Query('status') status?: OrderStatus) {
    return this.orders.listForStaff(user, status);
  }

  @Patch('staff/orders/:id/status')
  @Roles('STAFF', 'ADMIN')
  updateStatus(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: UpdateStatusDto) {
    return this.orders.updateStatus(user, id, dto.status, dto.courierId);
  }
}
