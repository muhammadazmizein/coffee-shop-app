import { Module } from '@nestjs/common';
import { ReportsController } from './admin/reports.controller.js';
import { AdminController } from './admin/admin.controller.js';
import { AddressesController } from './addresses/addresses.controller.js';
import { AuthModule } from './auth/auth.module.js';
import { CheckinModule } from './checkin/checkin.module.js';
import { MembershipModule } from './membership/membership.module.js';
import { MenuModule } from './menu/menu.module.js';
import { NotificationsController } from './notifications/notifications.controller.js';
import { OrdersModule } from './orders/orders.module.js';
import { PaymentsModule } from './payments/payments.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { ProfileController } from './profile/profile.controller.js';
import { AdminPromosController, PromosController } from './promos/promos.controller.js';
import { VouchersController } from './vouchers/vouchers.controller.js';

@Module({
  imports: [PrismaModule, AuthModule, CheckinModule, MembershipModule, MenuModule, OrdersModule, PaymentsModule],
  controllers: [ProfileController, NotificationsController, AddressesController, AdminController, ReportsController, VouchersController, PromosController, AdminPromosController],
})
export class AppModule {}
