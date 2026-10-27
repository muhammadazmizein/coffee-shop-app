import { Transform, Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsInt, IsOptional, IsString, Max, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class TierInputDto {
  @Transform(trim)
  @IsString({ message: 'Nama level harus berupa teks' })
  @MinLength(1, { message: 'Nama level tidak boleh kosong' })
  @MaxLength(20, { message: 'Nama level maksimal 20 karakter' })
  name: string;

  @IsInt({ message: 'Minimal belanja harus bilangan bulat' })
  @Min(0, { message: 'Minimal belanja tidak boleh negatif' })
  @Max(1_000_000_000, { message: 'Minimal belanja terlalu besar' })
  minSpend: number;

  @IsInt({ message: 'Pengali poin harus bilangan bulat (persen)' })
  @Min(100, { message: 'Pengali poin minimal 100% (1,0x)' })
  @Max(500, { message: 'Pengali poin maksimal 500% (5,0x)' })
  earnMultiplierPct: number;

  @IsInt({ message: 'Diskon harus bilangan bulat (persen)' })
  @Min(0, { message: 'Diskon tidak boleh negatif' })
  @Max(50, { message: 'Diskon maksimal 50%' })
  discountPct: number;

  /** null/kosong = tanpa batas. */
  @IsOptional()
  @IsInt({ message: 'Batas diskon harus bilangan bulat rupiah' })
  @Min(1, { message: 'Batas diskon minimal Rp1 (kosongkan bila tanpa batas)' })
  maxDiscount?: number | null;
}

export class ReplaceTiersDto {
  @IsArray({ message: 'Daftar level wajib diisi' })
  @ArrayMinSize(1, { message: 'Minimal 1 level' })
  @ArrayMaxSize(6, { message: 'Maksimal 6 level' })
  @ValidateNested({ each: true })
  @Type(() => TierInputDto)
  tiers: TierInputDto[];
}
