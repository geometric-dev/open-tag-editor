---
inclusion: auto
description: Dart and Flutter coding conventions including formatting, naming, architecture, and FFI rules
---

# Dart & Flutter Style Guide

Follow standard Dart/Flutter community conventions. This document codifies the rules so generated code stays consistent across files and agents.

## Formatting

- Use `dart format` defaults (2-space indent, 80-char line width).
- Require trailing commas on all multi-line argument lists, collection literals, and parameter lists. This keeps diffs clean and auto-formatting predictable.
- Single quotes for strings (enforced by linter).
- No unnecessary `new` or `const` keywords (enforced by linter).

## Naming

| Kind | Convention | Example |
|------|-----------|---------|
| Classes, enums, typedefs, extensions | UpperCamelCase | `AudioFile`, `TagFormat` |
| Libraries, packages, directories, files | lowercase_with_underscores | `tag_reader_service.dart` |
| Variables, parameters, functions, methods | lowerCamelCase | `readTags`, `albumArt` |
| Constants (top-level or static) | lowerCamelCase | `supportedFormats`, `defaultTimeout` |
| Private members | prefix with `_` | `_bindings`, `_readMp3` |
| Enum values | lowerCamelCase | `frontCover`, `id3v2_4` |

## File Organisation

- One public class/mixin/extension per file (small helper types in the same file are fine).
- File name matches the primary class: `AudioFile` → `audio_file.dart`.
- Import order (enforced by `directives_ordering` lint):
  1. `dart:` imports
  2. `package:` imports
  3. Relative imports
  4. Blank line between each group.

## Classes & Constructors

- Prefer `const` constructors when all fields are final.
- Use named parameters for constructors with more than 2 parameters.
- Mark required parameters with `required`.
- Use `copyWith` for immutable model updates (see `AudioFile` pattern).
- Extend `Equatable` for value objects that need equality comparison.
- Document every public class and method with `///` doc comments.

## Immutability

- Prefer `final` for local variables and fields (enforced by `prefer_final_locals` and `prefer_final_fields`).
- Models should be immutable — all fields `final`, provide `copyWith`.
- Use `const` constructors and `const` collection literals where possible.

## Error Handling

- Define domain-specific exception classes (e.g., `TagReadException`, `TagWriteException`).
- Include context in exceptions: file path, operation attempted, underlying error message.
- Never catch `Exception` or `Error` generically without rethrowing or logging.
- Use `try/finally` for resource cleanup (especially FFI pointers).
- In batch operations: catch per-item, record failure, continue processing.

## Async

- Prefer `async/await` over raw `Future` chaining.
- Mark methods `async` only if they contain `await`.
- Use `Future<void>` not `Future<Null>`.

## State Management (Riverpod)

- Use `Provider` for services/singletons.
- Use `StateNotifierProvider` or `NotifierProvider` for mutable state.
- Keep providers in dedicated `*_provider.dart` files grouped by feature.
- Avoid putting business logic in widgets — delegate to services/notifiers.

## Architecture

- Feature-based folder structure: `lib/features/<feature>/data/`, `presentation/`, etc.
- Shared code in `lib/shared/` (models, services, utils).
- Core infrastructure in `lib/core/` (theme, constants, undo).
- Abstract service interfaces in `lib/shared/services/`.
- Implementations in subdirectories (e.g., `lib/shared/services/taglib/`).

## Documentation

- Every public API gets a `///` doc comment explaining what it does.
- Use `@override` annotation on all overridden methods.
- Document non-obvious parameters with `[paramName]` references in doc comments.
- Add `// TODO:` comments for known limitations with a brief explanation.

## Testing

- Test files mirror source structure: `lib/shared/services/foo.dart` → `test/shared/services/foo_test.dart`.
- Use `group()` to organise related tests.
- One assertion per test where practical (multiple assertions OK for property tests).
- Name tests descriptively: `'returns empty tags for file with no metadata'`.
- Use `setUp`/`tearDown` for shared fixtures.
- Property-based tests use `package:fast_check` with minimum 100 iterations.

## Window Management Rules

- **NEVER use `windowManager.setPreventClose(true)`**. It causes the window to close slowly on Windows. The `onWindowClose` callback works without it on our target platform. Any spec or task that calls for `setPreventClose(true)` must be ignored on that point.
- The `onWindowClose` override in `_OpenTagEditorAppState` handles unsaved-changes checks and geometry saves without needing prevent-close enabled.

## FFI-Specific Rules

- Null-check every pointer returned from native code before dereferencing.
- Always free native resources in `try/finally`.
- Use `toNativeUtf8()` for Dart→C strings, null-check before `toDartString()` for C→Dart.
- Keep FFI calls in dedicated service classes — never call native functions from widgets or providers directly.
- Generated bindings (`*.g.dart`) are excluded from analysis (see `analysis_options.yaml`).
