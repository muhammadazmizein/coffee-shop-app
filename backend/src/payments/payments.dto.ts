import { IsIn, IsOptional, IsString, Matches } from 'class-validator';
import { METHOD_KEYS, type PayMethod } from './payments.logic.js';

export class PayDto {
  @IsIn(METHOD_KEYS)
  method: PayMethod;

  /** Nomor akun OVO (hanya dipakai metode ovo); kosong = nomor akun login. */
  @IsOptional()
  @IsString()
  @Matches(/^[+\d\s-]{9,16}$/, { message: 'Nomor OVO tidak valid' })
  phone?: string;
}
