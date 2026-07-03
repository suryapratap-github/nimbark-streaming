# Media Storage

The app now uses a single storage flow for feed videos, reels, thumbnails, processed outputs, and LiveKit recording assets.

## Current Mode: Local Storage

Local storage remains the default and active development mode.

- Uploaded files are stored under `storage/media`.
- Public files are served through `/api/media/local/...`.
- Admin can view storage health from the Storage page.
- Admin can run orphan cleanup as a dry run before deleting files.
- The scheduled cleanup runs daily in dry-run mode unless `MEDIA_CLEANUP_DELETE_ORPHANS=true`.

## Cloudflare R2 Mode

R2 can be enabled later from the admin Storage page after these values are available:

- Bucket
- Endpoint
- Region, usually `auto`
- Access key ID
- Secret access key
- Public/CDN URL

When R2 is active:

- Mobile asks the backend for an upload target.
- Backend returns a short-lived signed PUT URL.
- Mobile uploads directly to R2.
- Feed publish stores the R2 object key and public URL.
- The processing worker downloads source media from R2, transcodes locally, then uploads processed output back to R2.
- LiveKit recording is enabled only when R2 storage is active, because LiveKit cloud egress needs remote object storage.

## Health And Cleanup

Admin storage health checks:

- Local: confirms the local media directory exists and is writable.
- R2: confirms required R2 fields are present and the bucket can be reached.

Cleanup:

- Local cleanup compares files on disk with `MediaAsset.objectKey`.
- Dry run is the default.
- R2 orphan cleanup is intentionally not destructive yet; it should be added after lifecycle policies and audit needs are finalized.
