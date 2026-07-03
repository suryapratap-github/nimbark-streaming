# Nimbark Streaming

Monorepo starter for a Flutter video app, NestJS backend, and React admin panel.

## Folders

- `apps/backend` - NestJS API for auth, media, feeds, live rooms, notifications, and admin operations.
- `apps/admin` - React admin panel for users, moderation, reports, and metrics.
- `apps/mobile` - Flutter app shell for auth, feed, upload, live, and profile flows.
- `docs` - product and architecture notes.
- `infra` - deployment notes and placeholders for Cloudflare, LiveKit, Coturn, and PostgreSQL.

## First Setup

Install dependencies inside each app folder:

```bash
cd apps/backend && npm install
cd ../admin && npm install
cd ../mobile && flutter pub get
```

Then copy the env examples:

```bash
cp apps/backend/.env.example apps/backend/.env
cp apps/admin/.env.example apps/admin/.env
```

## Development Commands

Backend:

```bash
cd apps/backend
npm run prisma:generate
npm run prisma:migrate
npm run start:dev
```

Admin:

```bash
cd apps/admin
npm run dev
```

Mobile:

```bash
cd apps/mobile
flutter run
```
