# Contributing to Open Tag Editor

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

1. Install Flutter SDK (>= 3.22.0)
2. Clone the repo and run `flutter pub get`
3. (Only when `native/taglib_c.h` changes) regenerate FFI bindings:
   `dart run ffigen --config native/ffigen.yaml`
4. Run the app: `flutter run -d windows` (or `macos` / `linux`)

## Project Structure

- `lib/core/` â€” Shared utilities, theme, constants
- `lib/features/` â€” Feature modules (tag_editor, renamer, online_lookup, etc.)
- `lib/shared/` â€” Shared models, services, and widgets
- `test/` â€” Unit and widget tests

## Guidelines

- Follow the existing code style (enforced by `analysis_options.yaml`)
- Write tests for new logic
- Keep features modular â€” each feature in its own directory
- Use Riverpod for state management
- Prefer immutable data models with `copyWith` (see the `AudioFile` pattern)
- Prefer composition over inheritance

## Pull Requests

1. Fork the repo and create a feature branch
2. Make your changes with clear commit messages
3. Run `dart format .` — CI fails on any formatting drift
4. Run `flutter analyze` — CI fails on *any* issue, lints included
5. Run `flutter test` — all tests must pass
6. Open a PR with a description of what changed and why

The three commands above are exactly what the `format`, `analyze` and
`test` CI jobs run, so a green local run means a green pipeline.

## Reporting Issues

- Use GitHub Issues
- Include steps to reproduce, expected vs actual behavior
- Include the audio file format and OS if relevant

## Code of Conduct

Be respectful and constructive. We're all here to build something useful.
