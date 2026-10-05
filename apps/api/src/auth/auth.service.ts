import { Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(@Inject(PrismaService) private prisma: PrismaService, @Inject(JwtService) private jwt: JwtService) {}

  async register(dto: RegisterDto) {
    if (!dto.email && !dto.phone) throw new UnauthorizedException('email o phone requerido');
    const user = await this.prisma.users.create({
      data: {
        email: dto.email,
        phone: dto.phone,
        full_name: dto.full_name,
        password_hash: await this.hash(dto.password),
      },
    });
    return { id: user.id, email: user.email, full_name: user.full_name };
  }

  async login(identifier: string, password: string) {
    const user = await this.prisma.users.findFirst({
      where: { OR: [{ email: identifier }, { phone: identifier }] },
    });
    if (!user || !user.password_hash || !(await this.verify(password, user.password_hash))) {
      throw new UnauthorizedException('credenciales inválidas');
    }
    return { access_token: this.jwt.sign({ sub: user.id, role: user.role }) };
  }

  private async hash(pw: string) {
    const bcrypt = await import('bcryptjs');
    return bcrypt.hash(pw, 10);
  }
  private async verify(pw: string, h: string) {
    const bcrypt = await import('bcryptjs');
    return bcrypt.compare(pw, h);
  }
}
