# Contributing to Open Tag Editor

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

1. Install Flutter SDK **3.41 or newer**, ideally the version pinned in
   `.fvmrc` (3.47.5) — see [Toolchain version](#toolchain-version)
2. Install CMake and a C++ toolchain (required to build the native runner)
3. Clone the repo and run `flutter pub get`
4. (Only when `native/taglib_c.h` changes) regenerate FFI bindings:
   `dart run ffigen --config native/ffigen.yaml`
5. Run the app: `flutter run -d windows` (or `macos` / `linux`)

The FFI bindings are committed, so a fresh clone needs no extra generation
step and the build works without a native toolchain beyond the standard one.

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

## Toolchain version

Use the Flutter SDK version pinned in `.fvmrc`; CI reads that same file.
This matters more than usual because `dart format` is **not** stable across
SDK releases — the tall-style formatter changes its output between them, so
running a different version locally can make the `format` job fail on files
you never touched. [FVM](https://fvm.app) and the Flutter VS Code extension
both read `.fvmrc` automatically.

If the `format` job fails on files you did not touch, compare
`dart --version` with `.fvmrc` before anything else. If they differ, the
fix is to align the SDK, not to reformat the tree by hand.

Two more things the format job needs, both of which it now does for you:
`flutter pub get` must run first, because `dart format` reads
`analysis_options.yaml` to determine the language version and cannot resolve
`package:flutter_lints` without a `package_config.json`.

## Reporting Issues

- Use GitHub Issues
- Include steps to reproduce, expected vs actual behavior
- Include the audio file format and OS if relevant

## Code of Conduct

Be respectful and constructive. We're all here to build something useful.
