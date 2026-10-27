import { Body, Controller, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/auth.js';
import type { MidtransNotification } from './midtrans.service.js';
import { PaymentsService } from './payments.service.js';

@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  /** Metode pembayaran yang aktif, urut tampilan. */
  @Get('methods')
  @UseGuards(JwtAuthGuard)
  methods() {
    return this.payments.methods();
  }

  /** Webhook Midtrans. Keaslian dijamin signature_key, bukan auth user. */
  @Post('midtrans/notify')
  @HttpCode(200)
  notify(@Body() body: MidtransNotification) {
    return this.payments.handleNotification(body);
  }
}
