ALTER TABLE "LiveRoom"
  ADD COLUMN "currentViewerCount" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "peakViewerCount" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "totalViewerJoins" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "uniqueViewerCount" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "LiveRoomViewerSession" (
  "id" TEXT NOT NULL,
  "roomId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "leftAt" TIMESTAMP(3),
  "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "LiveRoomViewerSession_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "LiveRoomViewerSession_roomId_leftAt_idx" ON "LiveRoomViewerSession"("roomId", "leftAt");
CREATE INDEX "LiveRoomViewerSession_roomId_userId_idx" ON "LiveRoomViewerSession"("roomId", "userId");
CREATE INDEX "LiveRoomViewerSession_userId_joinedAt_idx" ON "LiveRoomViewerSession"("userId", "joinedAt");

ALTER TABLE "LiveRoomViewerSession"
  ADD CONSTRAINT "LiveRoomViewerSession_roomId_fkey"
  FOREIGN KEY ("roomId") REFERENCES "LiveRoom"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "LiveRoomViewerSession"
  ADD CONSTRAINT "LiveRoomViewerSession_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
