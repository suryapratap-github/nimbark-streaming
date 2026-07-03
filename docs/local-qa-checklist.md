# Local QA Checklist

Use this checklist before calling a build ready for deployment or real-device testing.

## Automated Checks

Run from the repo root unless noted.

```bash
cd apps/backend
npx prisma migrate status --schema prisma/schema.prisma
npm test
npm run build
```

```bash
cd apps/admin
npm run build
```

```bash
cd apps/mobile
flutter analyze
flutter test
```

Expected result:

- Prisma reports the database schema is up to date.
- Backend tests pass.
- Backend build passes.
- Admin build passes.
- Flutter analyze reports no issues.
- Flutter tests pass.

## Backend API Smoke Test

Start backend:

```bash
cd apps/backend
npm run start:dev
```

Check:

- `GET /api/media/settings`
- `POST /api/auth/login`
- `GET /api/admin/dashboard` with admin token
- `GET /api/feed/videos`
- `GET /api/live/rooms?status=LIVE`

## Admin Smoke Test

Start admin:

```bash
cd apps/admin
npm run dev
```

Check:

- Admin login works.
- Dashboard loads.
- Users list loads.
- Feed tab loads and can filter Published / Blocked / Deleted.
- Reports tab loads and can filter Pending / Reviewing / Actioned / Dismissed.
- Audit tab loads moderation actions.
- Storage tab health check works.
- Processing tab loads.
- Live tab loads.

## Mobile Local Smoke Test

Run with the backend URL for your device:

Android emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api
```

Physical device on same Wi-Fi:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:4000/api
```

Check:

- Register/login.
- Location prompt appears only after login.
- Profile loads and can be edited.
- Feed videos/reels load.
- Creator subscription UI loads.
- Creator can upload video/reel with thumbnail.
- Reel longer than 30 seconds is blocked before upload.
- Viewer can like/dislike/share/comment/report.
- Creator can delete own post and moderate own comments.
- Search finds creators and feed content.
- Notifications tab loads and unread count updates.

## Live Streaming Manual QA

This must be tested on real devices or emulator/device pairs with camera/mic permissions.

- Creator can create a live room.
- Creator can go live and sees timer.
- Creator sees active viewer count.
- Viewer can join ongoing live.
- Viewer can comment and react when enabled.
- Viewer cannot comment/react when disabled.
- Host sees all comments.
- Viewer sees only their own comments/reactions.
- Host can block/unblock viewer.
- Blocked viewer is removed and cannot rejoin.
- Viewer can report live stream.
- Live session ends cleanly after host leaves.
- Failed LiveKit connection ends the created live session.

## Push Notification Manual QA

Requires Firebase/APNs/FCM production or sandbox setup.

- Device token is registered after login.
- Follow notification appears in-app.
- Comment notification appears in-app.
- Followed creator live-start notification appears in-app.
- Push notification opens the correct screen when tapped.
- iOS APNs capability is enabled in Xcode and Apple Developer portal.

## RevenueCat Manual QA

Requires App Store / Play Store sandbox products.

- Products load from RevenueCat.
- Purchase activates subscription.
- Active subscription changes role to `CREATOR`.
- Restore purchase syncs subscription.
- RevenueCat webhook records payment event.
- Cancellation/expiration/billing failure downgrades role to `USER`.

## Media Storage Manual QA

Current default is local storage.

- Upload stores files under local media storage.
- Admin preview opens uploaded video/reel.
- Thumbnail displays in feed/admin.
- Processing job moves from queued/running to completed or skipped.
- Cleanup dry run reports orphan files before deletion.

R2 mode requires real Cloudflare credentials:

- Admin switches provider to R2.
- Storage health succeeds.
- Mobile upload uses signed PUT URL.
- Feed media public URL resolves through CDN/public URL.
- Processed media writes back to R2.
