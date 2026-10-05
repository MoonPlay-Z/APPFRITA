import { Body, Controller, Get, Inject, Param, Post, Req, UseGuards } from '@nestjs/common';
import { BusinessesService } from './businesses.service';
import { CreateBusinessDto } from './dto/create-business.dto';
import { JwtAuthGuard } from '../common/jwt-auth.guard';

@Controller('businesses')
export class BusinessesController {
  constructor(@Inject(BusinessesService) private svc: BusinessesService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  create(@Req() req: any, @Body() dto: CreateBusinessDto) { return this.svc.create(req.user.sub, dto); }

  @Get('mine')
  @UseGuards(JwtAuthGuard)
  mine(@Req() req: any) { return this.svc.mine(req.user.sub); }

  @Get(':id')
  findOne(@Param('id') id: string) { return this.svc.findOne(id); }
}
