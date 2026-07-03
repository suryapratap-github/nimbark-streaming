import { BadRequestException, Injectable } from '@nestjs/common';
import { StorageProvider } from '@prisma/client';
import { GetObjectCommand, HeadBucketCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { copyFile, mkdir, readFile, readdir, stat, unlink, writeFile } from 'fs/promises';
import { dirname, join, resolve } from 'path';
import { PrismaService } from '../../database/prisma.service';

export type UpdateStorageSettingsInput = {
  provider?: StorageProvider;
  localBasePath?: string;
  localPublicUrl?: string;
  videoCompressionEnabled?: boolean;
  r2Bucket?: string;
  r2Endpoint?: string;
  r2Region?: string;
  r2AccessKeyId?: string;
  r2SecretKey?: string;
  r2PublicUrl?: string;
};

@Injectable()
export class StorageService {
  constructor(private readonly prisma: PrismaService) {}

  async settings() {
    const settings = await this.ensureSettings();

    return this.publicSettings(settings);
  }

  async activeSettings() {
    return this.ensureSettings();
  }

  async health() {
    const settings = await this.ensureSettings();

    if (settings.provider === StorageProvider.LOCAL) {
      const basePath = resolve(process.cwd(), settings.localBasePath);
      await mkdir(basePath, { recursive: true });
      const localStat = await stat(basePath);

      return {
        provider: StorageProvider.LOCAL,
        healthy: localStat.isDirectory(),
        writable: true,
        publicUrl: settings.localPublicUrl,
        checkedAt: new Date()
      };
    }

    const r2Ready = Boolean(
      settings.r2Bucket && settings.r2Endpoint && settings.r2AccessKeyId && settings.r2SecretKey && settings.r2PublicUrl
    );

    if (!r2Ready) {
      return {
        provider: StorageProvider.R2,
        healthy: false,
        writable: false,
        publicUrl: settings.r2PublicUrl,
        message: 'R2 bucket, endpoint, access key, secret key, and public URL are required',
        checkedAt: new Date()
      };
    }

    try {
      await this.r2Client(settings).send(new HeadBucketCommand({ Bucket: settings.r2Bucket! }));
      return {
        provider: StorageProvider.R2,
        healthy: true,
        writable: true,
        publicUrl: settings.r2PublicUrl,
        checkedAt: new Date()
      };
    } catch (error) {
      return {
        provider: StorageProvider.R2,
        healthy: false,
        writable: false,
        publicUrl: settings.r2PublicUrl,
        message: error instanceof Error ? error.message : 'Unable to reach R2',
        checkedAt: new Date()
      };
    }
  }

  async createUpload(fileName: string, contentType: string) {
    const settings = await this.ensureSettings();
    const objectKey = `uploads/${Date.now()}-${this.safeFileName(fileName)}`;
    const publicUrl = this.publicUrl(settings, objectKey);

    if (settings.provider === StorageProvider.LOCAL) {
      return {
        provider: StorageProvider.LOCAL,
        objectKey,
        contentType,
        uploadUrl: '/api/media/local-upload',
        publicUrl,
        method: 'POST',
        fieldName: 'file'
      };
    }

    this.ensureR2Configured(settings);

    const uploadUrl = await getSignedUrl(
      this.r2Client(settings),
      new PutObjectCommand({
        Bucket: settings.r2Bucket!,
        Key: objectKey,
        ContentType: contentType
      }),
      { expiresIn: 900 }
    );

    return {
      provider: StorageProvider.R2,
      objectKey,
      contentType,
      uploadUrl,
      publicUrl,
      method: 'PUT'
    };
  }

  async saveLocalObject(file: { originalname: string; mimetype: string; size: number; buffer: Buffer }) {
    const settings = await this.ensureSettings();

    if (settings.provider !== StorageProvider.LOCAL) {
      throw new BadRequestException('Local upload is disabled because the active storage provider is not LOCAL');
    }

    const objectKey = `uploads/${Date.now()}-${this.safeFileName(file.originalname)}`;
    const targetPath = this.localPath(settings.localBasePath, objectKey);

    await mkdir(dirname(targetPath), { recursive: true });
    await writeFile(targetPath, file.buffer);

    return {
      provider: StorageProvider.LOCAL,
      objectKey,
      contentType: this.inferContentType(file.originalname, file.mimetype),
      sizeBytes: file.size,
      publicUrl: this.publicUrl(settings, objectKey)
    };
  }

  async saveProcessedLocalObject(sourcePath: string, objectKey: string, contentType: string) {
    const settings = await this.ensureSettings();

    if (settings.provider !== StorageProvider.LOCAL) {
      throw new BadRequestException('Processed local object can only be saved when LOCAL storage is active');
    }

    const targetPath = this.localPath(settings.localBasePath, objectKey);
    await mkdir(dirname(targetPath), { recursive: true });
    await writeFile(targetPath, await readFile(sourcePath));
    const outputStat = await stat(targetPath);

    return {
      objectKey,
      publicUrl: this.publicUrl(settings, objectKey),
      contentType,
      sizeBytes: outputStat.size
    };
  }

  async downloadObjectToFile(objectKey: string, targetPath: string) {
    const settings = await this.ensureSettings();

    await mkdir(dirname(targetPath), { recursive: true });

    if (settings.provider === StorageProvider.LOCAL) {
      await copyFile(this.localPath(settings.localBasePath, objectKey), targetPath);
      return targetPath;
    }

    this.ensureR2Configured(settings);
    const object = await this.r2Client(settings).send(
      new GetObjectCommand({
        Bucket: settings.r2Bucket!,
        Key: objectKey
      })
    );

    if (!object.Body) {
      throw new BadRequestException('R2 object body is empty');
    }

    const bytes = await object.Body.transformToByteArray();
    await writeFile(targetPath, Buffer.from(bytes));
    return targetPath;
  }

  async putObjectFromFile(objectKey: string, sourcePath: string, contentType: string) {
    const settings = await this.ensureSettings();

    if (settings.provider === StorageProvider.LOCAL) {
      return this.saveProcessedLocalObject(sourcePath, objectKey, contentType);
    }

    this.ensureR2Configured(settings);
    const body = await readFile(sourcePath);

    await this.r2Client(settings).send(
      new PutObjectCommand({
        Bucket: settings.r2Bucket!,
        Key: objectKey,
        Body: body,
        ContentType: contentType
      })
    );

    return {
      objectKey,
      publicUrl: this.publicUrl(settings, objectKey),
      contentType,
      sizeBytes: body.length
    };
  }

  async localFilePath(objectKey: string) {
    const settings = await this.ensureSettings();
    const targetPath = this.localPath(settings.localBasePath, objectKey);

    const fileStat = await stat(targetPath);

    if (!fileStat.isFile()) {
      throw new BadRequestException('Local media path is not a file');
    }

    return targetPath;
  }

  async cleanupOrphanedLocalMedia({ dryRun = true } = {}) {
    const settings = await this.ensureSettings();

    if (settings.provider !== StorageProvider.LOCAL) {
      return {
        provider: settings.provider,
        dryRun,
        deleted: 0,
        candidates: 0,
        message: 'Cleanup currently runs only for LOCAL storage'
      };
    }

    const basePath = resolve(process.cwd(), settings.localBasePath);
    await mkdir(basePath, { recursive: true });
    const assets = await this.prisma.mediaAsset.findMany({ select: { objectKey: true } });
    const knownKeys = new Set(assets.map((asset) => asset.objectKey));
    const files = await this.walkLocalFiles(basePath);
    const orphaned = files.filter((filePath: string) => {
      const objectKey = filePath.slice(basePath.length + 1);
      return !knownKeys.has(objectKey);
    });

    if (!dryRun) {
      await Promise.all(orphaned.map((filePath: string) => unlink(filePath)));
    }

    return {
      provider: StorageProvider.LOCAL,
      dryRun,
      candidates: orphaned.length,
      deleted: dryRun ? 0 : orphaned.length,
      checkedAt: new Date()
    };
  }

  publicUrl(settings: Awaited<ReturnType<StorageService['ensureSettings']>>, objectKey: string) {
    const baseUrl = settings.provider === StorageProvider.R2 ? settings.r2PublicUrl : settings.localPublicUrl;
    return baseUrl ? `${baseUrl.replace(/\/$/, '')}/${objectKey}` : null;
  }

  localPath(localBasePath: string, objectKey: string) {
    const basePath = resolve(process.cwd(), localBasePath);
    const targetPath = resolve(basePath, objectKey);

    if (!targetPath.startsWith(`${basePath}/`) && targetPath !== basePath) {
      throw new BadRequestException('Invalid local media path');
    }

    return targetPath;
  }

  async updateSettings(input: UpdateStorageSettingsInput) {
    const provider = input.provider;

    if (provider && !Object.values(StorageProvider).includes(provider)) {
      throw new BadRequestException('Unsupported storage provider');
    }

    const settings = await this.prisma.storageSetting.upsert({
      where: { id: 'default' },
      create: {
        id: 'default',
        provider: provider ?? StorageProvider.LOCAL,
        localBasePath: this.cleanPath(input.localBasePath) ?? 'storage/media',
        localPublicUrl: this.cleanPath(input.localPublicUrl) ?? '/api/media/local',
        videoCompressionEnabled: input.videoCompressionEnabled ?? false,
        r2Bucket: this.cleanNullable(input.r2Bucket),
        r2Endpoint: this.cleanNullable(input.r2Endpoint),
        r2Region: this.cleanNullable(input.r2Region) ?? 'auto',
        r2AccessKeyId: this.cleanNullable(input.r2AccessKeyId),
        r2SecretKey: this.cleanNullable(input.r2SecretKey),
        r2PublicUrl: this.cleanNullable(input.r2PublicUrl)
      },
      update: {
        provider,
        localBasePath: this.cleanPath(input.localBasePath),
        localPublicUrl: this.cleanPath(input.localPublicUrl),
        videoCompressionEnabled: input.videoCompressionEnabled,
        r2Bucket: this.cleanNullable(input.r2Bucket),
        r2Endpoint: this.cleanNullable(input.r2Endpoint),
        r2Region: this.cleanNullable(input.r2Region) ?? undefined,
        r2AccessKeyId: this.cleanNullable(input.r2AccessKeyId),
        r2SecretKey: input.r2SecretKey === undefined ? undefined : this.cleanNullable(input.r2SecretKey),
        r2PublicUrl: this.cleanNullable(input.r2PublicUrl)
      }
    });

    return this.publicSettings(settings);
  }

  private async ensureSettings() {
    return this.prisma.storageSetting.upsert({
      where: { id: 'default' },
      create: {
        id: 'default',
        provider: StorageProvider.LOCAL,
        localBasePath: 'storage/media',
        localPublicUrl: '/api/media/local',
        videoCompressionEnabled: false
      },
      update: {}
    });
  }

  private ensureR2Configured(settings: Awaited<ReturnType<StorageService['ensureSettings']>>) {
    if (!settings.r2Bucket || !settings.r2Endpoint || !settings.r2AccessKeyId || !settings.r2SecretKey || !settings.r2PublicUrl) {
      throw new BadRequestException('R2 storage is not configured');
    }
  }

  private r2Client(settings: Awaited<ReturnType<StorageService['ensureSettings']>>) {
    this.ensureR2Configured(settings);

    return new S3Client({
      region: settings.r2Region,
      endpoint: settings.r2Endpoint!,
      credentials: {
        accessKeyId: settings.r2AccessKeyId!,
        secretAccessKey: settings.r2SecretKey!
      },
      forcePathStyle: true
    });
  }

  private async walkLocalFiles(rootPath: string): Promise<string[]> {
    const entries = await readdir(rootPath, { withFileTypes: true });
    const files: string[][] = await Promise.all(
      entries.map(async (entry): Promise<string[]> => {
        const entryPath = join(rootPath, entry.name);
        if (entry.isDirectory()) {
          return this.walkLocalFiles(entryPath);
        }
        return entry.isFile() ? [entryPath] : [];
      })
    );

    return files.flat();
  }

  private publicSettings(settings: Awaited<ReturnType<StorageService['ensureSettings']>>) {
    return {
      id: settings.id,
      provider: settings.provider,
      localBasePath: settings.localBasePath,
      localPublicUrl: settings.localPublicUrl,
      videoCompressionEnabled: settings.videoCompressionEnabled,
      r2Bucket: settings.r2Bucket,
      r2Endpoint: settings.r2Endpoint,
      r2Region: settings.r2Region,
      r2AccessKeyId: settings.r2AccessKeyId,
      r2SecretConfigured: Boolean(settings.r2SecretKey),
      r2PublicUrl: settings.r2PublicUrl,
      updatedAt: settings.updatedAt
    };
  }

  private cleanNullable(value?: string) {
    if (value === undefined) {
      return undefined;
    }

    const trimmed = value.trim();
    return trimmed || null;
  }

  private cleanPath(value?: string) {
    if (value === undefined) {
      return undefined;
    }

    const trimmed = value.trim();
    return trimmed || undefined;
  }

  private safeFileName(fileName: string) {
    return fileName.trim().replace(/[^a-zA-Z0-9._-]+/g, '-').replace(/^-|-$/g, '') || 'upload';
  }

  private inferContentType(fileName: string, contentType: string) {
    if (contentType?.startsWith('video/') || contentType?.startsWith('image/')) {
      return contentType;
    }

    const extension = fileName.toLowerCase().split('.').pop();
    const contentTypes: Record<string, string> = {
      jpg: 'image/jpeg',
      jpeg: 'image/jpeg',
      png: 'image/png',
      webp: 'image/webp',
      mp4: 'video/mp4',
      m4v: 'video/x-m4v',
      mov: 'video/quicktime',
      webm: 'video/webm'
    };

    return extension ? contentTypes[extension] ?? contentType : contentType;
  }
}
