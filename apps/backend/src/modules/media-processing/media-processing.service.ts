import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  MediaProcessingJobStatus,
  MediaProcessingJobType,
  MediaType,
  Prisma,
  PublishStatus,
  StorageProvider
} from '@prisma/client';
import { Cron, CronExpression } from '@nestjs/schedule';
import { execFile } from 'child_process';
import { mkdir, rm, stat } from 'fs/promises';
import { tmpdir } from 'os';
import { join } from 'path';
import { promisify } from 'util';
import { PrismaService } from '../../database/prisma.service';
import { StorageService } from '../storage/storage.service';

const execFileAsync = promisify(execFile);

type ProcessingJob = Prisma.MediaProcessingJobGetPayload<{
  include: { mediaAsset: true };
}>;

@Injectable()
export class MediaProcessingService {
  private readonly logger = new Logger(MediaProcessingService.name);
  private isWorking = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly config: ConfigService
  ) {}

  async enqueueVideo(videoId: string, mediaAssetId: string) {
    return this.enqueue(MediaProcessingJobType.TRANSCODE_VIDEO, mediaAssetId, { videoId });
  }

  async enqueueReel(reelId: string, mediaAssetId: string) {
    return this.enqueue(MediaProcessingJobType.TRANSCODE_REEL, mediaAssetId, { reelId });
  }

  async enqueueLiveRecording(liveRecordingId: string, mediaAssetId: string) {
    return this.enqueue(MediaProcessingJobType.TRANSCODE_LIVE_RECORDING, mediaAssetId, { liveRecordingId });
  }

  @Cron(CronExpression.EVERY_10_SECONDS)
  async processNextQueuedJob() {
    if (this.isWorking) {
      return;
    }

    this.isWorking = true;

    try {
      const job = await this.claimNextJob();

      if (!job) {
        return;
      }

      await this.processJob(job);
    } finally {
      this.isWorking = false;
    }
  }

  private async enqueue(
    type: MediaProcessingJobType,
    mediaAssetId: string,
    target: { videoId?: string; reelId?: string; liveRecordingId?: string }
  ) {
    return this.prisma.mediaProcessingJob.create({
      data: {
        type,
        mediaAssetId,
        ...target
      }
    });
  }

  private async claimNextJob() {
    const queuedJob = await this.prisma.mediaProcessingJob.findFirst({
      where: { status: MediaProcessingJobStatus.QUEUED },
      orderBy: { createdAt: 'asc' },
      include: { mediaAsset: true }
    });

    if (!queuedJob) {
      return null;
    }

    return this.prisma.mediaProcessingJob.update({
      where: { id: queuedJob.id },
      data: {
        status: MediaProcessingJobStatus.RUNNING,
        attempts: { increment: 1 },
        startedAt: new Date(),
        errorMessage: null
      },
      include: { mediaAsset: true }
    });
  }

  private async processJob(job: ProcessingJob) {
    try {
      const result = await this.transcode(job);
      await this.finishJob(job, result.skipped ? MediaProcessingJobStatus.SKIPPED : MediaProcessingJobStatus.COMPLETED);
    } catch (error) {
      await this.failJob(job, error);
    }
  }

  private async transcode(job: ProcessingJob) {
    if (this.config.get<string>('MEDIA_TRANSCODING_ENABLED') === 'false') {
      return { skipped: true };
    }

    const settings = await this.storage.activeSettings();

    const inputObjectKey = job.mediaAsset.objectKey;
    const outputObjectKey = `processed/${job.mediaAsset.id}.mp4`;
    const workDir = join(tmpdir(), 'nimbark-media-processing');
    const inputPath =
      settings.provider === StorageProvider.LOCAL
        ? this.storage.localPath(settings.localBasePath, inputObjectKey)
        : join(workDir, `${job.id}-input`);
    const tempOutputPath = join(workDir, `${job.id}-output.mp4`);

    try {
      await mkdir(workDir, { recursive: true });
      if (settings.provider !== StorageProvider.LOCAL) {
        await this.storage.downloadObjectToFile(inputObjectKey, inputPath);
      }
      await stat(inputPath);

      const ffmpegPath = this.config.get<string>('FFMPEG_PATH') || 'ffmpeg';

      try {
        await execFileAsync(ffmpegPath, [
          '-y',
          '-i',
          inputPath,
          '-c:v',
          'libx264',
          '-preset',
          'veryfast',
          '-crf',
          '23',
          '-c:a',
          'aac',
          '-movflags',
          '+faststart',
          tempOutputPath
        ]);
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
          return { skipped: true };
        }

        throw error;
      }

      const storedObject = await this.storage.putObjectFromFile(outputObjectKey, tempOutputPath, 'video/mp4');

      await this.prisma.mediaAsset.update({
        where: { id: job.mediaAssetId },
        data: {
          objectKey: storedObject.objectKey,
          publicUrl: storedObject.publicUrl,
          contentType: storedObject.contentType,
          sizeBytes: storedObject.sizeBytes,
          type: this.mediaTypeForJob(job.type)
        }
      });

      return { skipped: false };
    } finally {
      await rm(tempOutputPath, { force: true });
      if (settings.provider !== StorageProvider.LOCAL) {
        await rm(inputPath, { force: true });
      }
    }
  }

  private async finishJob(job: ProcessingJob, status: MediaProcessingJobStatus) {
    await this.prisma.$transaction(async (tx) => {
      await tx.mediaProcessingJob.update({
        where: { id: job.id },
        data: {
          status,
          completedAt: new Date()
        }
      });

      if (job.videoId) {
        await tx.video.update({
          where: { id: job.videoId },
          data: { status: PublishStatus.PUBLISHED }
        });
      }

      if (job.reelId) {
        await tx.reel.update({
          where: { id: job.reelId },
          data: { status: PublishStatus.PUBLISHED }
        });
      }

      if (job.liveRecordingId) {
        await tx.liveRecording.update({
          where: { id: job.liveRecordingId },
          data: { status: PublishStatus.PUBLISHED }
        });
      }
    });
  }

  private async failJob(job: ProcessingJob, error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Media processing failed';
    const shouldRetry = job.attempts < job.maxAttempts;

    this.logger.warn(`Media processing job ${job.id} failed: ${errorMessage}`);

    await this.prisma.$transaction(async (tx) => {
      await tx.mediaProcessingJob.update({
        where: { id: job.id },
        data: {
          status: shouldRetry ? MediaProcessingJobStatus.QUEUED : MediaProcessingJobStatus.FAILED,
          errorMessage,
          completedAt: shouldRetry ? null : new Date()
        }
      });

      if (!shouldRetry) {
        if (job.videoId) {
          await tx.video.update({ where: { id: job.videoId }, data: { status: PublishStatus.REJECTED } });
        }

        if (job.reelId) {
          await tx.reel.update({ where: { id: job.reelId }, data: { status: PublishStatus.REJECTED } });
        }

        if (job.liveRecordingId) {
          await tx.liveRecording.update({
            where: { id: job.liveRecordingId },
            data: {
              status: PublishStatus.REJECTED,
              errorMessage
            }
          });
        }
      }
    });
  }

  private mediaTypeForJob(type: MediaProcessingJobType) {
    if (type === MediaProcessingJobType.TRANSCODE_REEL) {
      return MediaType.REEL;
    }

    if (type === MediaProcessingJobType.TRANSCODE_LIVE_RECORDING) {
      return MediaType.LIVE_RECORDING;
    }

    return MediaType.VIDEO;
  }
}
