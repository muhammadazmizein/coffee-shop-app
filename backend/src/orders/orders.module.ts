import { Module } from '@nestjs/common';
import { MembershipModule } from '../membership/membership.module.js';
import { PaymentsModule } from '../payments/payments.module.js';
import { OrdersController } from './orders.controller.js';
import { OrdersService } from './orders.service.js';

@Module({
  imports: [PaymentsModule, MembershipModule],
  controllers: [OrdersController],
  providers: [OrdersService],
})
export class OrdersModule {}
