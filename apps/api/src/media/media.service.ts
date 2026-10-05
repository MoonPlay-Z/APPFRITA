import { Inject, Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMediaDto } from './dto/create-media.dto';

const MAX = 5 * 1024 * 1024;
const ALLOWED = ['image/jpeg', 'image/png', 'image/webp'];

@Injectable()
export class MediaService {
  constructor(@Inject(PrismaService) private prisma: PrismaService) {}

  async create(userId: string, dto: CreateMediaDto) {
    if (dto.size_bytes > MAX) throw new BadRequestException('imagen > 5MB');
    if (!ALLOWED.includes(dto.mime_type)) throw new BadRequestException('tipo no permitido');
    return this.prisma.media_assets.create({
      data: { owner_user_id: userId, business_id: dto.business_id, storage_key: dto.storage_key, url: dto.url, thumb_url: dto.thumb_url, mime_type: dto.mime_type, size_bytes: dto.size_bytes, width: dto.width, height: dto.height },
    });
  }

  async get(id: string) {
    return this.prisma.media_assets.findUnique({ where: { id } });
  }
}
