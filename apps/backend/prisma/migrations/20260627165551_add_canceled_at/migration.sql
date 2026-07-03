-- AlterTable
ALTER TABLE "UserSubscription" ADD COLUMN     "canceledAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "UserSubscription_status_expiresAt_idx" ON "UserSubscription"("status", "expiresAt");
