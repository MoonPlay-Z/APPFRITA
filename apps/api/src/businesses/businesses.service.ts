import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateBusinessDto } from './dto/create-business.dto';

@Injectable()
export class BusinessesService {
  constructor(@Inject(PrismaService) private prisma: PrismaService) {}

  async create(userId: string, dto: CreateBusinessDto) {
    const biz = await this.prisma.businesses.create({
      data: { owner_id: userId, name: dto.name, slug: dto.slug, description: dto.description, category: dto.category, phone: dto.phone, whatsapp_number: dto.whatsapp_number, currency: dto.currency ?? 'USD' },
    });
    await this.prisma.business_members.create({ data: { business_id: biz.id, user_id: userId, role: 'owner' } });
    return biz;
  }

  async mine(userId: string) {
    return this.prisma.businesses.findMany({ where: { business_members: { some: { user_id: userId } } } });
  }

  async findOne(id: string) {
    const b = await this.prisma.businesses.findUnique({ where: { id } });
    if (!b) throw new NotFoundException('negocio no encontrado');
    return b;
  }
}
