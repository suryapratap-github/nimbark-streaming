-- User/session lookup indexes
CREATE INDEX "User_role_isActive_createdAt_idx" ON "User"("role", "isActive", "createdAt");
CREATE INDEX "User_isActive_createdAt_idx" ON "User"("isActive", "createdAt");
CREATE INDEX "UserSession_userId_expiresAt_idx" ON "UserSession"("userId", "expiresAt");
CREATE INDEX "UserSession_expiresAt_idx" ON "UserSession"("expiresAt");

-- Media/feed indexes
CREATE INDEX "MediaAsset_ownerId_type_createdAt_idx" ON "MediaAsset"("ownerId", "type", "createdAt");
CREATE INDEX "MediaAsset_bucket_createdAt_idx" ON "MediaAsset"("bucket", "createdAt");
CREATE INDEX "Video_status_createdAt_idx" ON "Video"("status", "createdAt");
CREATE INDEX "Video_creatorId_status_createdAt_idx" ON "Video"("creatorId", "status", "createdAt");
CREATE INDEX "Video_mediaAssetId_idx" ON "Video"("mediaAssetId");
CREATE INDEX "Reel_status_createdAt_idx" ON "Reel"("status", "createdAt");
CREATE INDEX "Reel_creatorId_status_createdAt_idx" ON "Reel"("creatorId", "status", "createdAt");
CREATE INDEX "Reel_mediaAssetId_idx" ON "Reel"("mediaAssetId");
CREATE INDEX "Comment_videoId_createdAt_idx" ON "Comment"("videoId", "createdAt");
CREATE INDEX "Comment_reelId_createdAt_idx" ON "Comment"("reelId", "createdAt");
CREATE INDEX "Comment_authorId_createdAt_idx" ON "Comment"("authorId", "createdAt");
CREATE INDEX "Like_videoId_idx" ON "Like"("videoId");
CREATE INDEX "Like_reelId_idx" ON "Like"("reelId");
CREATE INDEX "Dislike_videoId_idx" ON "Dislike"("videoId");
CREATE INDEX "Dislike_reelId_idx" ON "Dislike"("reelId");
CREATE INDEX "Follow_followingId_createdAt_idx" ON "Follow"("followingId", "createdAt");
CREATE INDEX "Follow_followerId_createdAt_idx" ON "Follow"("followerId", "createdAt");

-- Notification/subscription indexes
CREATE INDEX "Notification_userId_readAt_createdAt_idx" ON "Notification"("userId", "readAt", "createdAt");
CREATE INDEX "Notification_userId_createdAt_idx" ON "Notification"("userId", "createdAt");
CREATE INDEX "SubscriptionPlan_isActive_priceCents_idx" ON "SubscriptionPlan"("isActive", "priceCents");
CREATE INDEX "UserSubscription_externalProductId_idx" ON "UserSubscription"("externalProductId");
CREATE INDEX "UserSubscription_latestEventAt_idx" ON "UserSubscription"("latestEventAt");

-- Live indexes
CREATE INDEX "LiveRoom_status_createdAt_idx" ON "LiveRoom"("status", "createdAt");
CREATE INDEX "LiveRoom_hostId_status_createdAt_idx" ON "LiveRoom"("hostId", "status", "createdAt");
CREATE INDEX "LiveComment_roomId_createdAt_idx" ON "LiveComment"("roomId", "createdAt");
CREATE INDEX "LiveComment_userId_createdAt_idx" ON "LiveComment"("userId", "createdAt");
CREATE INDEX "LiveReaction_roomId_createdAt_idx" ON "LiveReaction"("roomId", "createdAt");
CREATE INDEX "LiveReaction_roomId_emoji_idx" ON "LiveReaction"("roomId", "emoji");
CREATE INDEX "LiveReaction_userId_createdAt_idx" ON "LiveReaction"("userId", "createdAt");
CREATE INDEX "LiveRoomViewerSession_roomId_lastSeenAt_idx" ON "LiveRoomViewerSession"("roomId", "lastSeenAt");

-- Moderation/audit indexes
CREATE INDEX "Report_status_createdAt_idx" ON "Report"("status", "createdAt");
CREATE INDEX "Report_targetType_targetId_idx" ON "Report"("targetType", "targetId");
CREATE INDEX "Report_reporterId_createdAt_idx" ON "Report"("reporterId", "createdAt");
CREATE INDEX "Report_subjectUserId_createdAt_idx" ON "Report"("subjectUserId", "createdAt");
CREATE INDEX "AdminAuditLog_adminId_createdAt_idx" ON "AdminAuditLog"("adminId", "createdAt");
CREATE INDEX "AdminAuditLog_action_createdAt_idx" ON "AdminAuditLog"("action", "createdAt");
CREATE INDEX "AdminAuditLog_target_idx" ON "AdminAuditLog"("target");
CREATE INDEX "AdminAuditLog_createdAt_idx" ON "AdminAuditLog"("createdAt");
