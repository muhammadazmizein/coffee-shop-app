import { Module } from '@nestjs/common';
import { MidtransService } from './midtrans.service.js';
import { PaymentSweeper } from './payment-sweeper.js';
import { PaymentsController } from './payments.controller.js';
import { PaymentsService } from './payments.service.js';

@Module({
  controllers: [PaymentsController],
  providers: [MidtransService, PaymentsService, PaymentSweeper],
  exports: [MidtransService, PaymentsService],
})
export class PaymentsModule {}
