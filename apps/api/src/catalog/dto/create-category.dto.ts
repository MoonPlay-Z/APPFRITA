import { IsNumber, IsOptional, IsString } from 'class-validator';
export class CreateCategoryDto {
  @IsString() business_id!: string;
  @IsString() name!: string;
  @IsNumber() @IsOptional() sort_order?: number;
}
