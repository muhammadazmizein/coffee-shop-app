import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class OrderItemDto {
  @IsString()
  productId: string;

  @IsInt()
  @Min(1)
  @Max(20)
  qty: number;

  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  optionIds: string[];

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}

export class CreateOrderDto {
  @IsString()
  outletId: string;

  @IsEnum(['PICKUP', 'DELIVERY'])
  type: 'PICKUP' | 'DELIVERY';

  @IsOptional()
  @IsString()
  addressId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  voucherCode?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;

  /** Jumlah poin yang ingin ditukar; server membatasi sesuai saldo dan aturan maksimum. */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  usePoints?: number;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(30)
  @ValidateNested({ each: true })
  @Type(() => OrderItemDto)
  items: OrderItemDto[];
}

export class UpdateStatusDto {
  @IsEnum(['PREPARING', 'READY', 'ON_DELIVERY', 'COMPLETED', 'CANCELLED'])
  status: 'PREPARING' | 'READY' | 'ON_DELIVERY' | 'COMPLETED' | 'CANCELLED';

  /** Wajib saat mengirim pesanan delivery (status ON_DELIVERY). */
  @IsOptional()
  @IsString()
  courierId?: string;
}
