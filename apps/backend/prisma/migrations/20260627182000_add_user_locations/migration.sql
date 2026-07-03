-- AlterTable
ALTER TABLE "User" ADD COLUMN "lastLatitude" DOUBLE PRECISION;
ALTER TABLE "User" ADD COLUMN "lastLongitude" DOUBLE PRECISION;
ALTER TABLE "User" ADD COLUMN "locationSource" TEXT;
ALTER TABLE "User" ADD COLUMN "locationUpdatedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "UserLocation" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "source" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserLocation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "UserLocation_userId_createdAt_idx" ON "UserLocation"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "UserLocation_createdAt_idx" ON "UserLocation"("createdAt");

-- AddForeignKey
ALTER TABLE "UserLocation" ADD CONSTRAINT "UserLocation_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
