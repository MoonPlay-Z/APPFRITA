import { IsArray, IsNumber, IsOptional, IsString, ValidateNested, Min, IsInt } from 'class-validator';
import { Type } from 'class-transformer';

class ItemDto {
  @IsString() product_id!: string;
  @IsInt() @Min(1) quantity!: number;
  @IsOptional() options?: any;
  @IsString() @IsOptional() note?: string;
}

export class CreateOrderDto {
  @IsString() business_id!: string;
  @IsString() location_id!: string;
  @IsString() type!: string;          // delivery | pickup | dine_in
  @IsString() @IsOptional() delivery_address?: string;
  @IsString() @IsOptional() customer_note?: string;
  @IsArray() @ValidateNested({ each: true }) @Type(() => ItemDto) items!: ItemDto[];
}
