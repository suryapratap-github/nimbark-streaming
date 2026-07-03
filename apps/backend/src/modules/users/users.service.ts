import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ReportTargetType, SubscriptionStatus, UserRole } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { UpdateLocationDto } from './dto/update-location.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService
  ) {}

  subscriptionPlans() {
    return this.prisma.subscriptionPlan.findMany({
      where: { isActive: true },
      orderBy: { priceCents: 'asc' }
    });
  }

  searchCreators(query: string) {
    const term = query.trim();

    if (term.length < 2) {
      return [];
    }

    return this.prisma.user.findMany({
      where: {
        role: UserRole.CREATOR,
        isActive: true,
        OR: [
          { username: { contains: term, mode: 'insensitive' } },
          { displayName: { contains: term, mode: 'insensitive' } },
          { bio: { contains: term, mode: 'insensitive' } }
        ]
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
      select: {
        id: true,
        displayName: true,
        username: true,
        bio: true,
        avatarUrl: true,
        _count: {
          select: {
            followers: true,
            videos: true,
            reels: true,
            creatorLikesReceived: true,
            creatorSharesReceived: true
          }
        }
      }
    });
  }


  async getProfile(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        email: true,
        displayName: true,
        username: true,
        bio: true,
        avatarUrl: true,
        role: true,
        lastLatitude: true,
        lastLongitude: true,
        locationSource: true,
        locationUpdatedAt: true,
        createdAt: true,
        _count: {
          select: {
            followers: true,
            following: true,
            videos: true,
            reels: true,
            creatorLikesReceived: true,
            creatorSharesReceived: true
          }
        }
      }
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user;
  }

  updateProfile(id: string, dto: UpdateProfileDto, authenticatedUserId?: string) {
    this.ensureSelf(id, authenticatedUserId);

    return this.prisma.user.update({
      where: { id },
      data: {
        displayName: dto.displayName?.trim(),
        bio: dto.bio?.trim(),
        avatarUrl: dto.avatarUrl?.trim()
      },
      select: {
        id: true,
        email: true,
        displayName: true,
        username: true,
        bio: true,
        avatarUrl: true,
        role: true
      }
    });
  }

  async deleteProfile(id: string, authenticatedUserId?: string) {
    this.ensureSelf(id, authenticatedUserId);

    const user = await this.prisma.user.findUnique({
      where: { id },
      select: { role: true }
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (user.role === UserRole.ADMIN) {
      throw new BadRequestException('Admin profiles cannot be deleted from the app');
    }

    await this.prisma.user.delete({ where: { id } });
    return { deleted: true, id };
  }

  async updateLocation(id: string, dto: UpdateLocationDto, authenticatedUserId?: string) {
    if (!authenticatedUserId || authenticatedUserId !== id) {
      throw new ForbiddenException('You can only update location for the logged-in user');
    }

    await this.ensureUserExists(id);

    const source = dto.source ?? 'mobile';

    await this.prisma.userLocation.create({
      data: {
        userId: id,
        latitude: dto.latitude,
        longitude: dto.longitude,
        source
      }
    });

    return this.prisma.user.update({
      where: { id },
      data: {
        lastLatitude: dto.latitude,
        lastLongitude: dto.longitude,
        locationSource: source,
        locationUpdatedAt: new Date()
      },
      select: {
        id: true,
        lastLatitude: true,
        lastLongitude: true,
        locationSource: true,
        locationUpdatedAt: true
      }
    });
  }

  async follow(followerId: string, followingId: string) {
    if (followerId === followingId) {
      throw new BadRequestException('You cannot follow yourself');
    }

    await this.ensureUserExists(followingId);

    const existing = await this.prisma.follow.findUnique({
      where: {
        followerId_followingId: {
          followerId,
          followingId
        }
      }
    });

    if (existing) {
      return existing;
    }

    const follow = await this.prisma.follow.create({
      data: {
        followerId,
        followingId
      }
    });

    await this.notifications.notifyFollow(followerId, followingId);

    return follow;
  }

  async toggleCreatorLike(userId: string, creatorId: string) {
    if (userId === creatorId) {
      throw new BadRequestException('You cannot like your own creator profile');
    }

    await this.ensureCreatorExists(creatorId);

    const existing = await this.prisma.creatorLike.findUnique({
      where: {
        userId_creatorId: {
          userId,
          creatorId
        }
      },
      select: { id: true }
    });

    if (existing) {
      await this.prisma.creatorLike.delete({ where: { id: existing.id } });
      return { liked: false };
    }

    await this.prisma.creatorLike.create({
      data: {
        userId,
        creatorId
      }
    });

    return { liked: true };
  }

  async shareCreator(userId: string, creatorId: string) {
    if (userId === creatorId) {
      throw new BadRequestException('You cannot share your own creator profile');
    }

    await this.ensureCreatorExists(creatorId);

    await this.prisma.creatorShare.create({
      data: {
        userId,
        creatorId
      }
    });

    return { shared: true };
  }

  async reportUser(reporterId: string, subjectUserId: string, reason: string) {
    if (reporterId === subjectUserId) {
      throw new BadRequestException('You cannot report yourself');
    }

    await this.ensureUserExists(subjectUserId);

    const trimmed = reason.trim();

    if (!trimmed) {
      throw new BadRequestException('Report reason is required');
    }

    if (trimmed.length > 500) {
      throw new BadRequestException('Report reason must be 500 characters or less');
    }

    return this.prisma.report.create({
      data: {
        reporterId,
        subjectUserId,
        targetType: ReportTargetType.USER,
        targetId: subjectUserId,
        reason: trimmed
      }
    });
  }

  async unfollow(followerId: string, followingId: string) {
    await this.prisma.follow.deleteMany({
      where: {
        followerId,
        followingId
      }
    });

    return { following: false };
  }

  async subscription(id: string, authenticatedUserId?: string) {
    this.ensureSelf(id, authenticatedUserId);

    return this.prisma.userSubscription.findFirst({
      where: {
        userId: id,
        status: SubscriptionStatus.ACTIVE,
        expiresAt: { gt: new Date() }
      },
      orderBy: { expiresAt: 'desc' },
      include: { plan: true }
    });
  }

  async cancel(id: string, authenticatedUserId?: string) {
    this.ensureSelf(id, authenticatedUserId);

    const subscription = await this.prisma.userSubscription.findFirst({
      where: {
        userId: id,
        status: SubscriptionStatus.ACTIVE,
        expiresAt: { gt: new Date() }
      },
      orderBy: { expiresAt: 'desc' }
    });

    if (!subscription) {
      throw new NotFoundException('No active subscription found');
    }

    const updated = await this.prisma.userSubscription.update({
      where: { id: subscription.id },
      data: {
        status: SubscriptionStatus.CANCELLED,
        canceledAt: new Date()
      }
    });

    await this.downgradeIfCreator(id);

    return updated;
  }

  async downgradeExpiredSubscriptions() {
    const now = new Date();

    const expired = await this.prisma.userSubscription.findMany({
      where: {
        status: SubscriptionStatus.ACTIVE,
        expiresAt: { lte: now }
      },
      select: { userId: true },
      distinct: ['userId']
    });

    const userIds = [...new Set(expired.map((e) => e.userId))];

    await this.prisma.userSubscription.updateMany({
      where: {
        userId: { in: userIds },
        status: SubscriptionStatus.ACTIVE,
        expiresAt: { lte: now }
      },
      data: { status: SubscriptionStatus.EXPIRED }
    });

    let reverted = 0;

    for (const userId of userIds) {
      reverted += await this.downgradeIfCreator(userId);
    }

    return { reverted, expiredUserIds: userIds.length };
  }

  private async downgradeIfCreator(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, subscriptions: { where: { status: SubscriptionStatus.ACTIVE, expiresAt: { gt: new Date() } }, take: 1 } }
    });

    if (user?.role === UserRole.CREATOR && user.subscriptions.length === 0) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { role: UserRole.USER }
      });

      return 1;
    }

    return 0;
  }

  async subscribe(id: string, planId: string, authenticatedUserId?: string) {
    this.ensureSelf(id, authenticatedUserId);
    throw new BadRequestException('Use RevenueCat purchase flow to subscribe');
  }

  private async ensureUserExists(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: { id: true }
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }
  }

  private ensureSelf(id: string, authenticatedUserId?: string) {
    if (!authenticatedUserId || authenticatedUserId !== id) {
      throw new ForbiddenException('You can only perform this action for the logged-in user');
    }
  }

  private async ensureCreatorExists(id: string) {
    const user = await this.prisma.user.findFirst({
      where: {
        id,
        role: UserRole.CREATOR,
        isActive: true
      },
      select: { id: true }
    });

    if (!user) {
      throw new NotFoundException('Creator not found');
    }
  }
}
