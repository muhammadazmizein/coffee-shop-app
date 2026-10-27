import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsDate, IsIn, IsInt, IsOptional, IsString, Matches, MaxLength, Max, Min, MinLength } from 'class-validator';
import { PROMO_ART_KEYS } from './promos.logic.js';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
/** Teks opsional: string kosong dianggap "kosongkan" (null). */
const emptyToNull = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() || null : value);
const upperOrNull = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim().toUpperCase() || null : value);

export class CreatePromoDto {
  @Transform(trim) @IsString() @MinLength(1) @MaxLength(60) title: string;
  @Transform(trim) @IsString() @MinLength(1) @MaxLength(160) body: string;
  /** null = tanpa ilustrasi bawaan. */
  @IsOptional() @IsIn(PROMO_ART_KEYS as unknown as string[], { message: 'Ilustrasi tidak dikenal' }) art?: string | null;
  @IsOptional() @Transform(emptyToNull) @IsString() @MaxLength(30) ctaLabel?: string | null;
  @IsOptional() @Transform(upperOrNull) @Matches(/^[A-Z0-9]{3,20}$/, { message: 'Kode voucher 3-20 karakter huruf besar/angka' }) voucherCode?: string | null;
  @IsOptional() @IsInt() @Min(-1000) @Max(100000) sort?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @Type(() => Date) @IsDate() startsAt?: Date | null;
  @IsOptional() @Type(() => Date) @IsDate() endsAt?: Date | null;
}

export class UpdatePromoDto {
  @IsOptional() @Transform(trim) @IsString() @MinLength(1) @MaxLength(60) title?: string;
  @IsOptional() @Transform(trim) @IsString() @MinLength(1) @MaxLength(160) body?: string;
  @IsOptional() @IsIn(PROMO_ART_KEYS as unknown as string[], { message: 'Ilustrasi tidak dikenal' }) art?: string | null;
  @IsOptional() @Transform(emptyToNull) @IsString() @MaxLength(30) ctaLabel?: string | null;
  @IsOptional() @Transform(upperOrNull) @Matches(/^[A-Z0-9]{3,20}$/, { message: 'Kode voucher 3-20 karakter huruf besar/angka' }) voucherCode?: string | null;
  @IsOptional() @IsInt() @Min(-1000) @Max(100000) sort?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @Type(() => Date) @IsDate() startsAt?: Date | null;
  @IsOptional() @Type(() => Date) @IsDate() endsAt?: Date | null;
}

export class MovePromoDto {
  @IsIn(['up', 'down']) direction: 'up' | 'down';
}
