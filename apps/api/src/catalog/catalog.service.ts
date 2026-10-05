import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { CreateProductDto } from './dto/create-product.dto';

@Injectable()
export class CatalogService {
  constructor(@Inject(PrismaService) private prisma: PrismaService) {}

  private async assertMember(userId: string, businessId: string) {
    const m = await this.prisma.business_members.findFirst({ where: { business_id: businessId, user_id: userId } });
    if (!m) throw new NotFoundException('no eres miembro de este negocio');
  }

  async createCategory(userId: string, dto: CreateCategoryDto) {
    await this.assertMember(userId, dto.business_id);
    return this.prisma.product_categories.create({ data: { business_id: dto.business_id, name: dto.name, sort_order: dto.sort_order ?? 0 } });
  }

  async createProduct(userId: string, dto: CreateProductDto) {
    await this.assertMember(userId, dto.business_id);
    return this.prisma.products.create({
      data: { business_id: dto.business_id, category_id: dto.category_id, name: dto.name, description: dto.description, price: dto.price, sort_order: dto.sort_order ?? 0, is_available: dto.is_available ?? true },
    });
  }

  async listProducts(businessId: string) {
    return this.prisma.products.findMany({ where: { business_id: businessId, is_available: true }, orderBy: { sort_order: 'asc' } });
  }

  async listCategories(businessId: string) {
    return this.prisma.product_categories.findMany({ where: { business_id: businessId }, orderBy: { sort_order: 'asc' } });
  }
}
