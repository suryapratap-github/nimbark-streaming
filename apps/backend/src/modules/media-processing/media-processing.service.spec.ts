import { MediaProcessingJobStatus } from '@prisma/client';
import { MediaProcessingService } from './media-processing.service';

describe('MediaProcessingService queue recovery', () => {
  const prisma = {
    mediaProcessingJob: {
      findMany: jest.fn(),
      updateMany: jest.fn(),
      findFirst: jest.fn()
    }
  };
  const storage = {};
  const config = {
    get: jest.fn()
  };
  const service = new MediaProcessingService(prisma as never, storage as never, config as never);

  beforeEach(() => {
    jest.clearAllMocks();
    config.get.mockReturnValue(undefined);
    prisma.mediaProcessingJob.findFirst.mockResolvedValue(null);
    prisma.mediaProcessingJob.updateMany.mockResolvedValue({ count: 1 });
  });

  it('requeues stale running jobs before claiming queued work', async () => {
    prisma.mediaProcessingJob.findMany.mockResolvedValue([
      { id: 'retryable-job', attempts: 1, maxAttempts: 3 },
      { id: 'exhausted-job', attempts: 3, maxAttempts: 3 }
    ]);

    await service.processNextQueuedJob();

    expect(prisma.mediaProcessingJob.findMany).toHaveBeenCalledWith({
      where: {
        status: MediaProcessingJobStatus.RUNNING,
        startedAt: { lt: expect.any(Date) }
      },
      select: {
        id: true,
        attempts: true,
        maxAttempts: true
      }
    });
    expect(prisma.mediaProcessingJob.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['retryable-job'] } },
      data: {
        status: MediaProcessingJobStatus.QUEUED,
        startedAt: null,
        errorMessage: 'Requeued after worker shutdown or timeout'
      }
    });
    expect(prisma.mediaProcessingJob.findFirst).toHaveBeenCalledWith({
      where: { status: MediaProcessingJobStatus.QUEUED },
      orderBy: { createdAt: 'asc' },
      include: { mediaAsset: true }
    });
  });

  it('does not requeue stale jobs that have exhausted attempts', async () => {
    prisma.mediaProcessingJob.findMany.mockResolvedValue([{ id: 'exhausted-job', attempts: 3, maxAttempts: 3 }]);

    await service.processNextQueuedJob();

    expect(prisma.mediaProcessingJob.updateMany).not.toHaveBeenCalled();
    expect(prisma.mediaProcessingJob.findFirst).toHaveBeenCalled();
  });
});
