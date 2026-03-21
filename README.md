# Fidel

Flutter app for Android device diagnostics.

## What it does

- Shows live system data (CPU, memory, battery, thermal, sensors, and device metadata).
- Organizes data into feature pages under `lib/features`.
- Supports exporting snapshots/logs from the app.
- Includes localization support and app-level settings.

## Tech stack

- Flutter + Dart
- hooks_riverpod
- go_router
- GetX translations
- Native Android bridge in Kotlin (MethodChannel/EventChannel)

## Project layout

- `lib/features`: UI pages and feature widgets
- `lib/application`: providers and orchestration
- `lib/domain`: entities, value objects, repository contracts
- `lib/infrastructure`: datasource, mappers, repository implementations
- `lib/platform`: channel bridge definitions

## Requirements

- Flutter SDK (Dart `^3.11.0`)
- Android SDK

## Run locally

```bash
flutter pub get
flutter run
```

## Test

```bash
flutter test
```

## Build APK

```bash
flutter build apk --release
```

## License

MIT (see LICENSE).
