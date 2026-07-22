# Nimbark Mobile Product Redesign

## Product Direction

Nimbark should feel like a creator-first streaming studio, not a generic social feed. The product is organized around three jobs:

- Watch: discover videos, swipe shorts, continue watching, react, comment, share, report.
- Create: upload, prepare details, publish, monitor processing, manage content.
- Go live: start, join, moderate, notify, and review live performance.

The redesign keeps the existing destinations but changes their hierarchy. Home becomes the discovery surface, Create becomes a guided studio, Live remains a real-time surface, Inbox becomes action-oriented notifications, and You becomes channel identity plus account controls.

## Navigation Map

```text
App
├─ Home
│  ├─ Videos
│  ├─ Shorts
│  ├─ Search
│  ├─ Creator profile
│  └─ Video detail + inline comments
├─ Create
│  ├─ Pick format
│  ├─ Select media
│  ├─ Add metadata
│  ├─ Publish
│  └─ Processing status
├─ Live
│  ├─ Create room
│  ├─ Join room
│  ├─ Viewer panel
│  └─ Live comments
├─ Inbox
│  ├─ Comment notification
│  ├─ Follow notification
│  └─ Live started notification
└─ You
   ├─ Channel header
   ├─ Creator quick actions
   ├─ Appearance
   ├─ Profile settings
   ├─ Password
   └─ Creator subscription/access
```

## Core User Flows

```text
First-time viewer
Auth -> Home -> Search or watch -> React/comment/share -> Follow creator
```

```text
Returning viewer
Open app -> Continue Home/Shorts -> Inbox live notification -> Join live
```

```text
Creator upload
You/Create -> Pick format -> Select media -> Add details -> Publish -> Processing -> Dashboard
```

```text
Creator performance
You -> Creator dashboard -> Analytics -> Top posts -> Open detail -> Manage/delete
```

## Design Tokens

Spacing uses an 8pt system: 8, 16, 24, 32. Dense controls may use 4px internal gaps only when text and icons stay within 44x44 touch targets.

Radius scale:

- `radius1`: 8, chips and small controls.
- `radius2`: 14, fields, buttons, panels.
- `radius3`: 22, feed cards and immersive media.
- `nav`: 28, floating navigation.

Elevation:

- `0`: flat inline content.
- `1`: panels.
- `2`: feed cards and creator modules.
- `3`: floating navigation and overlays.

Blur:

- `surface`: 18px frosted panels.
- `media dock`: 16px over video.

Motion:

- Fast: 160ms for taps and active states.
- Base: 260ms for navigation, search, card state changes.
- Slow: 420ms for future full-screen transitions.
- Curve: ease-out cubic. Respect reduced-motion by replacing animated movement with opacity/state changes.

Color identity:

- Signal red/orange for creation and play.
- Violet for premium depth.
- Teal for live and confirmation accents.
- Warm neutral surfaces to avoid a single-hue dark slate look.

Typography:

- Screen titles: 22-28, weight 900.
- Section titles: 18-22, weight 900.
- Body: platform default size, weight 400-500.
- Labels: 11-14, weight 800-900.

Icon sizing:

- Small: 18.
- Standard: 24.
- Large: 32.
- Touch target: minimum 44x44.

## Component States

Every reusable component must define:

- Default: neutral surface, clear label or icon.
- Hover: future web uses slightly raised/tinted surface.
- Pressed: 160ms scale or tonal compression.
- Focused: primary 1.6px outline.
- Disabled: 38-50% opacity, no shadow.
- Loading: spinner or skeleton in stable dimensions.
- Success: teal/check state plus short confirmation.
- Error: error color border/message with retry.
- Selected: primary-container fill and strong label weight.
- Active: selected plus motion or live indicator.
- Inactive: neutral foreground and no elevation change.

## Micro-Interactions

- Like: active tonal fill, 160ms scale pulse, optimistic count update.
- Subscribe/follow: filled CTA transitions to selected state with confirmation.
- Share: clipboard success snackbar and share count update.
- Comment: bottom sheet, send action, count update.
- Notifications: badge count in floating nav and direct deep-link routing.
- Upload success: status card changes from processing to success.
- Live starting/ending: use teal pulse for active, soft fade for ended.
- Pull to refresh: existing refresh indicator, future custom branded progress.
- Search: animated expansion from discovery header into field.
- Tab switching: `AnimatedSwitcher` with stable page keys.
- Card expansion: feed cards open detail via shared content hierarchy.
- Loading: media thumbnails remain aspect-stable to avoid layout jumps.

## Video Experience

Implemented lightweight controls:

- Tap play/pause.
- Double tap left/right seek by 10 seconds.
- Playback speed selector.
- Captions affordance.
- Picture-in-picture affordance.
- Screen lock.
- Sleep timer affordance.
- Progress rail.

Future native wiring:

- Android/iOS PiP APIs.
- Caption track parsing and language selector.
- Brightness and volume vertical gestures.
- Mini player persisted across navigation.
- Quality selector from transcoding variants.
- Continue watching backed by server watch progress.
- Smart recommendations backed by watch, like, comment, and creator-follow signals.

## Creator Experience

Current implementation keeps upload, format selection, details, comments, publish, processing, dashboard, analytics, and deletion.

Next creator modules:

- Drafts with local persistence.
- Thumbnail editor with scrub-frame selection and crop.
- Tags and categories.
- Schedule publish.
- Copyright checks during processing.
- Revenue tab with subscription and post-level earnings.
- Audience insights by followers, returning viewers, and live viewers.

## Empty States

Every empty screen should include an icon or illustration, useful message, and one primary action:

- Empty feed: invite creators to publish or refresh.
- Empty search: suggest searchable topics once query is long enough.
- Empty creator dashboard: upload CTA.
- Empty inbox: direct user back to Home/Live.
- Empty live: create or refresh rooms.
- Empty profile content: complete channel identity.

## Error States

Error states use compact, respectful language and a recovery action:

- Network error: retry.
- No internet: retry after connection.
- Upload failure: keep selected file and retry publish.
- Permission denied: explain required permission and link settings.
- Content unavailable: return to feed.
- Server error: retry with diagnostic message preserved for debugging.

## Accessibility Checklist

- 44x44 minimum touch targets.
- Semantic labels for navigation and icon-only controls.
- WCAG AA contrast for text and state colors.
- Dynamic text should wrap within panels.
- Reduced motion mode should avoid large transitions.
- Color is not the only state indicator.
- Keyboard focus border is defined for future web/desktop.
- Error text is visible and screen-reader readable.

## Developer Handoff

The Flutter implementation now centralizes product primitives in `main.dart`:

- `_NimbarkTokens`
- `_NimbarkBrandMark`
- `_PremiumSurface`
- `_FloatingNavBar`
- `_VideoControlDock`

As the app grows, move these into `lib/core/design/` and split screens out of `main.dart`. Keep API behavior unchanged while extracting components, and add widget tests for feed navigation, upload validation, and video controls before deeper feature wiring.
