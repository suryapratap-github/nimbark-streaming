import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LiveRoomStatus, MediaType, PublishStatus, ReportTargetType, StorageProvider, UserRole } from '@prisma/client';
import {
  AccessToken,
  EgressClient,
  EgressInfo,
  EgressStatus,
  EncodedFileOutput,
  EncodedFileType,
  RoomServiceClient,
  S3Upload,
  VideoGrant
} from 'livekit-server-sdk';
import { PrismaService } from '../../database/prisma.service';
import { AuthenticatedUser } from '../auth/types/authenticated-request';
import { MediaProcessingService } from '../media-processing/media-processing.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StorageService } from '../storage/storage.service';
import { CreateLiveRoomDto } from './dto/create-live-room.dto';

@Injectable()
export class LiveService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly storage: StorageService,
    private readonly mediaProcessing: MediaProcessingService,
    private readonly notifications: NotificationsService
  ) {}

  rooms(status?: LiveRoomStatus) {
    return this.prisma.liveRoom.findMany({
      where: status ? { status } : undefined,
      orderBy: { createdAt: 'desc' },
      include: {
        host: {
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

  async createRoom(dto: CreateLiveRoomDto, user?: AuthenticatedUser) {
    this.ensureCreator(user);

    const title = dto.title.trim();
    const existingRoom = await this.prisma.liveRoom.findFirst({
      where: {
        hostId: user!.id,
        status: { in: [LiveRoomStatus.SCHEDULED, LiveRoomStatus.LIVE] }
      },
      orderBy: { createdAt: 'desc' }
    });

    if (existingRoom) {
      if (existingRoom.status === LiveRoomStatus.LIVE) {
        return existingRoom;
      }

      return this.prisma.liveRoom.update({
        where: { id: existingRoom.id },
        data: { title }
      });
    }

    return this.prisma.liveRoom.create({
      data: {
        hostId: user!.id,
        title,
        status: LiveRoomStatus.SCHEDULED
      }
    });
  }

  async startRoom(roomId: string, user?: AuthenticatedUser) {
    const room = await this.ensureRoom(roomId);
    this.ensureRoomHostOrAdmin(room.hostId, user);

    if (room.status === LiveRoomStatus.LIVE) {
      return room;
    }

    if (room.status === LiveRoomStatus.ENDED || room.status === LiveRoomStatus.CANCELLED) {
      throw new BadRequestException('This live room cannot be restarted');
    }

    const liveRoom = await this.prisma.liveRoom.update({
      where: { id: roomId },
      data: {
        status: LiveRoomStatus.LIVE,
        startedAt: room.startedAt ?? new Date(),
        endedAt: null
      }
    });

    await this.startRecordingIfConfigured(liveRoom.id, liveRoom.title);
    await this.notifications.notifyLiveStarted({
      hostId: liveRoom.hostId,
      roomId: liveRoom.id,
      title: liveRoom.title
    });

    return this.ensureRoom(roomId);
  }

  async endRoom(roomId: string, user?: AuthenticatedUser) {
    const room = await this.ensureRoom(roomId);
    this.ensureRoomHostOrAdmin(room.hostId, user);

    if (room.status === LiveRoomStatus.ENDED) {
      return room;
    }

    const endedAt = room.endedAt ?? new Date();

    const endedRoom = await this.prisma.$transaction(async (tx) => {
      await tx.liveRoomViewerSession.updateMany({
        where: {
          roomId,
          leftAt: null
        },
        data: {
          leftAt: endedAt,
          lastSeenAt: endedAt
        }
      });

      return tx.liveRoom.update({
        where: { id: roomId },
        data: {
          status: LiveRoomStatus.ENDED,
          endedAt,
          currentViewerCount: 0
        }
      });
    });

    await this.stopActiveRecordings(roomId);

    return this.ensureRoom(endedRoom.id);
  }

  async createToken(roomId: string, user?: AuthenticatedUser) {
    if (!user) {
      throw new ForbiddenException('Login is required to join live rooms');
    }

    const room = await this.prisma.liveRoom.findUnique({
      where: { id: roomId },
      select: {
        id: true,
        hostId: true,
        title: true,
        status: true,
        startedAt: true,
        commentsOn: true,
        reactionsOn: true,
        recordingOn: true,
        host: {
          select: {
            displayName: true,
            username: true
          }
        }
      }
    });

    if (!room) {
      throw new NotFoundException('Live room not found');
    }

    const isHost = room.hostId === user.id;
    const isAdmin = user.role === UserRole.ADMIN;

    if (room.status !== LiveRoomStatus.LIVE && !isHost && !isAdmin) {
      throw new BadRequestException('This live room is not live yet');
    }

    await this.ensureNotBlocked(room, user);

    const canPublish = isHost || isAdmin;
    const wsUrl = this.config.get<string>('LIVEKIT_URL');
    const apiKey = this.config.get<string>('LIVEKIT_API_KEY');
    const apiSecret = this.config.get<string>('LIVEKIT_API_SECRET');

    if (!wsUrl || !apiKey || !apiSecret) {
      throw new BadRequestException('LiveKit is not configured on the backend');
    }

    const joiningUser = await this.prisma.user.findUnique({
      where: { id: user.id },
      select: {
        email: true,
        displayName: true,
        username: true
      }
    });

    const token = new AccessToken(apiKey, apiSecret, {
      identity: `${user.id}:${canPublish ? 'host' : 'viewer'}`,
      ttl: '1h',
      name: joiningUser?.username || joiningUser?.displayName || joiningUser?.email || user.email
    });
    const grant: VideoGrant = {
      room: this.liveKitRoomName(room.id),
      roomJoin: true,
      canPublish,
      canSubscribe: true,
      canPublishData: true
    };

    token.addGrant(grant);

    return {
      roomId,
      roomName: this.liveKitRoomName(room.id),
      title: room.title,
      hostName: room.host.displayName || room.host.username,
      hostIdentity: `${room.hostId}:host`,
      participantIdentity: `${user.id}:${canPublish ? 'host' : 'viewer'}`,
      startedAt: room.startedAt,
      commentsOn: room.commentsOn,
      reactionsOn: room.reactionsOn,
      recordingOn: room.recordingOn,
      wsUrl,
      token: await token.toJwt(),
      canPublish
    };
  }

  async blocks(roomId: string, user?: AuthenticatedUser) {
    const room = await this.ensureRoom(roomId);
    this.ensureRoomHostOrAdmin(room.hostId, user);

    return this.prisma.liveRoomBlock.findMany({
      where: { roomId },
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
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

  async participants(roomId: string, user?: AuthenticatedUser) {
    const room = await this.ensureRoom(roomId);
    this.ensureRoomHostOrAdmin(room.hostId, user);

    const roomService = this.liveKitRoomService();

    if (!roomService) {
      return [];
    }

    let participants: Awaited<ReturnType<RoomServiceClient['listParticipants']>>;

    try {
      participants = await roomService.listParticipants(this.liveKitRoomName(room.id));
    } catch (_) {
      return [];
    }

    const viewers = participants
      .map((participant) => ({
        identity: participant.identity,
        userId: participant.identity.split(':')[0]
      }))
      .filter((participant) => participant.identity.endsWith(':viewer') && participant.userId);

    const users = await this.prisma.user.findMany({
      where: { id: { in: viewers.map((viewer) => viewer.userId) } },
      select: {
        id: true,
        displayName: true,
        username: true,
        avatarUrl: true
      }
    });
    const usersById = new Map(users.map((viewer) => [viewer.id, viewer]));

    return viewers.map((viewer) => ({
      ...viewer,
      user: usersById.get(viewer.userId) ?? null
    }));
  }

  async blockViewer(roomId: string, viewerUserId: string, user?: AuthenticatedUser) {
    const room = await this.ensureRoom(roomId);
    this.ensureRoomHostOrAdmin(room.hostId, user);

    if (!viewerUserId?.trim()) {
      throw new BadRequestException('Viewer user id is required');
    }

    if (viewerUserId === room.hostId) {
      throw new BadRequestException('The host cannot be blocked from their own live room');
    }

    const viewer = await this.prisma.user.findUnique({
      where: { id: viewerUserId },
      select: {
        id: true,
        displayName: true,
        username: true,
        avatarUrl: true
      }
    });

    if (!viewer) {
      throw new NotFoundException('Viewer not found');
    }

    const block = await this.prisma.liveRoomBlock.upsert({
      where: {
        roomId_userId: {
          roomId,
          userId: viewerUserId
        }
      },
      create: {
        roomId,
        userId: viewerUserId,
        blockedBy: user!.id
      },
      update: {
        blockedBy: user!.id
      },
      include: {
        user: {
          select: {
            id: true,
            displayName: true,
            username: true,
            avatarUrl: true
          }
        }
      }
    });

    await this.recordViewerLeft(room.id, viewerUserId);
    await this.removeLiveKitParticipant(room.id, `${viewerUserId}:viewer`);
    await this.createAdminAudit(user, 'LIVE_VIEWER_BLOCK', `LIVE_ROOM:${roomId}:USER:${viewerUserId}`);

    return block;
  }

  async viewerJoined(roomId: string, user?: AuthenticatedUser) {
    if (!user) {
      throw new ForbiddenException('Login is required to join live rooms');
    }

    const room = await this.ensureRoom(roomId);
    await this.ensureNotBlocked(room, user);

    if (room.status !== LiveRoomStatus.LIVE) {
      throw new BadRequestException('This live room is not live');
    }

    if (room.hostId === user.id || user.role === UserRole.ADMIN) {
      return this.viewerAnalytics(roomId);
    }

    await this.recordViewerJoin(roomId, user.id);
    return this.viewerAnalytics(roomId);
  }

  async viewerLeft(roomId: string, user?: AuthenticatedUser) {
    if (!user) {
      throw new ForbiddenException('Login is required to leave live rooms');
    }

    const room = await this.ensureRoom(roomId);

    if (room.hostId !== user.id && user.role !== UserRole.ADMIN) {
      await this.recordViewerLeft(roomId, user.id);
    }

    return this.viewerAnalytics(roomId);
  }

  async unblockViewer(roomId: string, viewerUserId: string, user?: AuthenticatedUser) {
    const room = await this.ensureRoom(roomId);
    this.ensureRoomHostOrAdmin(room.hostId, user);

    if (!viewerUserId?.trim()) {
      throw new BadRequestException('Viewer user id is required');
    }

    await this.prisma.liveRoomBlock.deleteMany({
      where: {
        roomId,
        userId: viewerUserId
      }
    });
    await this.createAdminAudit(user, 'LIVE_VIEWER_UNBLOCK', `LIVE_ROOM:${roomId}:USER:${viewerUserId}`);

    return {
      unblocked: true,
      roomId,
      userId: viewerUserId
    };
  }

  async startRecording(roomId: string, user?: AuthenticatedUser) {
    const room = await this.ensureRoom(roomId);
    this.ensureRoomHostOrAdmin(room.hostId, user);

    if (room.status !== LiveRoomStatus.LIVE) {
      throw new BadRequestException('Recording can only start for a live room');
    }

    const recording = await this.startRecordingIfConfigured(room.id, room.title, true);

    if (!recording) {
      throw new BadRequestException('Live recording storage is not configured');
    }

    return recording;
  }

  async stopRecording(roomId: string, user?: AuthenticatedUser) {
    const room = await this.ensureRoom(roomId);
    this.ensureRoomHostOrAdmin(room.hostId, user);

    await this.stopActiveRecordings(roomId);

    return this.prisma.liveRecording.findMany({
      where: { roomId },
      orderBy: { createdAt: 'desc' }
    });
  }

  async comments(roomId: string, user?: AuthenticatedUser) {
    if (!user) {
      throw new ForbiddenException('Login is required to view live comments');
    }

    const room = await this.ensureRoom(roomId);
    await this.ensureNotBlocked(room, user);
    const canViewAll = room.hostId === user.id || user.role === UserRole.ADMIN;

    const comments = await this.prisma.liveComment.findMany({
      where: canViewAll ? { roomId } : { roomId, userId: user.id },
      orderBy: { createdAt: 'desc' },
      take: 50
    });
    const users = await this.prisma.user.findMany({
      where: { id: { in: comments.map((comment) => comment.userId) } },
      select: {
        id: true,
        displayName: true,
        username: true,
        avatarUrl: true
      }
    });
    const usersById = new Map(users.map((user) => [user.id, user]));

    return comments
      .slice()
      .reverse()
      .map((comment) => ({
        ...comment,
        author: usersById.get(comment.userId) ?? null
      }));
  }

  async createComment(roomId: string, body: string, user?: AuthenticatedUser) {
    if (!user) {
      throw new ForbiddenException('Login is required to comment');
    }

    const room = await this.ensureRoom(roomId);
    await this.ensureNotBlocked(room, user);

    if (room.status !== LiveRoomStatus.LIVE) {
      throw new BadRequestException('This live room is not live');
    }

    if (!room.commentsOn) {
      throw new BadRequestException('Comments are disabled for this live room');
    }

    const trimmedBody = body?.trim();

    if (!trimmedBody) {
      throw new BadRequestException('Comment cannot be empty');
    }

    if (trimmedBody.length > 250) {
      throw new BadRequestException('Comment must be 250 characters or less');
    }

    const [comment, author] = await Promise.all([
      this.prisma.liveComment.create({
        data: {
          roomId,
          userId: user.id,
          body: trimmedBody
        }
      }),
      this.prisma.user.findUnique({
        where: { id: user.id },
        select: {
          id: true,
          displayName: true,
          username: true,
          avatarUrl: true
        }
      })
    ]);

    return {
      ...comment,
      author
    };
  }

  async reactions(roomId: string, user?: AuthenticatedUser) {
    if (!user) {
      throw new ForbiddenException('Login is required to view live reactions');
    }

    const room = await this.ensureRoom(roomId);
    await this.ensureNotBlocked(room, user);

    if (room.hostId !== user.id && user.role !== UserRole.ADMIN) {
      return [];
    }

    const reactions = await this.prisma.liveReaction.groupBy({
      by: ['emoji'],
      where: { roomId },
      _count: { emoji: true }
    });

    return reactions.map((reaction) => ({
      emoji: reaction.emoji,
      count: reaction._count.emoji
    }));
  }

  async createReaction(roomId: string, emoji: string, user?: AuthenticatedUser) {
    if (!user) {
      throw new ForbiddenException('Login is required to react');
    }

    const room = await this.ensureRoom(roomId);
    await this.ensureNotBlocked(room, user);

    if (room.status !== LiveRoomStatus.LIVE) {
      throw new BadRequestException('This live room is not live');
    }

    if (!room.reactionsOn) {
      throw new BadRequestException('Reactions are disabled for this live room');
    }

    const allowedEmoji = new Set(['❤️', '🔥', '👏', '😂']);
    const normalizedEmoji = emoji?.trim();

    if (!allowedEmoji.has(normalizedEmoji)) {
      throw new BadRequestException('Unsupported reaction');
    }

    await this.prisma.liveReaction.create({
      data: {
        roomId,
        userId: user.id,
        emoji: normalizedEmoji
      }
    });

    return this.reactions(roomId);
  }

  async reportRoom(roomId: string, reason: string, user?: AuthenticatedUser) {
    if (!user) {
      throw new ForbiddenException('Login is required to report a live room');
    }

    const room = await this.ensureRoom(roomId);

    if (room.hostId === user.id) {
      throw new BadRequestException('You cannot report your own live room');
    }

    const trimmed = reason?.trim();

    if (!trimmed) {
      throw new BadRequestException('Report reason is required');
    }

    if (trimmed.length > 500) {
      throw new BadRequestException('Report reason must be 500 characters or less');
    }

    return this.prisma.report.create({
      data: {
        reporterId: user.id,
        subjectUserId: room.hostId,
        targetType: ReportTargetType.LIVE_ROOM,
        targetId: roomId,
        reason: trimmed
      }
    });
  }

  async settings(roomId: string) {
    const room = await this.ensureRoom(roomId);

    return {
      commentsOn: room.commentsOn,
      reactionsOn: room.reactionsOn
    };
  }

  async updateSettings(roomId: string, body: { commentsOn?: boolean; reactionsOn?: boolean }, user?: AuthenticatedUser) {
    const room = await this.ensureRoom(roomId);
    this.ensureRoomHostOrAdmin(room.hostId, user);

    return this.prisma.liveRoom.update({
      where: { id: roomId },
      data: {
        commentsOn: typeof body.commentsOn === 'boolean' ? body.commentsOn : undefined,
        reactionsOn: typeof body.reactionsOn === 'boolean' ? body.reactionsOn : undefined
      }
    });
  }

  private async ensureRoom(roomId: string) {
    const room = await this.prisma.liveRoom.findUnique({
      where: { id: roomId }
    });

    if (!room) {
      throw new NotFoundException('Live room not found');
    }

    return room;
  }

  private ensureCreator(user?: AuthenticatedUser) {
    if (!user || (user.role !== UserRole.CREATOR && user.role !== UserRole.ADMIN)) {
      throw new ForbiddenException('Creator access is required to go live');
    }
  }

  private ensureRoomHostOrAdmin(hostId: string, user?: AuthenticatedUser) {
    if (!user || (user.id !== hostId && user.role !== UserRole.ADMIN)) {
      throw new ForbiddenException('Only the host or an admin can manage this live room');
    }
  }

  private async ensureNotBlocked(room: { id: string; hostId: string }, user: AuthenticatedUser) {
    if (room.hostId === user.id || user.role === UserRole.ADMIN) {
      return;
    }

    const block = await this.prisma.liveRoomBlock.findUnique({
      where: {
        roomId_userId: {
          roomId: room.id,
          userId: user.id
        }
      }
    });

    if (block) {
      throw new ForbiddenException('You are blocked from this live room');
    }
  }

  private liveKitRoomName(roomId: string) {
    return `nimbark-${roomId}`;
  }

  private viewerAnalytics(roomId: string) {
    return this.prisma.liveRoom.findUnique({
      where: { id: roomId },
      select: {
        currentViewerCount: true,
        peakViewerCount: true,
        totalViewerJoins: true,
        uniqueViewerCount: true
      }
    });
  }

  private async recordViewerJoin(roomId: string, userId: string) {
    const now = new Date();

    await this.prisma.$transaction(async (tx) => {
      const activeSession = await tx.liveRoomViewerSession.findFirst({
        where: {
          roomId,
          userId,
          leftAt: null
        },
        select: { id: true }
      });

      if (activeSession) {
        await tx.liveRoomViewerSession.update({
          where: { id: activeSession.id },
          data: { lastSeenAt: now }
        });
        return;
      }

      const previousSession = await tx.liveRoomViewerSession.findFirst({
        where: {
          roomId,
          userId
        },
        select: { id: true }
      });

      await tx.liveRoomViewerSession.create({
        data: {
          roomId,
          userId,
          joinedAt: now,
          lastSeenAt: now
        }
      });

      const [activeViewerCount, room] = await Promise.all([
        tx.liveRoomViewerSession.count({
          where: {
            roomId,
            leftAt: null
          }
        }),
        tx.liveRoom.findUnique({
          where: { id: roomId },
          select: {
            peakViewerCount: true
          }
        })
      ]);

      await tx.liveRoom.update({
        where: { id: roomId },
        data: {
          currentViewerCount: activeViewerCount,
          peakViewerCount: Math.max(room?.peakViewerCount ?? 0, activeViewerCount),
          totalViewerJoins: { increment: 1 },
          uniqueViewerCount: previousSession ? undefined : { increment: 1 }
        }
      });
    });
  }

  private async recordViewerLeft(roomId: string, userId: string) {
    const now = new Date();

    await this.prisma.$transaction(async (tx) => {
      await tx.liveRoomViewerSession.updateMany({
        where: {
          roomId,
          userId,
          leftAt: null
        },
        data: {
          leftAt: now,
          lastSeenAt: now
        }
      });

      const activeViewerCount = await tx.liveRoomViewerSession.count({
        where: {
          roomId,
          leftAt: null
        }
      });

      await tx.liveRoom.update({
        where: { id: roomId },
        data: {
          currentViewerCount: activeViewerCount
        }
      });
    });
  }

  private async startRecordingIfConfigured(roomId: string, title: string, requireConfig = false) {
    const config = await this.liveRecordingConfig();

    if (!config) {
      if (requireConfig) {
        throw new BadRequestException('Live recording storage is not configured');
      }

      return null;
    }

    const existingRecording = await this.prisma.liveRecording.findFirst({
      where: {
        roomId,
        status: PublishStatus.PROCESSING,
        egressId: { not: null }
      },
      orderBy: { createdAt: 'desc' }
    });

    if (existingRecording) {
      return existingRecording;
    }

    const egressClient = this.liveKitEgressService();

    if (!egressClient) {
      if (requireConfig) {
        throw new BadRequestException('LiveKit egress is not configured');
      }

      return null;
    }

    const startedAt = new Date();
    const objectKey = this.liveRecordingObjectKey(roomId, title, startedAt);
    const publicUrl = this.publicRecordingUrl(objectKey, config.publicUrl);
    const recording = await this.prisma.liveRecording.create({
      data: {
        roomId,
        objectKey,
        publicUrl,
        startedAt,
        status: PublishStatus.PROCESSING
      }
    });

    try {
      const fileOutput = new EncodedFileOutput({
        fileType: EncodedFileType.MP4,
        filepath: objectKey,
        output: {
          case: 's3',
          value: new S3Upload({
            accessKey: config.accessKey,
            secret: config.secret,
            region: config.region,
            endpoint: config.endpoint,
            bucket: config.bucket,
            forcePathStyle: true
          })
        }
      });
      const egress = await egressClient.startRoomCompositeEgress(
        this.liveKitRoomName(roomId),
        { file: fileOutput },
        { layout: config.layout }
      );

      const savedRecording = await this.prisma.liveRecording.update({
        where: { id: recording.id },
        data: {
          egressId: egress.egressId,
          status: this.publishStatusFromEgress(egress),
          startedAt: this.dateFromLiveKitTimestamp(egress.startedAt) ?? startedAt,
          errorMessage: egress.error || undefined
        }
      });

      await this.prisma.liveRoom.update({
        where: { id: roomId },
        data: { recordingOn: true }
      });

      return savedRecording;
    } catch (error) {
      await this.prisma.liveRecording.update({
        where: { id: recording.id },
        data: {
          status: PublishStatus.REJECTED,
          endedAt: new Date(),
          errorMessage: error instanceof Error ? error.message : 'Unable to start LiveKit egress'
        }
      });

      if (requireConfig) {
        throw error;
      }

      return null;
    }
  }

  private async stopActiveRecordings(roomId: string) {
    const room = await this.prisma.liveRoom.findUnique({
      where: { id: roomId },
      select: { hostId: true }
    });
    const activeRecordings = await this.prisma.liveRecording.findMany({
      where: {
        roomId,
        status: PublishStatus.PROCESSING,
        egressId: { not: null }
      },
      orderBy: { createdAt: 'desc' }
    });

    if (!activeRecordings.length) {
      await this.prisma.liveRoom.update({
        where: { id: roomId },
        data: { recordingOn: false }
      });
      return;
    }

    const egressClient = this.liveKitEgressService();
    const endedAt = new Date();

    await Promise.all(
      activeRecordings.map(async (recording) => {
        if (!egressClient || !recording.egressId) {
          await this.prisma.liveRecording.update({
            where: { id: recording.id },
            data: {
              status: PublishStatus.REJECTED,
              endedAt,
              errorMessage: 'LiveKit egress is not configured'
            }
          });
          return;
        }

        try {
          const egress = await egressClient.stopEgress(recording.egressId);
          const fileResult = egress.fileResults[0];
          const objectKey = fileResult?.filename || recording.objectKey;
          const egressStatus = this.publishStatusFromEgress(egress);
          const publicUrl = objectKey ? this.publicRecordingUrl(objectKey) : recording.publicUrl;
          let mediaAssetId = recording.mediaAssetId;

          if (objectKey && room?.hostId && egressStatus === PublishStatus.PUBLISHED) {
            const mediaAsset = await this.prisma.mediaAsset.create({
              data: {
                ownerId: room.hostId,
                type: MediaType.LIVE_RECORDING,
                bucket: 'live-recordings',
                objectKey,
                publicUrl,
                contentType: 'video/mp4'
              }
            });
            mediaAssetId = mediaAsset.id;
          }

          const savedRecording = await this.prisma.liveRecording.update({
            where: { id: recording.id },
            data: {
              objectKey,
              publicUrl,
              mediaAssetId,
              status: egressStatus === PublishStatus.PUBLISHED ? PublishStatus.PROCESSING : egressStatus,
              endedAt: this.dateFromLiveKitTimestamp(egress.endedAt) ?? endedAt,
              errorMessage: egress.error || undefined
            }
          });

          if (mediaAssetId && egressStatus === PublishStatus.PUBLISHED) {
            await this.mediaProcessing.enqueueLiveRecording(savedRecording.id, mediaAssetId);
          }
        } catch (error) {
          await this.prisma.liveRecording.update({
            where: { id: recording.id },
            data: {
              status: PublishStatus.REJECTED,
              endedAt,
              errorMessage: error instanceof Error ? error.message : 'Unable to stop LiveKit egress'
            }
          });
        }
      })
    );

    await this.prisma.liveRoom.update({
      where: { id: roomId },
      data: { recordingOn: false }
    });
  }

  private async liveRecordingConfig() {
    const settings = await this.storage.activeSettings();
    const enabled = this.config.get<string>('LIVE_RECORDING_ENABLED');
    const layout = this.config.get<string>('LIVE_RECORDING_LAYOUT') || 'speaker';

    if (enabled === 'false') {
      return null;
    }

    if (settings.provider !== StorageProvider.R2) {
      return null;
    }

    const hasStorageConfig = Boolean(settings.r2Bucket && settings.r2AccessKeyId && settings.r2SecretKey && settings.r2Endpoint);

    if (!hasStorageConfig) {
      if (enabled === 'true') {
        throw new BadRequestException('Live recording is enabled but active R2 storage is not configured');
      }

      return null;
    }

    return {
      bucket: settings.r2Bucket!,
      accessKey: settings.r2AccessKeyId!,
      secret: settings.r2SecretKey!,
      endpoint: settings.r2Endpoint!,
      region: settings.r2Region,
      publicUrl: settings.r2PublicUrl,
      layout
    };
  }

  private liveRecordingObjectKey(roomId: string, title: string, startedAt: Date) {
    const safeTitle = title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)/g, '')
      .slice(0, 48) || 'live';
    const timestamp = startedAt.toISOString().replace(/[:.]/g, '-');

    return `live-recordings/${roomId}/${timestamp}-${safeTitle}.mp4`;
  }

  private publicRecordingUrl(objectKey: string, publicBaseUrl?: string | null) {
    const configuredPublicBaseUrl =
      publicBaseUrl ||
      this.config.get<string>('LIVE_RECORDING_PUBLIC_URL') ||
      this.config.get<string>('CLOUDFLARE_PUBLIC_MEDIA_URL');

    if (!configuredPublicBaseUrl) {
      return null;
    }

    return `${configuredPublicBaseUrl.replace(/\/$/, '')}/${objectKey}`;
  }

  private publishStatusFromEgress(egress: EgressInfo) {
    if (egress.status === EgressStatus.EGRESS_COMPLETE) {
      return PublishStatus.PUBLISHED;
    }

    if (
      egress.status === EgressStatus.EGRESS_FAILED ||
      egress.status === EgressStatus.EGRESS_ABORTED ||
      egress.status === EgressStatus.EGRESS_LIMIT_REACHED
    ) {
      return PublishStatus.REJECTED;
    }

    return PublishStatus.PROCESSING;
  }

  private dateFromLiveKitTimestamp(value: bigint) {
    if (!value) {
      return null;
    }

    const numericValue = Number(value);

    if (!Number.isFinite(numericValue) || numericValue <= 0) {
      return null;
    }

    return new Date(numericValue > 10_000_000_000_000 ? numericValue / 1_000_000 : numericValue);
  }

  private liveKitHttpUrl(wsUrl: string) {
    if (wsUrl.startsWith('wss://')) {
      return `https://${wsUrl.slice('wss://'.length)}`;
    }

    if (wsUrl.startsWith('ws://')) {
      return `http://${wsUrl.slice('ws://'.length)}`;
    }

    return wsUrl;
  }

  private async removeLiveKitParticipant(roomId: string, identity: string) {
    const wsUrl = this.config.get<string>('LIVEKIT_URL');
    const apiKey = this.config.get<string>('LIVEKIT_API_KEY');
    const apiSecret = this.config.get<string>('LIVEKIT_API_SECRET');

    if (!wsUrl || !apiKey || !apiSecret) {
      return;
    }

    try {
      const roomService = this.liveKitRoomService(wsUrl, apiKey, apiSecret);
      if (!roomService) {
        return;
      }

      await roomService.removeParticipant(this.liveKitRoomName(roomId), identity, {
        revokeTokenTs: BigInt(Math.floor(Date.now() / 1000))
      });
    } catch (_) {
      // The viewer may already be gone; the database block still prevents rejoining.
    }
  }

  private async createAdminAudit(user: AuthenticatedUser | undefined, action: string, target: string) {
    if (user?.role !== UserRole.ADMIN) {
      return;
    }

    await this.prisma.adminAuditLog.create({
      data: {
        adminId: user.id,
        action,
        target
      }
    });
  }

  private liveKitRoomService(wsUrl?: string, apiKey?: string, apiSecret?: string) {
    const configuredWsUrl = wsUrl ?? this.config.get<string>('LIVEKIT_URL');
    const configuredApiKey = apiKey ?? this.config.get<string>('LIVEKIT_API_KEY');
    const configuredApiSecret = apiSecret ?? this.config.get<string>('LIVEKIT_API_SECRET');

    if (!configuredWsUrl || !configuredApiKey || !configuredApiSecret) {
      return null;
    }

    return new RoomServiceClient(this.liveKitHttpUrl(configuredWsUrl), configuredApiKey, configuredApiSecret);
  }

  private liveKitEgressService() {
    const configuredWsUrl = this.config.get<string>('LIVEKIT_URL');
    const configuredApiKey = this.config.get<string>('LIVEKIT_API_KEY');
    const configuredApiSecret = this.config.get<string>('LIVEKIT_API_SECRET');

    if (!configuredWsUrl || !configuredApiKey || !configuredApiSecret) {
      return null;
    }

    return new EgressClient(this.liveKitHttpUrl(configuredWsUrl), configuredApiKey, configuredApiSecret);
  }
}
