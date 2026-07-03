# Nimbark Streaming Scope

## Product Direction

Build a short-video and lightweight live-streaming platform first. The MVP should feel closer to "TikTok plus Twitch Lite" than a full clone of YouTube, Instagram, and Twitch.

The goal is to launch a focused product quickly:

- Mobile-first video and reels feed
- Creator profiles and follows
- One-host live streams
- Comments, reactions, and notifications
- Live recording that can be published back into the feed
- Admin tools for moderation and operational visibility

## Phase 1: Video MVP

Timeline: 2-4 weeks

User features:

- Register, login, logout
- Profile setup and edit
- Upload videos
- Upload reels
- Home video feed
- Reels feed
- Like, comment, share
- Follow and unfollow creators
- Push notifications

Admin features:

- User list and user detail
- Video and reel moderation queue
- Report review
- Basic platform metrics

Core backend:

- Auth and user APIs
- Media upload API with Cloudflare R2 signed upload flow
- Feed APIs
- Likes, comments, follows
- Notification records and FCM dispatch
- Admin-only moderation APIs

## Phase 2: Live Streaming MVP

Timeline: 2-3 weeks

Host features:

- Go live
- Stop live
- Switch camera
- Mute and unmute microphone
- Turn camera on and off
- Enable and disable comments
- Record live stream
- Show default image when camera is off

Viewer features:

- Join live stream
- Send comments
- Send reactions
- View viewer count
- Receive notification when a followed creator goes live

Core backend:

- Live room creation
- LiveKit token generation
- Live status tracking
- Socket.io events for comments, reactions, and viewer count
- FCM notification when a creator starts a stream

## Phase 3: Recording And Publishing

Timeline: 1 week

Recording flow:

1. Host starts recording.
2. LiveKit records the stream.
3. Recording is stored in Cloudflare R2.
4. Media worker generates a thumbnail.
5. Backend creates a feed post automatically.
6. Recording appears in the app feed.

## Phase 4: Scale Later

Add these only after MVP usage proves the need:

- CDN tuning
- Multiple LiveKit servers
- Chat moderation
- AI moderation
- Stream quality adaptation
- Creator analytics
- Monetization
- Gifts and subscriptions
- Multiple hosts and co-hosting

## Tech Stack

- Mobile app: Flutter
- Backend API: Node.js with NestJS
- Admin panel: React with Vite
- Database: PostgreSQL
- Storage: Cloudflare R2
- CDN: Cloudflare
- Push notifications: Firebase FCM
- Live server: self-hosted LiveKit
- TURN server: Coturn
- Realtime events: Socket.io

## Repository Structure

```text
NimbarkStreaming
├── apps
│   ├── backend        # NestJS API
│   ├── admin          # React admin panel
│   └── mobile         # Flutter app
├── docs               # Product and architecture docs
├── infra              # Deployment notes and config placeholders
└── scope.md
```

## Initial Database Tables

- users
- user_sessions
- videos
- reels
- media_assets
- comments
- likes
- follows
- notifications
- live_rooms
- live_comments
- live_reactions
- live_recordings
- reports
- admin_audit_logs

## Estimated MVP Monthly Cost

- Backend VPS: 4 GB RAM, 2 CPU, about $5-10/month
- LiveKit VPS: 8 GB RAM, 4 CPU, about $15-20/month
- Coturn VPS: about $5/month
- Cloudflare R2: low initial cost

Expected MVP range: about $20-35/month before traffic grows.
