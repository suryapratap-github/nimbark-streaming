import { Injectable } from '@nestjs/common';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { PushNotificationsService } from './push-notifications.service';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pushNotifications: PushNotificationsService
  ) {}

  list(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50
    });
  }

  async unreadCount(userId: string) {
    const count = await this.prisma.notification.count({
      where: {
        userId,
        readAt: null
      }
    });

    return { count };
  }

  async markRead(userId: string, id: string) {
    await this.prisma.notification.updateMany({
      where: {
        id,
        userId
      },
      data: {
        readAt: new Date()
      }
    });

    return { read: true };
  }

  async markAllRead(userId: string) {
    await this.prisma.notification.updateMany({
      where: {
        userId,
        readAt: null
      },
      data: {
        readAt: new Date()
      }
    });

    return { read: true };
  }

  async registerDeviceToken(input: {
    userId: string;
    token: string;
    platform?: string;
  }) {
    const token = input.token.trim();

    if (!token) {
      return { registered: false };
    }

    await this.prisma.pushDeviceToken.upsert({
      where: { token },
      update: {
        userId: input.userId,
        platform: input.platform
      },
      create: {
        userId: input.userId,
        token,
        platform: input.platform
      }
    });

    return { registered: true };
  }

  async create(data: {
    userId: string;
    type: NotificationType;
    title: string;
    body: string;
    data?: Prisma.InputJsonValue;
  }) {
    const notification = await this.prisma.notification.create({
      data
    });

    await this.sendPush(data.userId, data.title, data.body, data.type, data.data);

    return notification;
  }

  async notifyFollow(followerId: string, followingId: string) {
    const follower = await this.prisma.user.findUnique({
      where: { id: followerId },
      select: {
        displayName: true,
        username: true
      }
    });

    const actor = follower?.username ? `@${follower.username}` : follower?.displayName ?? 'Someone';

    return this.create({
      userId: followingId,
      type: NotificationType.FOLLOW,
      title: 'New follower',
      body: `${actor} started following you`,
      data: {
        followerId,
        followingId
      }
    });
  }

  async notifyPostComment(input: {
    creatorId: string;
    commenterId: string;
    postId: string;
    postType: 'video' | 'reel';
    postTitle: string;
  }) {
    if (input.creatorId === input.commenterId) {
      return null;
    }

    const commenter = await this.prisma.user.findUnique({
      where: { id: input.commenterId },
      select: {
        displayName: true,
        username: true
      }
    });
    const actor = commenter?.username ? `@${commenter.username}` : commenter?.displayName ?? 'Someone';

    return this.create({
      userId: input.creatorId,
      type: NotificationType.COMMENT,
      title: 'New comment',
      body: `${actor} commented on ${input.postTitle}`,
      data: {
        postId: input.postId,
        postType: input.postType
      }
    });
  }

  async notifyLiveStarted(input: {
    hostId: string;
    roomId: string;
    title: string;
  }) {
    const [host, followers] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: input.hostId },
        select: {
          displayName: true,
          username: true
        }
      }),
      this.prisma.follow.findMany({
        where: { followingId: input.hostId },
        select: { followerId: true }
      })
    ]);

    if (followers.length === 0) {
      return { created: 0 };
    }

    const hostName = host?.username ? `@${host.username}` : host?.displayName ?? 'A creator';

    const notifications = followers.map((follow) => ({
        userId: follow.followerId,
        type: NotificationType.LIVE_STARTED,
        title: 'Live now',
        body: `${hostName} is live: ${input.title}`,
        data: {
          roomId: input.roomId,
          hostId: input.hostId
        }
      }));

    await this.prisma.notification.createMany({
      data: notifications
    });

    await Promise.all(
      notifications.map((notification) =>
        this.sendPush(notification.userId, notification.title, notification.body, notification.type, notification.data)
      )
    );

    return { created: followers.length };
  }

  private async sendPush(
    userId: string,
    title: string,
    body: string,
    type: NotificationType,
    data?: Prisma.InputJsonValue
  ) {
    const tokens = await this.prisma.pushDeviceToken.findMany({
      where: { userId },
      select: { token: true }
    });

    const stringData = this.pushData(type, data);
    const result = await this.pushNotifications.sendToTokens({
      tokens: tokens.map((token) => token.token),
      title,
      body,
      data: stringData
    });

    if (result.failedTokens.length > 0) {
      await this.prisma.pushDeviceToken.deleteMany({
        where: { token: { in: result.failedTokens } }
      });
    }
  }

  private pushData(type: NotificationType, data?: Prisma.InputJsonValue) {
    const payload: Record<string, string> = {
      type
    };

    if (!data || typeof data !== 'object' || Array.isArray(data)) {
      return payload;
    }

    for (const [key, value] of Object.entries(data)) {
      if (value !== null && value !== undefined) {
        payload[key] = String(value);
      }
    }

    return payload;
  }
}
