# Backend API

NestJS API for Nimbark Streaming.

## Modules

- `auth` - registration, login, sessions, tokens
- `users` - profiles, follows, creator lookup
- `media` - signed uploads, R2 assets, thumbnails
- `feed` - videos, reels, likes, comments
- `live` - LiveKit rooms, host controls, viewer access
- `notifications` - notification records and FCM
- `admin` - moderation and operational APIs

## Admin Auth

Admin routes require a valid JWT with the `ADMIN` role. Public registration creates normal `USER` accounts; admin accounts should be created through a controlled seed, migration, or manual database operation.

## User Location

User location is captured by the client after browser or mobile geolocation permission is granted. The user does not type location manually. The client should request location permission only after login, registration, or restoring an existing authenticated session. Clients send coordinates to:

```text
PATCH /api/users/:id/location
```

This endpoint requires `Authorization: Bearer <token>` and only accepts updates for the logged-in user. The backend stores the latest latitude/longitude on the user record and keeps location ping history for admin dashboard insights.

## Run

```bash
npm install
cp .env.example .env
npm run prisma:generate
npm run prisma:migrate
npm run start:dev
```

API base URL: `http://localhost:4000/api`

## LiveKit

Real live rooms require LiveKit credentials in `.env`:

```text
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your-api-key
LIVEKIT_API_SECRET=your-api-secret
```

The mobile app asks for camera and microphone permission only when a `CREATOR` or `ADMIN` starts publishing. Normal `USER` accounts receive viewer-only tokens and can join ongoing rooms.

## Database

The backend uses Prisma with PostgreSQL. Set `DATABASE_URL` in `.env`, then run:

```bash
npm run prisma:migrate
```

For local development, the example URL is:

```text
postgresql://postgres:postgres@localhost:5432/nimbark
```
