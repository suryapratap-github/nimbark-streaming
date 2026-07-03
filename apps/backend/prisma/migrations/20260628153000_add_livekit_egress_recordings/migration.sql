ALTER TABLE "LiveRecording"
  ADD COLUMN "egressId" TEXT,
  ADD COLUMN "objectKey" TEXT,
  ADD COLUMN "publicUrl" TEXT,
  ADD COLUMN "errorMessage" TEXT,
  ADD COLUMN "startedAt" TIMESTAMP(3),
  ADD COLUMN "endedAt" TIMESTAMP(3),
  ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE UNIQUE INDEX "LiveRecording_egressId_key" ON "LiveRecording"("egressId");
CREATE INDEX "LiveRecording_roomId_status_idx" ON "LiveRecording"("roomId", "status");
