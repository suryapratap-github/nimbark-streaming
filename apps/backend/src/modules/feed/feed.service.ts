import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { MediaType, Prisma, PublishStatus, ReportTargetType, StorageProvider, UserRole } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { AuthenticatedUser } from '../auth/types/authenticated-request';
import { MediaProcessingService } from '../media-processing/media-processing.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StorageService } from '../storage/storage.service';

type FeedType = 'video' | 'reel';

type PublishVideoInput = {
  title: string;
  description?: string;
  objectKey: string;
  provider?: string;
  publicUrl?: string;
  contentType: string;
  sizeBytes?: number;
  durationMs?: number;
  commentsEnabled?: boolean;
  thumbnail?: PublishMediaInput;
};

type PublishReelInput = {
  caption?: string;
  objectKey: string;
  provider?: string;
  publicUrl?: string;
  contentType: string;
  sizeBytes?: number;
  durationMs?: number;
  commentsEnabled?: boolean;
  thumbnail?: PublishMediaInput;
};

type PublishMediaInput = {
  objectKey: string;
  provider?: string;
  publicUrl?: string;
  contentType: string;
  sizeBytes?: number;
};

const MAX_REEL_DURATION_MS = 30_000;

@Injectable()
export class FeedService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly mediaProcessing: MediaProcessingService,
    private readonly notifications: NotificationsService,
    private readonly storage?: StorageService
  ) {}

  async videos() {
    const videos = await this.prisma.video.findMany({
      where: { status: PublishStatus.PUBLISHED },
      orderBy: { createdAt: 'desc' },
      take: 20,
      include: this.feedInclude()
    });

    return this.normalizeFeedItems(videos);
  }

  async reels() {
    const reels = await this.prisma.reel.findMany({
      where: { status: PublishStatus.PUBLISHED },
      orderBy: { createdAt: 'desc' },
      take: 20,
      include: this.feedInclude()
    });

    return this.normalizeFeedItems(reels);
  }

  async publishVideo(input: PublishVideoInput, user?: AuthenticatedUser) {
    this.ensureCreator(user);
    this.ensureVideoContent(input.contentType, input.objectKey);

    const title = input.title.trim();

    if (!title) {
      throw new BadRequestException('Title is required');
    }

    const mediaAsset = await this.prisma.mediaAsset.create({
      data: {
        ownerId: user!.id,
        type: MediaType.VIDEO,
        bucket: this.mediaBucket(input.provider),
        objectKey: input.objectKey,
        publicUrl: input.publicUrl,
        contentType: input.contentType,
        sizeBytes: input.sizeBytes,
        durationMs: input.durationMs
      }
    });
    const thumbnail = await this.createThumbnailAsset(input.thumbnail, user!.id);

    const video = await this.prisma.video.create({
      data: {
        creatorId: user!.id,
        mediaAssetId: mediaAsset.id,
        thumbnailId: thumbnail?.id,
        title,
        description: input.description?.trim(),
        commentsEnabled: input.commentsEnabled ?? true,
        status: PublishStatus.PROCESSING
      },
      include: this.feedInclude()
    });

    await this.mediaProcessing.enqueueVideo(video.id, mediaAsset.id);

    return this.normalizeFeedItem(video);
  }

  async publishReel(input: PublishReelInput, user?: AuthenticatedUser) {
    this.ensureCreator(user);
    this.ensureVideoContent(input.contentType, input.objectKey);
    this.ensureReelDuration(input.durationMs);

    const mediaAsset = await this.prisma.mediaAsset.create({
      data: {
        ownerId: user!.id,
        type: MediaType.REEL,
        bucket: this.mediaBucket(input.provider),
        objectKey: input.objectKey,
        publicUrl: input.publicUrl,
        contentType: input.contentType,
        sizeBytes: input.sizeBytes,
        durationMs: input.durationMs
      }
    });
    const thumbnail = await this.createThumbnailAsset(input.thumbnail, user!.id);

    const reel = await this.prisma.reel.create({
      data: {
        creatorId: user!.id,
        mediaAssetId: mediaAsset.id,
        thumbnailId: thumbnail?.id,
        caption: input.caption?.trim(),
        commentsEnabled: input.commentsEnabled ?? true,
        status: PublishStatus.PROCESSING
      },
      include: this.feedInclude()
    });

    await this.mediaProcessing.enqueueReel(reel.id, mediaAsset.id);

    return this.normalizeFeedItem(reel);
  }

  async search(query: string) {
    const term = query.trim();

    if (term.length < 2) {
      return {
        creators: [],
        videos: [],
        reels: []
      };
    }

    const contains = {
      contains: term,
      mode: Prisma.QueryMode.insensitive
    };

    const [creators, videos, reels] = await Promise.all([
      this.prisma.user.findMany({
        where: {
          role: UserRole.CREATOR,
          isActive: true,
          OR: [
            { username: contains },
            { displayName: contains },
            { bio: contains }
          ]
        },
        orderBy: { createdAt: 'desc' },
        take: 12,
        select: this.creatorSelect()
      }),
      this.prisma.video.findMany({
        where: {
          status: PublishStatus.PUBLISHED,
          OR: [
            { title: contains },
            { description: contains },
            { creator: { username: contains } },
            { creator: { displayName: contains } }
          ]
        },
        orderBy: { createdAt: 'desc' },
        take: 12,
        include: this.feedInclude()
      }),
      this.prisma.reel.findMany({
        where: {
          status: PublishStatus.PUBLISHED,
          OR: [
            { caption: contains },
            { creator: { username: contains } },
            { creator: { displayName: contains } }
          ]
        },
        orderBy: { createdAt: 'desc' },
        take: 12,
        include: this.feedInclude()
      })
    ]);

    return {
      creators,
      videos: await this.normalizeFeedItems(videos),
      reels: await this.normalizeFeedItems(reels)
    };
  }

  async creatorProfile(id: string) {
    const creator = await this.prisma.user.findFirst({
      where: {
        id,
        role: UserRole.CREATOR,
        isActive: true
      },
      select: this.creatorSelect()
    });

    if (!creator) {
      throw new NotFoundException('Creator not found');
    }

    const [videos, reels] = await Promise.all([
      this.prisma.video.findMany({
        where: {
          creatorId: id,
          status: PublishStatus.PUBLISHED
        },
        orderBy: { createdAt: 'desc' },
        include: this.feedInclude()
      }),
      this.prisma.reel.findMany({
        where: {
          creatorId: id,
          status: PublishStatus.PUBLISHED
        },
        orderBy: { createdAt: 'desc' },
        include: this.feedInclude()
      })
    ]);

    return {
      creator,
      videos: await this.normalizeFeedItems(videos),
      reels: await this.normalizeFeedItems(reels)
    };
  }

  async item(type: FeedType, id: string) {
    const item = type === 'video'
      ? await this.prisma.video.findFirst({
        where: {
          id,
          status: PublishStatus.PUBLISHED
        },
        include: this.feedInclude()
      })
      : await this.prisma.reel.findFirst({
        where: {
          id,
          status: PublishStatus.PUBLISHED
        },
        include: this.feedInclude()
      });

    if (!item) {
      throw new NotFoundException('Post is not available');
    }

    return this.normalizeFeedItem(item);
  }

  async processingStatus(type: FeedType, id: string, user?: AuthenticatedUser) {
    this.ensureAuthenticated(user);

    const post = type === 'video'
      ? await this.prisma.video.findUnique({
          where: { id },
          select: {
            id: true,
            creatorId: true,
            status: true,
            processingJobs: {
              orderBy: { createdAt: 'desc' },
              take: 1,
              select: {
                status: true,
                errorMessage: true,
                attempts: true,
                maxAttempts: true,
                updatedAt: true
              }
            }
          }
        })
      : await this.prisma.reel.findUnique({
          where: { id },
          select: {
            id: true,
            creatorId: true,
            status: true,
            processingJobs: {
              orderBy: { createdAt: 'desc' },
              take: 1,
              select: {
                status: true,
                errorMessage: true,
                attempts: true,
                maxAttempts: true,
                updatedAt: true
              }
            }
          }
        });

    if (!post) {
      throw new NotFoundException('Post is not available');
    }

    const isOwner = post.creatorId === user!.id;
    const isAdmin = user!.role === UserRole.ADMIN;

    if (!isOwner && !isAdmin) {
      throw new ForbiddenException('You can only check your own upload status');
    }

    const job = post.processingJobs[0] ?? null;

    return {
      id: post.id,
      type,
      status: post.status,
      processingStatus: job?.status ?? null,
      errorMessage: job?.errorMessage ?? null,
      attempts: job?.attempts ?? 0,
      maxAttempts: job?.maxAttempts ?? 0,
      updatedAt: job?.updatedAt ?? null
    };
  }

  async incrementView(type: FeedType, id: string, user?: AuthenticatedUser) {
    this.ensureAuthenticated(user);
    await this.ensurePublishedItem(type, id);

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const viewWhere = {
      userId: user!.id,
      createdAt: { gte: since },
      ...this.itemWhere(type, id)
    };
    const existing = await this.prisma.feedView.findFirst({
      where: viewWhere,
      select: { id: true }
    });

    if (existing) {
      const item = type === 'video'
        ? await this.prisma.video.findUnique({ where: { id }, select: { viewCount: true } })
        : await this.prisma.reel.findUnique({ where: { id }, select: { viewCount: true } });

      return {
        counted: false,
        viewCount: item?.viewCount ?? 0
      };
    }

    const createView = this.prisma.feedView.create({
      data: {
        userId: user!.id,
        ...this.itemWhere(type, id)
      }
    });

    if (type === 'video') {
      const [, item] = await this.prisma.$transaction([
        createView,
        this.prisma.video.update({
          where: { id },
          data: { viewCount: { increment: 1 } },
          select: { viewCount: true }
        })
      ]);

      return {
        counted: true,
        viewCount: item.viewCount
      };
    }

    const [, item] = await this.prisma.$transaction([
      createView,
      this.prisma.reel.update({
        where: { id },
        data: { viewCount: { increment: 1 } },
        select: { viewCount: true }
      })
    ]);

    return {
      counted: true,
      viewCount: item.viewCount
    };
  }

  async toggleLike(type: FeedType, id: string, user?: AuthenticatedUser) {
    this.ensureAuthenticated(user);
    await this.ensurePublishedItem(type, id);
    const existing = await this.findLike(type, id, user!.id);

    if (existing) {
      await this.prisma.like.delete({ where: { id: existing.id } });
      return { liked: false };
    }

    await this.prisma.$transaction([
      this.prisma.dislike.deleteMany({ where: this.userItemWhere(type, id, user!.id) }),
      this.prisma.like.create({ data: this.userItemData(type, id, user!.id) })
    ]);

    return { liked: true };
  }

  async toggleDislike(type: FeedType, id: string, user?: AuthenticatedUser) {
    this.ensureAuthenticated(user);
    await this.ensurePublishedItem(type, id);
    const existing = await this.findDislike(type, id, user!.id);

    if (existing) {
      await this.prisma.dislike.delete({ where: { id: existing.id } });
      return { disliked: false };
    }

    await this.prisma.$transaction([
      this.prisma.like.deleteMany({ where: this.userItemWhere(type, id, user!.id) }),
      this.prisma.dislike.create({ data: this.userItemData(type, id, user!.id) })
    ]);

    return { disliked: true };
  }

  async share(type: FeedType, id: string, user?: AuthenticatedUser) {
    this.ensureAuthenticated(user);
    await this.ensurePublishedItem(type, id);
    await this.prisma.share.create({ data: this.userItemData(type, id, user!.id) });
    return { shared: true };
  }

  comments(type: FeedType, id: string) {
    return this.prisma.comment.findMany({
      where: this.itemWhere(type, id),
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
            username: true,
            avatarUrl: true
          }
        }
      }
    });
  }

  async createComment(type: FeedType, id: string, body: string, user?: AuthenticatedUser) {
    this.ensureAuthenticated(user);
    const item = await this.ensurePublishedItem(type, id);

    if (!item.commentsEnabled) {
      throw new BadRequestException('Comments are disabled for this post');
    }

    const trimmed = body.trim();

    if (!trimmed) {
      throw new BadRequestException('Comment cannot be empty');
    }

    if (trimmed.length > 250) {
      throw new BadRequestException('Comment must be 250 characters or less');
    }

    const comment = await this.prisma.comment.create({
      data: {
        authorId: user!.id,
        body: trimmed,
        ...this.itemWhere(type, id)
      },
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
            username: true,
            avatarUrl: true
          }
        }
      }
    });

    if (type === 'video') {
      const target = await this.prisma.video.findUnique({ where: { id }, select: { creatorId: true, title: true } });

      if (target) {
        await this.notifications.notifyPostComment({
          creatorId: target.creatorId,
          commenterId: user!.id,
          postId: id,
          postType: type,
          postTitle: target.title
        });
      }
    } else {
      const target = await this.prisma.reel.findUnique({ where: { id }, select: { creatorId: true, caption: true } });

      if (target) {
        await this.notifications.notifyPostComment({
          creatorId: target.creatorId,
          commenterId: user!.id,
          postId: id,
          postType: type,
          postTitle: target.caption || 'your reel'
        });
      }
    }

    return comment;
  }

  async deleteComment(type: FeedType, id: string, commentId: string, user?: AuthenticatedUser) {
    this.ensureAuthenticated(user);

    const comment = await this.prisma.comment.findFirst({
      where: {
        id: commentId,
        ...this.itemWhere(type, id)
      },
      select: {
        id: true,
        authorId: true
      }
    });

    if (!comment) {
      throw new NotFoundException('Comment not found');
    }

    const item = type === 'video'
      ? await this.prisma.video.findUnique({ where: { id }, select: { creatorId: true } })
      : await this.prisma.reel.findUnique({ where: { id }, select: { creatorId: true } });

    if (!item) {
      throw new NotFoundException('Post is not available');
    }

    const isAdmin = user!.role === UserRole.ADMIN;
    const isPostCreator = item.creatorId === user!.id;
    const isCommentAuthor = comment.authorId === user!.id;

    if (!isAdmin && !isPostCreator && !isCommentAuthor) {
      throw new ForbiddenException('You cannot delete this comment');
    }

    await this.prisma.comment.delete({ where: { id: comment.id } });

    return { deleted: true, id: comment.id };
  }

  async report(type: FeedType, id: string, reason: string, user?: AuthenticatedUser) {
    this.ensureAuthenticated(user);

    const trimmed = this.normalizeReportReason(reason);

    const target = type === 'video'
      ? await this.prisma.video.findUnique({ where: { id }, select: { id: true, creatorId: true } })
      : await this.prisma.reel.findUnique({ where: { id }, select: { id: true, creatorId: true } });

    if (!target) {
      throw new NotFoundException('Post is not available');
    }

    return this.prisma.report.create({
      data: {
        reporterId: user!.id,
        subjectUserId: target.creatorId,
        targetType: type === 'video' ? ReportTargetType.VIDEO : ReportTargetType.REEL,
        targetId: id,
        reason: trimmed
      }
    });
  }

  async reportComment(type: FeedType, id: string, commentId: string, reason: string, user?: AuthenticatedUser) {
    this.ensureAuthenticated(user);

    const trimmed = this.normalizeReportReason(reason);
    const comment = await this.prisma.comment.findFirst({
      where: {
        id: commentId,
        ...this.itemWhere(type, id)
      },
      select: {
        id: true,
        authorId: true
      }
    });

    if (!comment) {
      throw new NotFoundException('Comment not found');
    }

    if (comment.authorId === user!.id) {
      throw new BadRequestException('You cannot report your own comment');
    }

    return this.prisma.report.create({
      data: {
        reporterId: user!.id,
        subjectUserId: comment.authorId,
        targetType: ReportTargetType.COMMENT,
        targetId: comment.id,
        reason: trimmed
      }
    });
  }

  async deletePost(type: FeedType, id: string, user?: AuthenticatedUser) {
    this.ensureAuthenticated(user);

    const item = type === 'video'
      ? await this.prisma.video.findUnique({ where: { id }, select: { id: true, creatorId: true } })
      : await this.prisma.reel.findUnique({ where: { id }, select: { id: true, creatorId: true } });

    if (!item) {
      throw new NotFoundException('Post is not available');
    }

    const isAdmin = user!.role === UserRole.ADMIN;
    const isOwnerCreator = user!.role === UserRole.CREATOR && item.creatorId === user!.id;

    if (!isAdmin && !isOwnerCreator) {
      throw new ForbiddenException('You can only delete your own posts');
    }

    if (type === 'video') {
      const updated = await this.prisma.video.update({
        where: { id },
        data: { status: PublishStatus.DELETED },
        include: this.feedInclude()
      });
      await this.createAdminAudit(user, 'FEED_DELETE', `VIDEO:${id}`, { creatorId: item.creatorId });
      return updated;
    }

    const updated = await this.prisma.reel.update({
      where: { id },
      data: { status: PublishStatus.DELETED },
      include: this.feedInclude()
    });
    await this.createAdminAudit(user, 'FEED_DELETE', `REEL:${id}`, { creatorId: item.creatorId });
    return updated;
  }

  private feedInclude() {
    return {
      creator: {
        select: this.creatorSelect()
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
  }

  private async normalizeFeedItems<T extends { mediaAsset: { publicUrl: string | null; objectKey: string }; thumbnail?: { publicUrl: string | null; objectKey: string } | null }>(
    items: T[]
  ) {
    return Promise.all(items.map((item) => this.normalizeFeedItem(item)));
  }

  private async normalizeFeedItem<T extends { mediaAsset: { publicUrl: string | null; objectKey: string }; thumbnail?: { publicUrl: string | null; objectKey: string } | null }>(
    item: T
  ) {
    if (!this.storage) {
      return item;
    }

    const settings = await this.storage.activeSettings();
    const mediaAsset = {
      ...item.mediaAsset,
      publicUrl: this.feedPublicUrl(settings, item.mediaAsset.publicUrl, item.mediaAsset.objectKey)
    };
    const thumbnail = item.thumbnail
      ? {
          ...item.thumbnail,
          publicUrl: this.feedPublicUrl(settings, item.thumbnail.publicUrl, item.thumbnail.objectKey)
        }
      : item.thumbnail;

    return {
      ...item,
      mediaAsset,
      thumbnail
    };
  }

  private feedPublicUrl(
    settings: Awaited<ReturnType<StorageService['activeSettings']>>,
    currentUrl: string | null,
    objectKey: string
  ) {
    if (settings.provider === StorageProvider.R2 && this.isLocalMediaUrl(currentUrl)) {
      return this.storage?.publicUrl(settings, objectKey) ?? currentUrl;
    }

    return currentUrl ?? this.storage?.publicUrl(settings, objectKey) ?? null;
  }

  private isLocalMediaUrl(url: string | null) {
    if (!url) {
      return true;
    }

    try {
      return new URL(url).pathname.startsWith('/api/media/local/');
    } catch {
      return url.startsWith('/api/media/local/');
    }
  }

  private async createThumbnailAsset(input: PublishMediaInput | undefined, ownerId: string) {
    if (!input) {
      return null;
    }

    const contentType = input.contentType.trim();

    if (!contentType.startsWith('image/')) {
      throw new BadRequestException('Thumbnail must be an image file');
    }

    return this.prisma.mediaAsset.create({
      data: {
        ownerId,
        type: MediaType.THUMBNAIL,
        bucket: this.mediaBucket(input.provider),
        objectKey: input.objectKey,
        publicUrl: input.publicUrl,
        contentType,
        sizeBytes: input.sizeBytes
      }
    });
  }

  private creatorSelect() {
    return {
      id: true,
      displayName: true,
      username: true,
      avatarUrl: true,
      bio: true,
      _count: {
        select: {
          followers: true,
          videos: true,
          reels: true,
          creatorLikesReceived: true,
          creatorSharesReceived: true
        }
      }
    };
  }

  private mediaBucket(provider?: string) {
    return provider?.toUpperCase() === 'R2' ? 'r2' : 'local';
  }

  private ensureCreator(user?: AuthenticatedUser) {
    if (!user || (user.role !== UserRole.CREATOR && user.role !== UserRole.ADMIN)) {
      throw new ForbiddenException('Creator access is required to publish');
    }
  }

  private ensureAuthenticated(user?: AuthenticatedUser) {
    if (!user) {
      throw new ForbiddenException('Login is required');
    }
  }

  private ensureVideoContent(contentType: string, objectKey: string) {
    const extension = objectKey.toLowerCase().split('.').pop();
    const knownVideoExtension = extension ? ['mp4', 'm4v', 'mov', 'webm'].includes(extension) : false;

    if (!contentType?.startsWith('video/') && !knownVideoExtension) {
      throw new BadRequestException('Only video files are supported');
    }
  }

  private ensureReelDuration(durationMs?: number) {
    if (!Number.isFinite(durationMs)) {
      throw new BadRequestException('Video duration is required for reels');
    }

    if (durationMs! > MAX_REEL_DURATION_MS) {
      throw new BadRequestException('Reels must be 30 seconds or shorter');
    }
  }

  private normalizeReportReason(reason: string) {
    const trimmed = reason?.trim();

    if (!trimmed) {
      throw new BadRequestException('Report reason is required');
    }

    if (trimmed.length > 500) {
      throw new BadRequestException('Report reason must be 500 characters or less');
    }

    return trimmed;
  }

  private async createAdminAudit(user: AuthenticatedUser | undefined, action: string, target: string, metadata?: Prisma.InputJsonValue) {
    if (user?.role !== UserRole.ADMIN) {
      return;
    }

    await this.prisma.adminAuditLog.create({
      data: {
        adminId: user.id,
        action,
        target,
        metadata
      }
    });
  }

  private async ensurePublishedItem(type: FeedType, id: string) {
    const item = type === 'video'
      ? await this.prisma.video.findFirst({ where: { id, status: PublishStatus.PUBLISHED }, select: { id: true, commentsEnabled: true } })
      : await this.prisma.reel.findFirst({ where: { id, status: PublishStatus.PUBLISHED }, select: { id: true, commentsEnabled: true } });

    if (!item) {
      throw new NotFoundException('Post is not available');
    }

    return item;
  }

  private findLike(type: FeedType, id: string, userId: string) {
    return this.prisma.like.findFirst({ where: this.userItemWhere(type, id, userId), select: { id: true } });
  }

  private findDislike(type: FeedType, id: string, userId: string) {
    return this.prisma.dislike.findFirst({ where: this.userItemWhere(type, id, userId), select: { id: true } });
  }

  private itemWhere(type: FeedType, id: string) {
    return type === 'video' ? { videoId: id } : { reelId: id };
  }

  private userItemWhere(type: FeedType, id: string, userId: string) {
    return {
      userId,
      ...this.itemWhere(type, id)
    };
  }

  private userItemData(type: FeedType, id: string, userId: string) {
    return this.userItemWhere(type, id, userId);
  }
}
