# Repository Guidelines

## Project Structure & Module Organization

Application code lives in `lib/`. Keep shared theme definitions in `lib/core/theme/`, domain models in `lib/models/`, Firebase and model integrations in `lib/services/`, and UI code in `lib/presentation/`. Presentation is divided into BLoCs, controllers, screens, and reusable widgets. Native platform configuration belongs in `android/` and `ios/`; do not place Dart business logic there. Store bundled images and models under `assets/` and register new asset paths in `pubspec.yaml`. Add automated tests under `test/`, mirroring the source layout where practical.

## Build, Test, and Development Commands

- `flutter pub get` installs dependencies from `pubspec.yaml`.
- `flutter run` launches the app on a connected device or emulator. A physical device is recommended for camera inference.
- `flutter analyze` runs the Dart analyzer and the `flutter_lints` rules.
- `dart format lib test` applies standard Dart formatting.
- `flutter test` runs all unit and widget tests; use `flutter test --coverage` when checking coverage locally.
- `flutter build apk` or `flutter build ios` creates release artifacts for the target platform. iOS builds require macOS and Xcode.

## Coding Style & Naming Conventions

Use Dart's standard two-space indentation and keep code formatter-clean. Name files and directories with `snake_case`, classes and enums with `UpperCamelCase`, and variables and methods with `lowerCamelCase`. Prefer small, focused widgets and keep state transitions in BLoCs or controllers rather than screens. Follow the rules inherited from `package:flutter_lints/flutter.yaml`; justify any lint suppression with a nearby comment.

## Testing Guidelines

Use `flutter_test` for unit and widget tests. Name files `*_test.dart` and organize related cases with `group()`. Cover new state transitions, service error handling, and important widget interactions. Mock Firebase, camera, and model boundaries so routine tests remain deterministic and do not require credentials or hardware. There is no enforced coverage threshold, but changed behavior should include regression tests.

## Commit & Pull Request Guidelines

Match the existing history: write concise, imperative commit subjects such as `Add estimate disclaimer` or `Fix edge-to-edge layout`. Keep each commit focused. Pull requests should explain the user-visible change, list validation commands, link relevant issues, and include screenshots or recordings for UI changes. Call out platform-specific behavior and configuration changes explicitly.

## Security & Local Configuration

Never commit Firebase credentials or downloaded ML model binaries. Create `lib/firebase_options.dart` from `lib/firebase_options.example.dart`, place platform Firebase files in the locations documented in `README.md`, and keep local secrets out of logs and reviews.

## Agent skills

### Issue tracker

Issues are tracked in the Linear `AutoDentifyr` team (`ATD`); Linear is authoritative, with GitHub used for code and pull requests. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default triage labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repository using root `CONTEXT.md` and `docs/adr/`. See `docs/agents/domain.md`.
