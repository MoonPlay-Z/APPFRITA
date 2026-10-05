import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateLocationDto } from './dto/create-location.dto';

@Injectable()
export class LocationsService {
  constructor(@Inject(PrismaService) private prisma: PrismaService) {}

  // locations.geo es GEOGRAPHY (Unsupported en Prisma) → insertar con SQL crudo
  async create(userId: string, dto: CreateLocationDto) {
    await this.assertMember(userId, dto.business_id);
    const rows: any[] = await this.prisma.$queryRawUnsafe(
      `INSERT INTO locations (business_id, name, address, geo, is_mobile_stall, accepts_delivery, accepts_pickup, accepts_reservations, delivery_radius_m, delivery_fee, min_order)
       VALUES ($1,$2,$3, ST_MakePoint($4,$5)::geography, $6,$7,$8,$9,$10,$11,$12) RETURNING id, name, is_open_now`,
      dto.business_id, dto.name, dto.address, dto.lng, dto.lat,
      dto.is_mobile_stall ?? false, dto.accepts_delivery ?? true, dto.accepts_pickup ?? true,
      dto.accepts_reservations ?? false, dto.delivery_radius_m ?? null, dto.delivery_fee ?? 0, dto.min_order ?? 0);
    return rows[0];
  }

  async setOpen(userId: string, id: string, isOpen: boolean) {
    const loc: any = await this.prisma.locations.findUnique({ where: { id } });
    if (!loc) throw new NotFoundException('local no encontrado');
    await this.assertMember(userId, loc.business_id);
    return this.prisma.locations.update({ where: { id }, data: { is_open_now: isOpen, open_updated_at: new Date() } });
  }

  async nearby(lng: number, lat: number, radiusM: number) {
    return this.prisma.$queryRawUnsafe(
      `SELECT l.id, l.name, b.name AS business_name, b.rating_avg,
              ST_Distance(l.geo, ST_MakePoint($1,$2)::geography) AS dist_m
       FROM locations l JOIN businesses b ON b.id = l.business_id
       WHERE l.is_active AND l.is_open_now AND b.is_active
         AND ST_DWithin(l.geo, ST_MakePoint($1,$2)::geography, $3)
       ORDER BY (SELECT COUNT(*) FROM ad_boosts a WHERE a.location_id=l.id AND now() BETWEEN a.starts_at AND a.ends_at) DESC, dist_m ASC
       LIMIT 30`, lng, lat, radiusM);
  }

  private async assertMember(userId: string, businessId: string) {
    const m = await this.prisma.business_members.findFirst({ where: { business_id: businessId, user_id: userId } });
    if (!m) throw new NotFoundException('no eres miembro de este negocio');
  }
}
