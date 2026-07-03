import { BadRequestException } from '@nestjs/common';
import { PublishStatus, ReportStatus, ReportTargetType, UserRole } from '@prisma/client';
import { AdminService } from './admin.service';

describe('AdminService report moderation', () => {
  const prisma = {
    report: {
      findUnique: jest.fn(),
      update: jest.fn()
    },
    user: {
      update: jest.fn()
    },
    video: {
      update: jest.fn()
    },
    reel: {
      update: jest.fn()
    },
    comment: {
      deleteMany: jest.fn()
    },
    liveRoom: {
      findUnique: jest.fn(),
      update: jest.fn()
    },
    adminAuditLog: {
      create: jest.fn()
    }
  };
  const service = new AdminService(prisma as never, {} as never);

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.report.update.mockImplementation(({ data }) =>
      Promise.resolve({
        id: 'report-1',
        status: data.status
      })
    );
  });

  it('blocks reported users and resolves the report with audit logs', async () => {
    prisma.report.findUnique.mockResolvedValue({
      id: 'report-1',
      subjectUserId: 'bad-user',
      targetType: ReportTargetType.USER,
      targetId: 'bad-user',
      subjectUser: {
        id: 'bad-user',
        role: UserRole.USER
      }
    });
    prisma.user.update.mockResolvedValue({ id: 'bad-user', isActive: false });

    await expect(service.actionReport('report-1', 'BLOCK_USER', 'admin-1')).resolves.toMatchObject({
      id: 'report-1',
      status: ReportStatus.RESOLVED
    });

    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'bad-user' },
      data: { isActive: false }
    });
    expect(prisma.adminAuditLog.create).toHaveBeenCalledWith({
      data: {
        adminId: 'admin-1',
        action: 'REPORT_BLOCK_USER',
        target: 'USER:bad-user',
        metadata: { reportId: 'report-1' }
      }
    });
    expect(prisma.report.update).toHaveBeenCalledWith(expect.objectContaining({ data: { status: ReportStatus.RESOLVED } }));
  });

  it('blocks reported feed content and resolves the report', async () => {
    prisma.report.findUnique.mockResolvedValue({
      id: 'report-1',
      subjectUserId: 'creator-1',
      targetType: ReportTargetType.VIDEO,
      targetId: 'video-1',
      subjectUser: {
        id: 'creator-1',
        role: UserRole.CREATOR
      }
    });
    prisma.video.update.mockResolvedValue({ id: 'video-1', status: PublishStatus.REJECTED });

    await service.actionReport('report-1', 'BLOCK_CONTENT', 'admin-1');

    expect(prisma.video.update).toHaveBeenCalledWith({
      where: { id: 'video-1' },
      data: { status: PublishStatus.REJECTED }
    });
    expect(prisma.adminAuditLog.create).toHaveBeenCalledWith({
      data: {
        adminId: 'admin-1',
        action: 'REPORT_BLOCK_CONTENT',
        target: 'VIDEO:video-1',
        metadata: { reportId: 'report-1' }
      }
    });
  });

  it('does not block admin accounts from reports', async () => {
    prisma.report.findUnique.mockResolvedValue({
      id: 'report-1',
      subjectUserId: 'admin-2',
      targetType: ReportTargetType.USER,
      targetId: 'admin-2',
      subjectUser: {
        id: 'admin-2',
        role: UserRole.ADMIN
      }
    });

    await expect(service.actionReport('report-1', 'BLOCK_USER', 'admin-1')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.user.update).not.toHaveBeenCalled();
  });
});
