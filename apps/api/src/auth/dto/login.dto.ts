import { IsString } from 'class-validator';

export class LoginDto {
  @IsString() identifier!: string; // email o phone
  @IsString() password!: string;
}
