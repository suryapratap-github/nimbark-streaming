import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { LiveRoomStatus, Prisma, PublishStatus, ReportStatus, ReportTargetType, SubscriptionStatus, UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../../database/prisma.service';
import { StorageService, UpdateStorageSettingsInput } from '../storage/storage.service';
import { CreateAdminUserDto } from './dto/create-admin-user.dto';
import { CreateSubscriptionPlanDto } from './dto/create-subscription-plan.dto';
import { UpdateAdminUserDto } from './dto/update-admin-user.dto';
import { UpdateSubscriptionPlanDto } from './dto/update-subscription-plan.dto';

const adminUserSelect = {
  id: true,
  email: true,
  displayName: true,
  username: true,
  avatarUrl: true,
  bio: true,
  role: true,
  isActive: true,
  lastLatitude: true,
  lastLongitude: true,
  locationSource: true,
  locationUpdatedAt: true,
  createdAt: true,
  subscriptions: {
    where: {
      status: SubscriptionStatus.ACTIVE,
      expiresAt: { gt: new Date() }
    },
    orderBy: { expiresAt: 'desc' },
    take: 1,
    include: { plan: true }
  },
  _count: {
    select: {
      followers: true,
      following: true,
      videos: true,
      reels: true
    }
  }
} as const;

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService
  ) {}

  async dashboard() {
    const [users, videos, reels, pendingReports, activeLiveRooms] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.video.count(),
      this.prisma.reel.count(),
      this.prisma.report.count({ where: { status: ReportStatus.OPEN } }),
      this.prisma.liveRoom.count({ where: { status: LiveRoomStatus.LIVE } })
    ]);

    return {
      users,
      videos,
      reels,
      pendingReports,
      activeLiveRooms
    };
  }

  storageSettings() {
    return this.storage.settings();
  }

  storageHealth() {
    return this.storage.health();
  }

  cleanupOrphanedMedia(dryRun = true) {
    return this.storage.cleanupOrphanedLocalMedia({ dryRun });
  }

  updateStorageSettings(input: UpdateStorageSettingsInput) {
    return this.storage.updateSettings(input);
  }

  mediaProcessingJobs() {
    return this.prisma.mediaProcessingJob.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        mediaAsset: true,
        video: {
          select: {
            id: true,
            title: true,
            status: true
          }
        },
        reel: {
          select: {
            id: true,
            caption: true,
            status: true
          }
        },
        liveRecording: {
          select: {
            id: true,
            status: true,
            room: {
              select: {
                id: true,
                title: true
              }
            }
          }
        }
      }
    });
  }

  auditLogs(filters: { action?: string; adminId?: string; target?: string }) {
    const action = filters.action?.trim();
    const adminId = filters.adminId?.trim();
    const target = filters.target?.trim();

    return this.prisma.adminAuditLog.findMany({
      where: {
        action: action || undefined,
        adminId: adminId || undefined,
        target: target
          ? {
              contains: target,
              mode: Prisma.QueryMode.insensitive
            }
          : undefined
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        admin: {
          select: {
            id: true,
            displayName: true,
            username: true,
            email: true
          }
        }
      }
    });
  }

  users() {
    return this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: adminUserSelect
    });
  }

  async createUser(dto: CreateAdminUserDto) {
    const email = dto.email.trim().toLowerCase();
    const username = this.normalizeUsername(dto.username);
    const role = this.normalizeEditableRole(dto.role);

    await this.ensureUniqueUser(email, username);

    const passwordHash = await bcrypt.hash(dto.password, 12);

    return this.prisma.user.create({
      data: {
        email,
        username,
        displayName: dto.displayName.trim(),
        passwordHash,
        role
      },
      select: adminUserSelect
    });
  }

  async updateUser(id: string, dto: UpdateAdminUserDto) {
    const user = await this.ensureUserExists(id);

    if (user.role === UserRole.ADMIN) {
      throw new BadRequestException('Admin accounts cannot be edited from this panel');
    }

    const email = dto.email?.trim().toLowerCase();
    const username = dto.username ? this.normalizeUsername(dto.username) : undefined;

    if (email || username) {
      await this.ensureUniqueUser(email, username, id);
    }

    return this.prisma.user.update({
      where: { id },
      data: {
        email,
        username,
        displayName: dto.displayName?.trim(),
        bio: dto.bio?.trim(),
        role: dto.role ? this.normalizeEditableRole(dto.role) : undefined,
        passwordHash: dto.password ? await bcrypt.hash(dto.password, 12) : undefined
      },
      select: adminUserSelect
    });
  }

  async reports(statusFilter = 'ALL') {
    const normalizedStatus = statusFilter.trim().toUpperCase();
    const where = Object.values(ReportStatus).includes(normalizedStatus as ReportStatus)
      ? { status: normalizedStatus as ReportStatus }
      : undefined;

    const reports = await this.prisma.report.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: {
        reporter: {
          select: {
            id: true,
            displayName: true,
            username: true,
            email: true
          }
        },
        subjectUser: {
          select: {
            id: true,
            displayName: true,
            username: true,
            email: true
          }
        }
      }
    });

    return this.enrichReports(reports);
  }

  async updateReportStatus(id: string, status: ReportStatus, adminId?: string) {
    if (!Object.values(ReportStatus).includes(status)) {
      throw new BadRequestException('Invalid report status');
    }

    const report = await this.prisma.report.update({
      where: { id },
      data: { status },
      include: {
        reporter: {
          select: {
            id: true,
            displayName: true,
            username: true,
            email: true
          }
        },
        subjectUser: {
          select: {
            id: true,
            displayName: true,
            username: true,
            email: true
          }
        }
      }
    });

    await this.createAudit(adminId, 'REPORT_STATUS_UPDATE', `REPORT:${id}`, { status });

    return report;
  }

  async actionReport(id: string, action: 'MARK_REVIEWING' | 'DISMISS' | 'BLOCK_CONTENT' | 'BLOCK_USER', adminId?: string) {
    const report = await this.prisma.report.findUnique({
      where: { id },
      include: {
        reporter: {
          select: {
            id: true,
            displayName: true,
            username: true,
            email: true
          }
        },
        subjectUser: {
          select: {
            id: true,
            displayName: true,
            username: true,
            email: true,
            role: true
          }
        }
      }
    });

    if (!report) {
      throw new NotFoundException('Report not found');
    }

    if (action === 'MARK_REVIEWING') {
      return this.updateReportStatus(id, ReportStatus.REVIEWING, adminId);
    }

    if (action === 'DISMISS') {
      return this.updateReportStatus(id, ReportStatus.REJECTED, adminId);
    }

    if (action === 'BLOCK_USER') {
      if (!report.subjectUserId || !report.subjectUser) {
        throw new BadRequestException('This report has no target user to block');
      }

      if (report.subjectUserId === adminId) {
        throw new BadRequestException('You cannot block yourself');
      }

      if (report.subjectUser.role === UserRole.ADMIN) {
        throw new BadRequestException('Admin accounts cannot be blocked from reports');
      }

      await this.prisma.user.update({
        where: { id: report.subjectUserId },
        data: { isActive: false }
      });
      await this.createAudit(adminId, 'REPORT_BLOCK_USER', `USER:${report.subjectUserId}`, { reportId: id });

      return this.updateReportStatus(id, ReportStatus.RESOLVED, adminId);
    }

    await this.blockReportedContent(report);
    await this.createAudit(adminId, 'REPORT_BLOCK_CONTENT', `${report.targetType}:${report.targetId}`, { reportId: id });

    return this.updateReportStatus(id, ReportStatus.RESOLVED, adminId);
  }

  async feedItems(statusFilter = 'ACTIVE') {
    const where = this.feedStatusWhere(statusFilter);
    const include = {
      creator: {
        select: {
          id: true,
          displayName: true,
          username: true,
          email: true
        }
      },
      mediaAsset: true,
      thumbnail: true,
      _count: {
        select: {
          comments: true,
          likes: true,
          dislikes: true,
          shares: true
        }
      }
    };

    const [videos, reels] = await Promise.all([
      this.prisma.video.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: 50,
        include
      }),
      this.prisma.reel.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: 50,
        include
      })
    ]);

    return [
      ...videos.map((item) => ({ ...item, feedType: 'VIDEO' as const, label: item.title })),
      ...reels.map((item) => ({ ...item, feedType: 'REEL' as const, label: item.caption || 'Reel' }))
    ]
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, 100);
  }

  private feedStatusWhere(statusFilter: string) {
    const normalizedStatus = statusFilter.trim().toUpperCase();

    if (normalizedStatus === 'PUBLISHED') {
      return { status: PublishStatus.PUBLISHED };
    }

    if (normalizedStatus === 'BLOCKED') {
      return { status: PublishStatus.REJECTED };
    }

    if (normalizedStatus === 'DELETED') {
      return { status: PublishStatus.DELETED };
    }

    return { status: { in: [PublishStatus.PUBLISHED, PublishStatus.REJECTED] } };
  }

  async updateFeedItem(
    type: 'VIDEO' | 'REEL',
    id: string,
    input: { status?: PublishStatus; commentsEnabled?: boolean },
    adminId?: string
  ) {
    if (input.status && !Object.values(PublishStatus).includes(input.status)) {
      throw new BadRequestException('Invalid feed status');
    }

    const data = {
      status: input.status,
      commentsEnabled: input.commentsEnabled
    };

    if (type === 'VIDEO') {
      const updated = await this.prisma.video.update({
        where: { id },
        data,
        include: {
          creator: {
            select: {
              id: true,
              displayName: true,
              username: true,
              email: true
            }
          },
          mediaAsset: true,
          thumbnail: true,
          _count: {
            select: {
              comments: true,
              likes: true,
              dislikes: true,
              shares: true
            }
          }
        }
      });
      await this.createAudit(adminId, 'FEED_UPDATE', `VIDEO:${id}`, input);
      return updated;
    }

    const updated = await this.prisma.reel.update({
      where: { id },
      data,
      include: {
        creator: {
          select: {
            id: true,
            displayName: true,
            username: true,
            email: true
          }
        },
        mediaAsset: true,
        thumbnail: true,
        _count: {
          select: {
            comments: true,
            likes: true,
            dislikes: true,
            shares: true
          }
        }
      }
    });
    await this.createAudit(adminId, 'FEED_UPDATE', `REEL:${id}`, input);
    return updated;
  }

  async liveRooms() {
    await this.closeStaleViewerSessions();

    const rooms = await this.prisma.liveRoom.findMany({
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: {
        host: {
          select: {
            id: true,
            displayName: true,
            username: true,
            email: true
          }
        },
        recordings: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: {
            id: true,
            egressId: true,
            objectKey: true,
            publicUrl: true,
            status: true,
            errorMessage: true,
            startedAt: true,
            endedAt: true,
            createdAt: true
          }
        },
        _count: {
          select: {
            comments: true,
            reactions: true,
            recordings: true
          }
        }
      }
    });

    const now = new Date();

    return rooms.map((room) => {
      const liveUntil = room.endedAt ?? (room.status === LiveRoomStatus.LIVE ? now : null);
      const durationSeconds = room.startedAt && liveUntil
        ? Math.max(0, Math.floor((liveUntil.getTime() - room.startedAt.getTime()) / 1000))
        : 0;

      return {
        ...room,
        hostName: room.host.displayName || room.host.username,
        durationSeconds
      };
    });
  }

  private async closeStaleViewerSessions() {
    const now = new Date();
    const cutoff = new Date(now.getTime() - 90_000);
    const staleSessions = await this.prisma.liveRoomViewerSession.findMany({
      where: {
        leftAt: null,
        lastSeenAt: { lt: cutoff },
        room: {
          status: LiveRoomStatus.LIVE
        }
      },
      distinct: ['roomId'],
      select: {
        roomId: true
      }
    });
    const roomIds = staleSessions.map((session) => session.roomId);

    if (!roomIds.length) {
      return;
    }

    await this.prisma.liveRoomViewerSession.updateMany({
      where: {
        roomId: { in: roomIds },
        leftAt: null,
        lastSeenAt: { lt: cutoff }
      },
      data: {
        leftAt: now,
        lastSeenAt: now
      }
    });

    await Promise.all(
      roomIds.map(async (roomId) => {
        const currentViewerCount = await this.prisma.liveRoomViewerSession.count({
          where: {
            roomId,
            leftAt: null
          }
        });

        await this.prisma.liveRoom.update({
          where: { id: roomId },
          data: { currentViewerCount }
        });
      })
    );
  }

  async locationInsights() {
    const [locatedUsers, recentLocations] = await Promise.all([
      this.prisma.user.count({
        where: {
          lastLatitude: { not: null },
          lastLongitude: { not: null }
        }
      }),
      this.prisma.userLocation.findMany({
        orderBy: { createdAt: 'desc' },
        take: 1000,
        include: {
          user: {
            select: {
              id: true,
              displayName: true,
              username: true
            }
          }
        }
      })
    ]);

    const clusters = new Map<
      string,
      {
        latitude: number;
        longitude: number;
        users: Set<string>;
        pings: number;
        lastSeenAt: Date;
      }
    >();

    for (const location of recentLocations) {
      const latitude = Number(location.latitude.toFixed(2));
      const longitude = Number(location.longitude.toFixed(2));
      const key = `${latitude},${longitude}`;
      const cluster = clusters.get(key) ?? {
        latitude,
        longitude,
        users: new Set<string>(),
        pings: 0,
        lastSeenAt: location.createdAt
      };

      cluster.users.add(location.userId);
      cluster.pings += 1;

      if (location.createdAt > cluster.lastSeenAt) {
        cluster.lastSeenAt = location.createdAt;
      }

      clusters.set(key, cluster);
    }

    return {
      locatedUsers,
      totalLocationPings: recentLocations.length,
      topLocations: Array.from(clusters.values())
        .map((cluster) => ({
          latitude: cluster.latitude,
          longitude: cluster.longitude,
          users: cluster.users.size,
          pings: cluster.pings,
          lastSeenAt: cluster.lastSeenAt
        }))
        .sort((a, b) => b.users - a.users || b.pings - a.pings)
        .slice(0, 10)
    };
  }

  subscriptionPlans() {
    return this.prisma.subscriptionPlan.findMany({
      orderBy: { createdAt: 'desc' }
    });
  }

  createSubscriptionPlan(dto: CreateSubscriptionPlanDto) {
    return this.prisma.subscriptionPlan.create({
      data: {
        name: dto.name.trim(),
        description: dto.description?.trim(),
        priceCents: dto.priceCents,
        currency: dto.currency?.trim().toUpperCase() ?? 'INR',
        durationDays: dto.durationDays,
        revenueCatOfferingId: this.cleanNullable(dto.revenueCatOfferingId),
        revenueCatPackageId: this.cleanNullable(dto.revenueCatPackageId),
        revenueCatEntitlementId: this.cleanNullable(dto.revenueCatEntitlementId),
        isActive: dto.isActive ?? true
      }
    });
  }

  async updateSubscriptionPlan(id: string, dto: UpdateSubscriptionPlanDto) {
    await this.ensurePlanExists(id);

    return this.prisma.subscriptionPlan.update({
      where: { id },
      data: {
        name: dto.name?.trim(),
        description: dto.description?.trim(),
        priceCents: dto.priceCents,
        currency: dto.currency?.trim().toUpperCase(),
        durationDays: dto.durationDays,
        revenueCatOfferingId: this.cleanNullable(dto.revenueCatOfferingId),
        revenueCatPackageId: this.cleanNullable(dto.revenueCatPackageId),
        revenueCatEntitlementId: this.cleanNullable(dto.revenueCatEntitlementId),
        isActive: dto.isActive
      }
    });
  }

  paymentEvents() {
    return this.prisma.paymentEvent.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        user: {
          select: {
            id: true,
            displayName: true,
            username: true,
            email: true
          }
        }
      }
    });
  }

  async updateUserAccess(id: string, isActive: boolean, adminId?: string) {
    if (id === adminId) {
      throw new BadRequestException('You cannot change access for your own admin account');
    }

    const user = await this.ensureUserExists(id);

    if (user.role === UserRole.ADMIN) {
      throw new BadRequestException('Admin accounts cannot be blocked or unblocked');
    }

    const updated = await this.prisma.user.update({
      where: { id },
      data: { isActive },
      select: adminUserSelect
    });
    await this.createAudit(adminId, isActive ? 'USER_UNBLOCK' : 'USER_BLOCK', `USER:${id}`);
    return updated;
  }

  async cancelUserSubscription(id: string, adminId?: string) {
    if (id === adminId) {
      throw new BadRequestException('You cannot cancel your own admin account subscription');
    }

    const user = await this.ensureUserExists(id);

    if (user.role === UserRole.ADMIN) {
      throw new BadRequestException('Admin account subscriptions cannot be managed here');
    }

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

    await this.prisma.$transaction([
      this.prisma.userSubscription.update({
        where: { id: subscription.id },
        data: {
          status: SubscriptionStatus.CANCELLED,
          canceledAt: new Date()
        }
      }),
      this.prisma.user.update({
        where: { id },
        data: { role: UserRole.USER }
      })
    ]);
    await this.createAudit(adminId, 'SUBSCRIPTION_CANCEL', `USER:${id}`, { subscriptionId: subscription.id });

    return this.prisma.user.findUniqueOrThrow({
      where: { id },
      select: adminUserSelect
    });
  }

  async deleteUser(id: string, adminId?: string) {
    if (id === adminId) {
      throw new BadRequestException('You cannot delete your own admin account');
    }

    const user = await this.ensureUserExists(id);

    if (user.role === UserRole.ADMIN) {
      throw new BadRequestException('Admin accounts cannot be deleted');
    }

    await this.createAudit(adminId, 'USER_DELETE', `USER:${id}`, { role: user.role });
    await this.prisma.user.delete({ where: { id } });

    return { deleted: true, id };
  }

  private async enrichReports<T extends Array<{ targetType: ReportTargetType; targetId: string; subjectUser?: { displayName: string; username: string } | null }>>(
    reports: T
  ) {
    const videoIds = reports.filter((report) => report.targetType === ReportTargetType.VIDEO).map((report) => report.targetId);
    const reelIds = reports.filter((report) => report.targetType === ReportTargetType.REEL).map((report) => report.targetId);
    const commentIds = reports.filter((report) => report.targetType === ReportTargetType.COMMENT).map((report) => report.targetId);
    const liveRoomIds = reports.filter((report) => report.targetType === ReportTargetType.LIVE_ROOM).map((report) => report.targetId);

    const [videos, reels, comments, liveRooms] = await Promise.all([
      this.prisma.video.findMany({
        where: { id: { in: videoIds } },
        select: {
          id: true,
          title: true,
          mediaAsset: { select: { publicUrl: true } }
        }
      }),
      this.prisma.reel.findMany({
        where: { id: { in: reelIds } },
        select: {
          id: true,
          caption: true,
          mediaAsset: { select: { publicUrl: true } }
        }
      }),
      this.prisma.comment.findMany({
        where: { id: { in: commentIds } },
        select: {
          id: true,
          body: true
        }
      }),
      this.prisma.liveRoom.findMany({
        where: { id: { in: liveRoomIds } },
        select: {
          id: true,
          title: true
        }
      })
    ]);

    const videosById = new Map(videos.map((video) => [video.id, video]));
    const reelsById = new Map(reels.map((reel) => [reel.id, reel]));
    const commentsById = new Map(comments.map((comment) => [comment.id, comment]));
    const liveRoomsById = new Map(liveRooms.map((room) => [room.id, room]));

    return reports.map((report) => {
      if (report.targetType === ReportTargetType.VIDEO) {
        const video = videosById.get(report.targetId);
        return {
          ...report,
          targetLabel: video?.title ?? 'Video',
          targetUrl: video?.mediaAsset.publicUrl ?? null
        };
      }

      if (report.targetType === ReportTargetType.REEL) {
        const reel = reelsById.get(report.targetId);
        return {
          ...report,
          targetLabel: reel?.caption || 'Reel',
          targetUrl: reel?.mediaAsset.publicUrl ?? null
        };
      }

      if (report.targetType === ReportTargetType.COMMENT) {
        const comment = commentsById.get(report.targetId);
        return {
          ...report,
          targetLabel: comment?.body ? comment.body.slice(0, 80) : 'Comment',
          targetUrl: null
        };
      }

      if (report.targetType === ReportTargetType.LIVE_ROOM) {
        const room = liveRoomsById.get(report.targetId);
        return {
          ...report,
          targetLabel: room?.title ?? 'Live room',
          targetUrl: null
        };
      }

      return {
        ...report,
        targetLabel: report.subjectUser ? `@${report.subjectUser.username}` : 'User',
        targetUrl: null
      };
    });
  }

  private async blockReportedContent(report: { targetType: ReportTargetType; targetId: string }) {
    if (report.targetType === ReportTargetType.VIDEO) {
      await this.prisma.video.update({
        where: { id: report.targetId },
        data: { status: PublishStatus.REJECTED }
      });
      return;
    }

    if (report.targetType === ReportTargetType.REEL) {
      await this.prisma.reel.update({
        where: { id: report.targetId },
        data: { status: PublishStatus.REJECTED }
      });
      return;
    }

    if (report.targetType === ReportTargetType.COMMENT) {
      await this.prisma.comment.deleteMany({
        where: { id: report.targetId }
      });
      return;
    }

    if (report.targetType === ReportTargetType.LIVE_ROOM) {
      const room = await this.prisma.liveRoom.findUnique({
        where: { id: report.targetId },
        select: { status: true }
      });

      if (!room) {
        throw new NotFoundException('Reported live room not found');
      }

      if (room.status !== LiveRoomStatus.ENDED && room.status !== LiveRoomStatus.CANCELLED) {
        await this.prisma.liveRoom.update({
          where: { id: report.targetId },
          data: {
            status: room.status === LiveRoomStatus.LIVE ? LiveRoomStatus.ENDED : LiveRoomStatus.CANCELLED,
            endedAt: room.status === LiveRoomStatus.LIVE ? new Date() : undefined
          }
        });
      }
      return;
    }

    throw new BadRequestException('This report target cannot be blocked as content');
  }

  private async createAudit(adminId: string | undefined, action: string, target: string, metadata?: Prisma.InputJsonValue) {
    if (!adminId) {
      return;
    }

    await this.prisma.adminAuditLog.create({
      data: {
        adminId,
        action,
        target,
        metadata
      }
    });
  }

  private async ensureUserExists(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        role: true
      }
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user;
  }

  private async ensurePlanExists(id: string) {
    const plan = await this.prisma.subscriptionPlan.findUnique({
      where: { id },
      select: { id: true }
    });

    if (!plan) {
      throw new NotFoundException('Subscription plan not found');
    }
  }

  private normalizeUsername(username: string) {
    return username.trim().toLowerCase().replace(/[^a-z0-9_]/g, '');
  }

  private normalizeEditableRole(role?: UserRole) {
    if (!role) {
      return UserRole.USER;
    }

    if (role === UserRole.ADMIN) {
      throw new BadRequestException('Admin accounts cannot be created or assigned from this panel');
    }

    return role;
  }

  private cleanNullable(value?: string) {
    if (value === undefined) {
      return undefined;
    }

    const trimmed = value.trim();
    return trimmed || null;
  }

  private async ensureUniqueUser(email?: string, username?: string, currentUserId?: string) {
    if (!email && !username) {
      return;
    }

    const existing = await this.prisma.user.findFirst({
      where: {
        id: currentUserId ? { not: currentUserId } : undefined,
        OR: [
          ...(email ? [{ email }] : []),
          ...(username ? [{ username }] : [])
        ]
      },
      select: { id: true }
    });

    if (existing) {
      throw new ConflictException('Email or username already exists');
    }
  }
}
