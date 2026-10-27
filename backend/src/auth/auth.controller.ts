import { Body, Controller, HttpCode, HttpException, HttpStatus, Ip, Post } from '@nestjs/common';
import { RateLimiter } from '../common/rate-limit.js';
import { RequestOtpDto, VerifyOtpDto } from './auth.dto.js';
import { AuthService } from './auth.service.js';

// Batas per IP melindungi biaya SMS dari penyalahgunaan (nomor acak berulang); batas per nomor ada di AuthService.
const otpIpLimiter = new RateLimiter(10, 60 * 60_000);

@Controller()
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('auth/otp/request')
  @HttpCode(200)
  requestOtp(@Body() dto: RequestOtpDto, @Ip() ip: string) {
    if (!otpIpLimiter.allow(ip)) {
      throw new HttpException('Terlalu banyak permintaan OTP dari jaringan ini', HttpStatus.TOO_MANY_REQUESTS);
    }
    return this.auth.requestOtp(dto.phone);
  }

  @Post('auth/otp/verify')
  @HttpCode(200)
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.auth.verifyOtp(dto.phone, dto.code);
  }
}
