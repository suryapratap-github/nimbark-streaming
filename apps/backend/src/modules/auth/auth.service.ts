import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { User, UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { randomBytes } from 'crypto';
import { PrismaService } from '../../database/prisma.service';
import { ChangePasswordDto, ForgotPasswordDto, LoginDto, RegisterDto, ResetPasswordDto } from './dto/auth.dto';

type PublicUser = Pick<User, 'id' | 'email' | 'displayName' | 'username' | 'bio' | 'role' | 'avatarUrl'>;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService
  ) {}

  async register(dto: RegisterDto) {
    const email = dto.email.trim().toLowerCase();
    const username = this.normalizeUsername(dto.username);

    const existing = await this.prisma.user.findFirst({
      where: {
        OR: [{ email }, { username }]
      },
      select: { id: true }
    });

    if (existing) {
      throw new ConflictException('Email or username already exists');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);
    const user = await this.prisma.user.create({
      data: {
        email,
        username,
        displayName: dto.displayName.trim(),
        passwordHash,
        role: UserRole.USER
      }
    });

    return this.createAuthResponse(user);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.trim().toLowerCase() }
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const passwordMatches = await bcrypt.compare(dto.password, user.passwordHash);

    if (!passwordMatches) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return this.createAuthResponse(user);
  }

  async forgotPassword(dto: ForgotPasswordDto) {
    const email = dto.email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({ where: { email } });

    if (!user || !user.isActive) {
      return { message: 'If that email exists, a reset code has been generated.' };
    }

    const resetToken = randomBytes(24).toString('hex');
    const passwordResetTokenHash = await bcrypt.hash(resetToken, 12);
    const passwordResetExpiresAt = new Date(Date.now() + 30 * 60 * 1000);

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordResetTokenHash,
        passwordResetExpiresAt
      }
    });

    return {
      message: 'If that email exists, a reset code has been generated.',
      ...(this.config.get<string>('NODE_ENV') === 'development' ? { resetToken } : {})
    };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const users = await this.prisma.user.findMany({
      where: {
        passwordResetTokenHash: { not: null },
        passwordResetExpiresAt: { gt: new Date() },
        isActive: true
      }
    });
    const user = await this.findUserByResetToken(users, dto.token);

    if (!user) {
      throw new BadRequestException('Invalid or expired reset code');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        passwordResetTokenHash: null,
        passwordResetExpiresAt: null
      }
    });

    return { message: 'Password reset successfully' };
  }

  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Invalid or expired token');
    }

    const passwordMatches = await bcrypt.compare(dto.currentPassword, user.passwordHash);

    if (!passwordMatches) {
      throw new UnauthorizedException('Current password is incorrect');
    }

    const passwordHash = await bcrypt.hash(dto.newPassword, 12);
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        passwordResetTokenHash: null,
        passwordResetExpiresAt: null
      }
    });

    return { message: 'Password changed successfully' };
  }

  private async createAuthResponse(user: User) {
    const publicUser = this.toPublicUser(user);
    const accessToken = await this.jwt.signAsync({
      sub: user.id,
      email: user.email,
      role: user.role
    });

    return {
      accessToken,
      tokenType: 'Bearer',
      expiresIn: this.config.get<string>('JWT_EXPIRES_IN') ?? '7d',
      user: publicUser
    };
  }

  private toPublicUser(user: User): PublicUser {
    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      username: user.username,
      bio: user.bio,
      role: user.role,
      avatarUrl: user.avatarUrl
    };
  }

  private normalizeUsername(username: string) {
    return username.trim().toLowerCase().replace(/[^a-z0-9_]/g, '');
  }

  private async findUserByResetToken(users: User[], token: string) {
    for (const user of users) {
      if (!user.passwordResetTokenHash) {
        continue;
      }

      if (await bcrypt.compare(token, user.passwordResetTokenHash)) {
        return user;
      }
    }

    return null;
  }
}
