import { Body, Controller, Get, Inject, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { OrdersService } from './orders.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { JwtAuthGuard } from '../common/jwt-auth.guard';

@Controller('orders')
@UseGuards(JwtAuthGuard)
export class OrdersController {
  constructor(@Inject(OrdersService) private svc: OrdersService) {}

  @Post() create(@Req() req: any, @Body() dto: CreateOrderDto) { return this.svc.create(req.user.sub, dto); }
  @Get('mine') mine(@Req() req: any) { return this.svc.mine(req.user.sub); }
  @Get('business') business(@Req() req: any, @Query('business_id') b: string) { return this.svc.businessOrders(req.user.sub, b); }
  @Patch(':id/status') update(@Req() req: any, @Param('id') id: string, @Body() dto: UpdateOrderStatusDto) { return this.svc.updateStatus(req.user.sub, id, dto); }
}
