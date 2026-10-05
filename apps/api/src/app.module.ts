import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { HealthController } from './health.controller';
import { BusinessesModule } from './businesses/businesses.module';
import { LocationsModule } from './locations/locations.module';

@Module({
  controllers: [HealthController],
  imports: [ConfigModule.forRoot({ isGlobal: true, envFilePath: ['.env', '../../.env'] }), PrismaModule, AuthModule, BusinessesModule, LocationsModule],
})
export class AppModule {}
