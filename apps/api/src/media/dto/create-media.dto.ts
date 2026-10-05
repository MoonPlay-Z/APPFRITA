import { IsInt, IsOptional, IsString, Min } from 'class-validator';
export class CreateMediaDto {
  @IsString() storage_key!: string;
  @IsString() url!: string;
  @IsString() @IsOptional() thumb_url?: string;
  @IsString() mime_type!: string;
  @IsInt() @Min(1) size_bytes!: number;
  @IsInt() @IsOptional() width?: number;
  @IsInt() @IsOptional() height?: number;
  @IsString() @IsOptional() business_id?: string;
}
