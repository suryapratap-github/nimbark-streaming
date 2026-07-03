CREATE TABLE "LiveRoomBlock" (
  "id" TEXT NOT NULL,
  "roomId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "blockedBy" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "LiveRoomBlock_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "LiveRoomBlock_roomId_userId_key" ON "LiveRoomBlock"("roomId", "userId");
CREATE INDEX "LiveRoomBlock_roomId_idx" ON "LiveRoomBlock"("roomId");
CREATE INDEX "LiveRoomBlock_userId_idx" ON "LiveRoomBlock"("userId");

ALTER TABLE "LiveRoomBlock"
  ADD CONSTRAINT "LiveRoomBlock_roomId_fkey"
  FOREIGN KEY ("roomId") REFERENCES "LiveRoom"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "LiveRoomBlock"
  ADD CONSTRAINT "LiveRoomBlock_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
