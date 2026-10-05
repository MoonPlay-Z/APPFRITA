import { IsIn, IsOptional, IsString } from 'class-validator';
export class UpdateOrderStatusDto {
  @IsOptional() @IsString() @IsIn(['pending','confirmed','preparing','ready','sent','delivered','cancelled']) status?: string;
  @IsOptional() @IsString() @IsIn(['unpaid','proof_uploaded','paid','rejected','refunded']) payment_status?: string;
  @IsString() @IsOptional() note?: string;
}
