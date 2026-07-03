CREATE TYPE "StorageProvider" AS ENUM ('LOCAL', 'R2');

CREATE TABLE "StorageSetting" (
  "id" TEXT NOT NULL DEFAULT 'default',
  "provider" "StorageProvider" NOT NULL DEFAULT 'LOCAL',
  "localBasePath" TEXT NOT NULL DEFAULT 'storage/media',
  "localPublicUrl" TEXT NOT NULL DEFAULT '/api/media/local',
  "r2Bucket" TEXT,
  "r2Endpoint" TEXT,
  "r2Region" TEXT NOT NULL DEFAULT 'auto',
  "r2AccessKeyId" TEXT,
  "r2SecretKey" TEXT,
  "r2PublicUrl" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "StorageSetting_pkey" PRIMARY KEY ("id")
);

INSERT INTO "StorageSetting" ("id", "provider", "localBasePath", "localPublicUrl")
VALUES ('default', 'LOCAL', 'storage/media', '/api/media/local')
ON CONFLICT ("id") DO NOTHING;
