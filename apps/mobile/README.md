# Mobile App

Flutter app shell for Nimbark Streaming.

## Feature Areas

- `auth` - login, register, session state
- `feed` - videos, reels, comments, likes
- `upload` - video and reel publishing
- `live` - LiveKit host and viewer flows
- `profile` - creator profile and settings

## Location Sync

Location permission should be requested only after a user is authenticated. After login, registration, or restoring an existing logged-in session on app launch, call `LocationSyncService.syncOnceAfterAuth(...)`.

The service sends at most one location ping per app process. If the user terminates and reopens the app while still logged in, it may ask/check permission again and refresh the latest location.

## Run

```bash
flutter pub get
flutter run
```

The app defaults to `https://nimbark-backend-r1mo.onrender.com/api`. For Android emulator with a local backend, use:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api
```

For iOS simulator or desktop, the default local API URL should work.
