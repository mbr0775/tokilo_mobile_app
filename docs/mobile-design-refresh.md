# Mobile design refresh

The Flutter client now uses a light Tokilo teal palette, bundled Roboto typography,
compact Material navigation and accessible native controls. The admin landing page
and workspace drawer use the same visual system.

## Updated screens

Home, Feed, Profile, Chat, onboarding, login, project requests, service pricing,
portfolio, notification inbox and the admin dashboard. Existing auth, request,
pricing, gallery, attachment and account deletion operations remain connected.
Showcase actions open `/portfolio`; `/notifications` is now registered.

The notification inbox reads the authenticated `tokilo_notification_feed` RPC
and the user's `project_notifications`. Account read receipts use
`tokilo_read_notifications`, including per-user broadcast receipts. Realtime
subscriptions refresh both sources. This requires the communications migrations
already applied to the shared TokiloMobileApp Supabase project.

## Motion

`ViewportMotion` observes the scroll position after layout, replays reveals on
viewport entry, and pauses decorative looping animation offscreen or while the
app is inactive. Reduced motion renders content immediately and freezes the
illustration. `TechScene` uses native transforms and a simple orbit painter;
no remote fonts, videos or animation dependencies are required.

## Verification

- 42 Flutter tests passed, including the existing startup and Google OAuth tests.
- Twelve screen types render at 390 x 844 and 360 x 640 with 1.4x text scaling.
- Navigation, admin menu, notification receipts, keyboard-aware chat composer,
  error/empty project states, reveal replay and loop suspension are covered.
- Screenshot fixtures use mocked HTTP and an in-memory Realtime socket;
  they contain no production conversations or database mutations.
- Android debug APK builds successfully at
  `build/app/outputs/flutter-apk/app-debug.apk`.
- Dart analysis has no errors; two existing unused-field warnings and legacy
  informational lints remain elsewhere in the repository.
- A physical NIC LX2 running Android 15 (API 35) was connected for the earlier UI pass. The debug
  build installed and launched successfully on its 720 x 1604 display at 320 dpi.
  The actual signed-out login screen was inspected; startup logs showed no
  Flutter exceptions or layout overflow, and notification permission was granted.
  After owner sign-in, live Feed projects, Home, Profile, admin dashboard,
  conversation list, an existing account conversation and notification inbox
  loaded on the phone. The chat composer remained above the native keyboard.
  Physical testing found and fixed portrait image cropping, admin shortcuts
  opening the customer chat route, the old admin inbox header and the gray
  navigation-bar scrim. The updated debug APK was reinstalled successfully.
  Wireless ADB disconnected before the final physical scroll-replay recheck.
  Replay, viewport pause and reduced motion pass the Flutter regression tests.
  No test messages were sent from the phone. End-to-end send/receive delivery,
  release-mode frame performance and iOS compilation remain unverified.
  Android reported skipped frames during debug cold startup; no steady-state
  frame-rate claim is made from this debug run.

Run `flutter test` for the checks. Set `TOKILO_UI_CAPTURE` to an output directory
to also save the rendered preview screenshots. Use the debug APK or hot restart
the Flutter app to see the changes. This is a local preview, not a store release.

The pre-existing mobile working tree and index were preserved. This refresh has
not been committed or pushed with the unrelated staged work.

## Home and Feed studio redesign — 13 October 2026

Home now uses a compact wordmark/header, ink typography with a lime highlight,
a swipeable live-project showcase, focused service rows and quick account links.
Feed uses flatter social posts, pinned filters, expandable captions and contained
portrait previews. Portrait images keep their full content, use restrained native
perspective motion and open the existing full-screen zoomable gallery. The gallery
now has labeled keyboard-accessible controls and reduced-motion transitions.
Independent feed content queries load concurrently. Data sources, auth and likes
remain connected to the existing Supabase project; no demo rows were added.
The mobile brand art is a small WebP derived from the owner's existing website art.

The latest Home/Feed layouts were inspected as Flutter renders at 390 x 844 and
360 x 640 (1.4x text scale), including locally cached copies of the owner's public
showcase images. The HTTP fixtures are isolated and the Realtime socket is in
memory: these tests send no production requests or messages. New interaction
checks cover filters, caption expansion, gallery opening/closing, messaging
navigation and swiping between projects. All 42 tests pass.

For representative screenshots, optionally set `TOKILO_PUBLIC_FIXTURES` to a local
folder containing `showcase.json` and each corresponding `<project-id>.jpg` before
running `test/mobile_design_test.dart`. Without that variable, tests use portable
synthetic fixtures. No credentials are required for the preview.

The phone is currently disconnected from ADB. This latest Home/Feed revision has
not yet been installed or visually checked on the physical phone. Use the rebuilt
debug APK to preview it; earlier physical-device verification above applies to the
previous revision. Release performance, iOS compilation and production messaging
send/receive are not covered by this visual refresh.
