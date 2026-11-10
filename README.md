# ucp

A Flutter project (org: `com.example`, platforms: android, ios, linux, macos, windows, web).

Flutter SDK: `3.47.5` stable (Dart `3.13.4`), installed at `/home/ubuntu/flutter`.

## Getting Started

```bash
export PATH="/home/ubuntu/flutter/bin:$PATH"
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run
```

Build examples:

```bash
flutter build apk --release
flutter build web --release
flutter build linux --release
```

## Release builds must ship `EXT_API_KEY`

The live leaderboard (`/api/ext/*`) is gated by the shared `x-api-key`
header. The key lives in three places and **all three must match**:

1. Server — Vercel project `ucp-community-api` → env `EXT_API_KEY` (production)
2. Chrome extension — `ucp-live-grading-extenstion/src/config.js`
3. This app — build-time `--dart-define`

Without it the app silently falls back to the demo leaderboard board
(`isExtConfigured` is false). So a release build must be:

```bash
flutter build apk --release \
  --dart-define=NODE_API_URL=https://ucp.animezone.me \
  --dart-define=EXT_API_KEY=<the key the server holds>
```

The key is also embedded in the shipped app binary, so treat it as
public — it gates the ext surface from random callers, it is **not**
student authentication.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
