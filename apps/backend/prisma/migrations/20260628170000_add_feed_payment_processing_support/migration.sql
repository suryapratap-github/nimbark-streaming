-- CreateEnum
CREATE TYPE "PaymentProvider" AS ENUM ('REVENUECAT');

-- CreateEnum
CREATE TYPE "MediaProcessingJobType" AS ENUM ('TRANSCODE_VIDEO', 'TRANSCODE_REEL', 'TRANSCODE_LIVE_RECORDING');

-- CreateEnum
CREATE TYPE "MediaProcessingJobStatus" AS ENUM ('QUEUED', 'RUNNING', 'COMPLETED', 'SKIPPED', 'FAILED');

-- AlterTable
ALTER TABLE "LiveRecording" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "Reel" ADD COLUMN "commentsEnabled" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "StorageSetting" ADD COLUMN "videoCompressionEnabled" BOOLEAN NOT NULL DEFAULT false,
ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "SubscriptionPlan" ADD COLUMN "revenueCatEntitlementId" TEXT,
ADD COLUMN "revenueCatOfferingId" TEXT,
ADD COLUMN "revenueCatPackageId" TEXT;

-- AlterTable
ALTER TABLE "UserSubscription" ADD COLUMN "externalProductId" TEXT,
ADD COLUMN "externalSubscriptionId" TEXT,
ADD COLUMN "latestEventAt" TIMESTAMP(3),
ADD COLUMN "provider" "PaymentProvider" NOT NULL DEFAULT 'REVENUECAT',
ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "UserSubscription" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "Video" ADD COLUMN "commentsEnabled" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable
CREATE TABLE "PushDeviceToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "platform" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PushDeviceToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MediaProcessingJob" (
    "id" TEXT NOT NULL,
    "type" "MediaProcessingJobType" NOT NULL,
    "status" "MediaProcessingJobStatus" NOT NULL DEFAULT 'QUEUED',
    "mediaAssetId" TEXT NOT NULL,
    "videoId" TEXT,
    "reelId" TEXT,
    "liveRecordingId" TEXT,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "maxAttempts" INTEGER NOT NULL DEFAULT 3,
    "errorMessage" TEXT,
    "startedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MediaProcessingJob_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeedView" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "videoId" TEXT,
    "reelId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FeedView_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CreatorLike" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "creatorId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CreatorLike_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Dislike" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "videoId" TEXT,
    "reelId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Dislike_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Share" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "videoId" TEXT,
    "reelId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Share_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CreatorShare" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "creatorId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CreatorShare_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PaymentEvent" (
    "id" TEXT NOT NULL,
    "provider" "PaymentProvider" NOT NULL,
    "eventId" TEXT NOT NULL,
    "eventType" TEXT NOT NULL,
    "userId" TEXT,
    "subscriptionId" TEXT,
    "payload" JSONB NOT NULL,
    "processedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PaymentEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "PushDeviceToken_token_key" ON "PushDeviceToken"("token");
CREATE INDEX "PushDeviceToken_userId_idx" ON "PushDeviceToken"("userId");
CREATE INDEX "PushDeviceToken_updatedAt_idx" ON "PushDeviceToken"("updatedAt");
CREATE INDEX "MediaProcessingJob_status_createdAt_idx" ON "MediaProcessingJob"("status", "createdAt");
CREATE INDEX "MediaProcessingJob_mediaAssetId_idx" ON "MediaProcessingJob"("mediaAssetId");
CREATE INDEX "MediaProcessingJob_videoId_idx" ON "MediaProcessingJob"("videoId");
CREATE INDEX "MediaProcessingJob_reelId_idx" ON "MediaProcessingJob"("reelId");
CREATE INDEX "MediaProcessingJob_liveRecordingId_idx" ON "MediaProcessingJob"("liveRecordingId");
CREATE INDEX "FeedView_userId_videoId_createdAt_idx" ON "FeedView"("userId", "videoId", "createdAt");
CREATE INDEX "FeedView_userId_reelId_createdAt_idx" ON "FeedView"("userId", "reelId", "createdAt");
CREATE INDEX "FeedView_videoId_createdAt_idx" ON "FeedView"("videoId", "createdAt");
CREATE INDEX "FeedView_reelId_createdAt_idx" ON "FeedView"("reelId", "createdAt");
CREATE INDEX "CreatorLike_creatorId_idx" ON "CreatorLike"("creatorId");
CREATE UNIQUE INDEX "CreatorLike_userId_creatorId_key" ON "CreatorLike"("userId", "creatorId");
CREATE UNIQUE INDEX "Dislike_userId_videoId_key" ON "Dislike"("userId", "videoId");
CREATE UNIQUE INDEX "Dislike_userId_reelId_key" ON "Dislike"("userId", "reelId");
CREATE INDEX "Share_videoId_idx" ON "Share"("videoId");
CREATE INDEX "Share_reelId_idx" ON "Share"("reelId");
CREATE INDEX "Share_userId_idx" ON "Share"("userId");
CREATE INDEX "CreatorShare_creatorId_idx" ON "CreatorShare"("creatorId");
CREATE INDEX "CreatorShare_userId_idx" ON "CreatorShare"("userId");
CREATE INDEX "PaymentEvent_provider_eventType_createdAt_idx" ON "PaymentEvent"("provider", "eventType", "createdAt");
CREATE INDEX "PaymentEvent_userId_createdAt_idx" ON "PaymentEvent"("userId", "createdAt");
CREATE UNIQUE INDEX "PaymentEvent_provider_eventId_key" ON "PaymentEvent"("provider", "eventId");
CREATE INDEX "UserSubscription_provider_externalSubscriptionId_idx" ON "UserSubscription"("provider", "externalSubscriptionId");

-- AddForeignKey
ALTER TABLE "PushDeviceToken" ADD CONSTRAINT "PushDeviceToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "MediaProcessingJob" ADD CONSTRAINT "MediaProcessingJob_mediaAssetId_fkey" FOREIGN KEY ("mediaAssetId") REFERENCES "MediaAsset"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "MediaProcessingJob" ADD CONSTRAINT "MediaProcessingJob_videoId_fkey" FOREIGN KEY ("videoId") REFERENCES "Video"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "MediaProcessingJob" ADD CONSTRAINT "MediaProcessingJob_reelId_fkey" FOREIGN KEY ("reelId") REFERENCES "Reel"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "MediaProcessingJob" ADD CONSTRAINT "MediaProcessingJob_liveRecordingId_fkey" FOREIGN KEY ("liveRecordingId") REFERENCES "LiveRecording"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "FeedView" ADD CONSTRAINT "FeedView_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "FeedView" ADD CONSTRAINT "FeedView_videoId_fkey" FOREIGN KEY ("videoId") REFERENCES "Video"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "FeedView" ADD CONSTRAINT "FeedView_reelId_fkey" FOREIGN KEY ("reelId") REFERENCES "Reel"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CreatorLike" ADD CONSTRAINT "CreatorLike_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CreatorLike" ADD CONSTRAINT "CreatorLike_creatorId_fkey" FOREIGN KEY ("creatorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Dislike" ADD CONSTRAINT "Dislike_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Dislike" ADD CONSTRAINT "Dislike_videoId_fkey" FOREIGN KEY ("videoId") REFERENCES "Video"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Dislike" ADD CONSTRAINT "Dislike_reelId_fkey" FOREIGN KEY ("reelId") REFERENCES "Reel"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Share" ADD CONSTRAINT "Share_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Share" ADD CONSTRAINT "Share_videoId_fkey" FOREIGN KEY ("videoId") REFERENCES "Video"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Share" ADD CONSTRAINT "Share_reelId_fkey" FOREIGN KEY ("reelId") REFERENCES "Reel"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CreatorShare" ADD CONSTRAINT "CreatorShare_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CreatorShare" ADD CONSTRAINT "CreatorShare_creatorId_fkey" FOREIGN KEY ("creatorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PaymentEvent" ADD CONSTRAINT "PaymentEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
