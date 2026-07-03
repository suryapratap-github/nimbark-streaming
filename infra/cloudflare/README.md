# Cloudflare

Use Cloudflare R2 for original media and generated thumbnails. The backend should issue signed upload URLs instead of proxying large files through the API server.

Recommended buckets:

- `nimbark-media-dev`
- `nimbark-media-prod`
