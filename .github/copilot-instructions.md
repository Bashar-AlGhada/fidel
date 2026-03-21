# Project Guidelines

## Code Style
- Follow lint rules from [analysis_options.yaml](../analysis_options.yaml).
- Keep domain code Flutter-free.
- Prefer small, focused changes over broad refactors.
- Match existing naming patterns:
  - entities: `*_entity.dart`
  - mappers: `*_mapper.dart` with `fromMap`/`to...` style conversions
  - repository interfaces in `lib/domain/repositories`, implementations in `lib/infrastructure/repositories_impl`

## Architecture
- Respect layer boundaries:
  - `lib/features` -> UI and presentation
  - `lib/application` -> providers and orchestration
  - `lib/domain` -> entities, value objects, repository contracts, use cases
  - `lib/infrastructure` -> datasource + mapper + repository implementations
  - `lib/platform` -> channel bridge definitions
- Do not bypass repository contracts with direct cross-layer imports.
- Keep platform-specific behavior in infrastructure/platform, not domain.

## Build and Test
- Install deps: `flutter pub get`
- Run app: `flutter run`
- Analyze: `flutter analyze`
- Run tests: `flutter test`
- Build release APK: `flutter build apk --release`

## Conventions
- Platform payload parsing must be defensive: handle `num`/`String` conversions and nulls safely.
- When fixing mapper/provider bugs, add or update tests in `test/` for the specific edge case.
- For stream-driven features, preserve existing route/module-aware sampling behavior.
- Keep docs concise; link to existing docs instead of duplicating content:
  - [README.md](../README.md)
  - [misc/fidel_plan.md](../misc/fidel_plan.md)
