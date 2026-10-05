import { Body, Controller, Get, Inject, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { LocationsService } from './locations.service';
import { CreateLocationDto } from './dto/create-location.dto';
import { JwtAuthGuard } from '../common/jwt-auth.guard';

@Controller('locations')
export class LocationsController {
  constructor(@Inject(LocationsService) private svc: LocationsService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  create(@Req() req: any, @Body() dto: CreateLocationDto) { return this.svc.create(req.user.sub, dto); }

  @Patch(':id/open')
  @UseGuards(JwtAuthGuard)
  open(@Req() req: any, @Param('id') id: string, @Body('is_open') isOpen: boolean) { return this.svc.setOpen(req.user.sub, id, !!isOpen); }

  @Get('nearby')
  nearby(@Query('lng') lng: string, @Query('lat') lat: string, @Query('radius_m') r?: string) {
    return this.svc.nearby(+lng, +lat, r ? +r : 5000);
  }
}
