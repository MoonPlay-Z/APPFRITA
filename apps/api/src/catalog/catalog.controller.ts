import { Body, Controller, Get, Inject, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { CatalogService } from './catalog.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { CreateProductDto } from './dto/create-product.dto';
import { JwtAuthGuard } from '../common/jwt-auth.guard';

@Controller('catalog')
export class CatalogController {
  constructor(@Inject(CatalogService) private svc: CatalogService) {}

  @Post('categories') @UseGuards(JwtAuthGuard)
  createCategory(@Req() req: any, @Body() dto: CreateCategoryDto) { return this.svc.createCategory(req.user.sub, dto); }

  @Post('products') @UseGuards(JwtAuthGuard)
  createProduct(@Req() req: any, @Body() dto: CreateProductDto) { return this.svc.createProduct(req.user.sub, dto); }

  @Get('products') async listProducts(@Query('business_id') businessId: string) { return this.svc.listProducts(businessId); }
  @Get('categories') async listCategories(@Query('business_id') businessId: string) { return this.svc.listCategories(businessId); }
}
