import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { BusinessesController } from './businesses.controller';
import { BusinessesService } from './businesses.service';

@Module({ controllers: [BusinessesController],
  imports: [AuthModule], providers: [BusinessesService], exports: [BusinessesService] })
export class BusinessesModule {}
