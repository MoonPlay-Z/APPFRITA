import { Inject, Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';

const TRANSITIONS: Record<string, string[]> = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['preparing', 'cancelled'],
  preparing: ['ready', 'cancelled'],
  ready: ['sent', 'delivered', 'cancelled'],
  sent: ['delivered'],
  delivered: [],
  cancelled: [],
};

@Injectable()
export class OrdersService {
  constructor(@Inject(PrismaService) private prisma: PrismaService) {}

  async create(userId: string, dto: CreateOrderDto) {
    const products = await this.prisma.products.findMany({ where: { id: { in: dto.items.map(i => i.product_id) } } });
    if (products.length !== dto.items.length) throw new BadRequestException('algún producto no existe');
    let subtotal = 0;
    const items = dto.items.map(i => {
      const p = products.find(p => p.id === i.product_id)!;
      const line = Number(p.price) * i.quantity;
      subtotal += line;
      return { product_id: p.id, name_snapshot: p.name, unit_price_snapshot: p.price, quantity: i.quantity, options_snapshot: i.options ?? null, line_total: line, note: i.note };
    });
    const location: any = await this.prisma.locations.findUnique({ where: { id: dto.location_id } });
    const deliveryFee = dto.type === 'delivery' ? Number(location?.delivery_fee ?? 0) : 0;
    const code = '#' + Math.random().toString(36).slice(2, 6).toUpperCase();
    const order = await this.prisma.orders.create({
      data: {
        code, business_id: dto.business_id, location_id: dto.location_id, customer_id: userId,
        type: dto.type as any, subtotal, delivery_fee: deliveryFee, total: subtotal + deliveryFee,
        delivery_address: dto.delivery_address, customer_note: dto.customer_note,
        order_items: { create: items },
      },
      include: { order_items: true },
    });
    await this.prisma.order_status_history.create({ data: { order_id: order.id, to_status: 'pending', to_payment: 'unpaid', changed_by: userId } });
    return order;
  }

  async mine(userId: string) {
    return this.prisma.orders.findMany({ where: { customer_id: userId }, orderBy: { created_at: 'desc' }, include: { order_items: true } });
  }

  async businessOrders( userId: string, businessId: string) {
    await this.assertMember(userId, businessId);
    return this.prisma.orders.findMany({ where: { business_id: businessId }, orderBy: { created_at: 'desc' }, include: { order_items: true } });
  }

  async updateStatus(userId: string, orderId: string, dto: UpdateOrderStatusDto) {
    const order = await this.prisma.orders.findUnique({ where: { id: orderId } });
    if (!order) throw new NotFoundException('pedido no encontrado');
    await this.assertMember(userId, order.business_id);
    const data: any = {};
    if (dto.status) {
      const allowed = TRANSITIONS[order.status] ?? [];
      if (!allowed.includes(dto.status)) throw new BadRequestException(`transición ${order.status} → ${dto.status} no válida`);
      data.status = dto.status;
      if (dto.status === 'sent') data.sent_at = new Date();
      if (dto.status === 'delivered') data.delivered_at = new Date();
      if (dto.status === 'cancelled') data.cancelled_reason = dto.note ?? null;
    }
    if (dto.payment_status) {
      data.payment_status = dto.payment_status;
      if (dto.payment_status === 'paid') { data.paid_at = new Date(); data.paid_confirmed_by = userId; }
    }
    const updated = await this.prisma.orders.update({ where: { id: orderId }, data });
    await this.prisma.order_status_history.create({
      data: { order_id: orderId, from_status: order.status, to_status: (dto.status ?? order.status) as any, from_payment: order.payment_status, to_payment: (dto.payment_status ?? order.payment_status) as any, changed_by: userId, note: dto.note },
    });
    return updated;
  }

  private async assertMember(userId: string, businessId: string) {
    const m = await this.prisma.business_members.findFirst({ where: { business_id: businessId, user_id: userId } });
    if (!m) throw new NotFoundException('no eres miembro de este negocio');
  }
}
