import { Body, Controller, Get, Inject, Param, Post, Req, UseGuards } from '@nestjs/common';
import { MediaService } from './media.service';
import { CreateMediaDto } from './dto/create-media.dto';
import { JwtAuthGuard } from '../common/jwt-auth.guard';

@Controller('media')
export class MediaController {
  constructor(@Inject(MediaService) private svc: MediaService) {}
  @Post() @UseGuards(JwtAuthGuard) create(@Req() req: any, @Body() dto: CreateMediaDto) { return this.svc.create(req.user.sub, dto); }
  @Get(':id') get(@Param('id') id: string) { return this.svc.get(id); }
}
