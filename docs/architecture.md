# Architecture

## Runtime Components

- Flutter mobile app talks to the NestJS API over HTTPS.
- Admin panel talks to the same NestJS API using admin-only routes.
- NestJS stores relational data in PostgreSQL.
- Media files are uploaded to Cloudflare R2 through signed upload URLs.
- Cloudflare serves public media through CDN-backed URLs.
- LiveKit handles live audio/video rooms.
- Coturn helps clients connect when direct peer connectivity fails.
- Socket.io carries live comments, reactions, and viewer counts.
- Firebase FCM sends push notifications.

## Backend Module Boundaries

- `auth` - login, signup, token lifecycle
- `users` - profiles, follows, creator lookup
- `media` - upload sessions, R2 assets, thumbnails
- `feed` - video feed, reels feed, likes, comments
- `live` - room lifecycle, LiveKit tokens, realtime events
- `notifications` - notification records and FCM sending
- `admin` - moderation, reports, audit logs, metrics

## Database Foundation

The first implementation step uses Prisma and PostgreSQL. Prisma owns the schema in `apps/backend/prisma/schema.prisma`, and the generated client is injected through `PrismaService`.

Start with auth and media metadata before adding LiveKit. That gives uploads, feeds, and moderation a stable data model to build on.

## MVP Rule

Keep the first release to one-host live streaming. Co-hosting, gifts, subscriptions, and AI moderation belong after real user behavior validates the product.
