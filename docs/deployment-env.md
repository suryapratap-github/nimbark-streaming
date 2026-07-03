# Deployment And Environment Checklist

Do not commit real secrets. Use your hosting provider secret manager for production values.

## Backend

Required production environment:

```bash
NODE_ENV=production
PORT=4000
DATABASE_URL=
JWT_SECRET=
JWT_EXPIRES_IN=7d
CORS_ORIGIN=
LOCAL_STORAGE_PATH=storage/media
MEDIA_TRANSCODING_ENABLED=true
FFMPEG_PATH=ffmpeg
MEDIA_CLEANUP_DELETE_ORPHANS=false
```

Firebase:

```bash
FIREBASE_SERVICE_ACCOUNT_JSON=
FIREBASE_SERVICE_ACCOUNT_PATH=
```

On Render, set `FIREBASE_SERVICE_ACCOUNT_JSON` to the full Firebase service-account JSON content. For local development, you can instead set `FIREBASE_SERVICE_ACCOUNT_PATH` to a local JSON file path. Do not commit the JSON file. Rotate any service account key that was shared outside a secret manager.

RevenueCat:

```bash
REVENUECAT_IOS_API_KEY=
REVENUECAT_ANDROID_API_KEY=
REVENUECAT_DEFAULT_OFFERING_ID=
REVENUECAT_WEBHOOK_SECRET=
```

LiveKit:

```bash
LIVEKIT_URL=
LIVEKIT_API_KEY=
LIVEKIT_API_SECRET=
LIVE_RECORDING_ENABLED=false
LIVE_RECORDING_LAYOUT=speaker
LIVE_RECORDING_PUBLIC_URL=
```

Cloudflare R2, when switching from local storage:

```bash
CLOUDFLARE_ACCOUNT_ID=
CLOUDFLARE_R2_BUCKET=
CLOUDFLARE_R2_ENDPOINT=
CLOUDFLARE_R2_REGION=auto
CLOUDFLARE_R2_ACCESS_KEY_ID=
CLOUDFLARE_R2_SECRET_ACCESS_KEY=
CLOUDFLARE_PUBLIC_MEDIA_URL=
```

## Admin

Required production environment:

```bash
VITE_API_URL=https://YOUR_BACKEND_DOMAIN/api
```

Build:

```bash
cd apps/admin
npm run build
```

Deploy `apps/admin/dist` to a static host.

## Mobile

Build with API URL:

```bash
flutter build apk --dart-define=API_BASE_URL=https://YOUR_BACKEND_DOMAIN/api
flutter build appbundle --dart-define=API_BASE_URL=https://YOUR_BACKEND_DOMAIN/api
flutter build ios --dart-define=API_BASE_URL=https://YOUR_BACKEND_DOMAIN/api
```

Firebase files:

- Android: `apps/mobile/android/app/google-services.json`
- iOS: `apps/mobile/ios/Runner/GoogleService-Info.plist`

iOS capabilities:

- Push Notifications
- Background Modes
- Remote notifications

Android permissions:

- Camera
- Microphone
- Internet
- Location, only after login flow
- Notifications, where required by Android version

## Database

Deploy migrations:

```bash
cd apps/backend
npx prisma migrate deploy --schema prisma/schema.prisma
npx prisma generate --schema prisma/schema.prisma
```

Recommended production database:

- Managed PostgreSQL
- Automated backups
- Point-in-time recovery
- Connection pooling
- Restricted inbound access

## Media

Development/default:

- Local storage
- Public media served through backend

Production recommendation:

- Cloudflare R2 for original uploads
- Cloudflare CDN/public URL for delivery
- Lifecycle rules for orphaned/temporary objects
- Keep local storage only for temporary processing

## LiveKit

Production requirements:

- LiveKit Cloud or self-hosted LiveKit
- TURN/coturn if self-hosted
- HTTPS/WSS endpoints
- Egress enabled only when R2 storage is configured

## RevenueCat

Production requirements:

- App Store subscription products
- Play Store subscription products
- RevenueCat offerings/packages mapped to admin plans
- Webhook URL: `https://YOUR_BACKEND_DOMAIN/api/payments/revenuecat/webhook`
- Webhook authorization secret configured in backend

Role rules:

- Active paid subscription -> `CREATOR`
- Expired/cancelled/billing issue -> `USER`

## Firebase Push

Production requirements:

- Android FCM configured.
- iOS APNs key/certificate uploaded to Firebase.
- iOS bundle identifier matches Firebase iOS app.
- Backend service account available through secret file path.

## Pre-Deploy Commands

```bash
cd apps/backend
npm test
npm run build
npx prisma validate --schema prisma/schema.prisma
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

## Post-Deploy Smoke Test

- Backend health/API responds.
- Admin can login.
- Mobile can login against production API.
- Feed loads.
- Upload works.
- Live token creation works.
- RevenueCat config endpoint returns expected keys.
- Notification device token registration succeeds.
- Reports and audit logs appear in admin.
