import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ReportTargetType, UserRole } from '@prisma/client';
import { FeedService } from './feed.service';

describe('FeedService reports and moderation', () => {
  const prisma = {
    comment: {
      findFirst: jest.fn(),
      delete: jest.fn()
    },
    report: {
      create: jest.fn()
    },
    video: {
      findUnique: jest.fn()
    },
    reel: {
      findUnique: jest.fn()
    },
    adminAuditLog: {
      create: jest.fn()
    }
  };
  const service = new FeedService(prisma as never, {} as never, {} as never);
  const user = {
    id: 'viewer-1',
    email: 'viewer@example.com',
    role: UserRole.USER
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('creates comment reports against the comment author', async () => {
    prisma.comment.findFirst.mockResolvedValue({
      id: 'comment-1',
      authorId: 'author-1'
    });
    prisma.report.create.mockResolvedValue({ id: 'report-1' });

    await expect(service.reportComment('video', 'video-1', 'comment-1', ' spam ', user)).resolves.toEqual({
      id: 'report-1'
    });

    expect(prisma.report.create).toHaveBeenCalledWith({
      data: {
        reporterId: 'viewer-1',
        subjectUserId: 'author-1',
        targetType: ReportTargetType.COMMENT,
        targetId: 'comment-1',
        reason: 'spam'
      }
    });
  });

  it('rejects reports for missing comments or own comments', async () => {
    prisma.comment.findFirst.mockResolvedValue(null);
    await expect(service.reportComment('video', 'video-1', 'missing-comment', 'spam', user)).rejects.toBeInstanceOf(
      NotFoundException
    );

    prisma.comment.findFirst.mockResolvedValue({
      id: 'comment-1',
      authorId: 'viewer-1'
    });
    await expect(service.reportComment('video', 'video-1', 'comment-1', 'spam', user)).rejects.toBeInstanceOf(
      BadRequestException
    );
  });

  it('lets admins delete comments and writes no audit for non-admin users', async () => {
    prisma.comment.findFirst.mockResolvedValue({
      id: 'comment-1',
      authorId: 'author-1'
    });
    prisma.video.findUnique.mockResolvedValue({
      creatorId: 'creator-1'
    });
    prisma.comment.delete.mockResolvedValue({ id: 'comment-1' });

    await expect(
      service.deleteComment('video', 'video-1', 'comment-1', {
        id: 'admin-1',
        email: 'admin@example.com',
        role: UserRole.ADMIN
      })
    ).resolves.toEqual({
      deleted: true,
      id: 'comment-1'
    });
    expect(prisma.comment.delete).toHaveBeenCalledWith({ where: { id: 'comment-1' } });
    expect(prisma.adminAuditLog.create).not.toHaveBeenCalled();
  });
});
