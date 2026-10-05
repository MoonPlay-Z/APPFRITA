import { IsString, IsOptional, IsIn } from 'class-validator';

export class CreateBusinessDto {
  @IsString() name!: string;
  @IsString() slug!: string;
  @IsString() @IsOptional() description?: string;
  @IsString() @IsOptional() category?: string;
  @IsString() @IsOptional() phone?: string;
  @IsString() @IsOptional() whatsapp_number?: string;
  @IsString() @IsOptional() @IsIn(['USD']) currency?: string;
}
