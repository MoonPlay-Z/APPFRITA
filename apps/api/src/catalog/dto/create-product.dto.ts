import { IsBoolean, IsNumber, IsOptional, IsString, Min } from 'class-validator';
export class CreateProductDto {
  @IsString() business_id!: string;
  @IsString() @IsOptional() category_id?: string;
  @IsString() name!: string;
  @IsString() @IsOptional() description?: string;
  @IsNumber() @Min(0) price!: number;
  @IsNumber() @IsOptional() sort_order?: number;
  @IsBoolean() @IsOptional() is_available?: boolean;
}
