import { IsString, Length, Matches } from 'class-validator';

export class RequestOtpDto {
  @IsString()
  @Matches(/^[+\d\s-]{9,16}$/, { message: 'Nomor HP tidak valid' })
  phone: string;
}

export class VerifyOtpDto extends RequestOtpDto {
  @IsString()
  @Length(6, 6)
  code: string;
}
