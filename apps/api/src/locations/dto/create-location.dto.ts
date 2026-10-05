import { IsBoolean, IsNumber, IsOptional, IsString } from 'class-validator';

export class CreateLocationDto {
  @IsString() business_id!: string;
  @IsString() name!: string;
  @IsString() address!: string;
  @IsNumber() lng!: number;
  @IsNumber() lat!: number;
  @IsBoolean() @IsOptional() is_mobile_stall?: boolean;
  @IsBoolean() @IsOptional() accepts_delivery?: boolean;
  @IsBoolean() @IsOptional() accepts_pickup?: boolean;
  @IsBoolean() @IsOptional() accepts_reservations?: boolean;
  @IsNumber() @IsOptional() delivery_radius_m?: number;
  @IsNumber() @IsOptional() delivery_fee?: number;
  @IsNumber() @IsOptional() min_order?: number;
}
