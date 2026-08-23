# Architecture

A feature-first Flutter desktop application. This document maps the layers,
the key flows, and the invariants that keep them safe. Coding conventions
live in `.kiro/steering/dart-style-guide.md`.

## Layers

```
main.dart ──► app.dart ──► EditorKeyboardShortcuts ──► HomePage
core/        theme, constants, undo machinery (no feature imports!)
features/<f>/
  data/      models · notifiers(services) · providers · commands
  presentation/  pages · widgets
shared/      models · services (incl. taglib FFI) · widgets
```

Invariant: `core` never imports `features`. Feature-to-feature imports flow
"downhill" only where unavoidable (e.g. online_lookup → tag_editor providers).

## Key flows

### Folder load
`FolderLoadingService` (takes a `ProviderReader` tear-off, not a WidgetRef)
→ threshold guard dialog for large recursive scans → `FileUtils.listAudioFiles`
→ **background isolate**: `IsolateTagReaderService.readTagsBatch` spawns a
worker that rebuilds its own TagLib bindings; per-file failures come back as
`AudioFile.readError`, never exceptions. Grid items + folder separators are
derived purely via `gridItemsProvider`.

### Edit & undo
All edits are `UndoableCommand`s executed by the single `undoRedoProvider`
(cap 100). Commands mutate `FileListNotifier` and recompute `isModified`
against each file's `originalTags` on undo, so dirty-state stays truthful
across undo/save interleavings.

### Save (one path only)
Everything funnels through `TagSaveService.saveAllModified()`:
diff `modifiedTags` → `TagWriterService.writeTagsBatch` → successes marked
clean with refreshed originals → callers surface the returned summary
(status bar / snackbar / error log). Batch writes run on an isolate with a
plain-value settings snapshot (`TagWriteSettingsSnapshot`); each write is
atomic (temp+rename), optionally backed up (.bak), then re-read and
validated before success is reported.

### Rename / tags-from-filename
One mask grammar, two directions: `MaskParser → MaskEvaluator` builds names;
`MaskExtractor` decomposes paths. Renames go `dryRun → ConflictDetector →
RenameExecutor` (skip/overwrite/autoIncrement) wrapped in an undoable
`RenameCommand`.

### Online lookup
Wizard state machine in `LookupStateNotifier` (constructor-injected services,
rebuilt when settings change). Track↔file matching is order-based when counts
align, otherwise Hungarian assignment over a multi-signal score matrix.
Failures throw `LookupServiceException` (distinct from "no results") and land
in both the dialog state and the session error log as informational entries.

### Error handling
Bounded FIFO session log (500) + retry service. Retryable operations carry a
sealed `OperationContext`; online-lookup entries are informational-only and
are filtered from retry flows by `ErrorEntry.isRetryable`.

## Native layer rules

- FFI handles never cross isolates: workers rebuild bindings via
  `createPlatformTagReaderService()` / `createNativeTagWriterFromSnapshot()`.
- Every pointer freed in `finally`; strings via `toNativeUtf8`.
- Windows non-ASCII paths use 8.3 short-path conversion (`Win32ShortPath`).
- Library search paths must stay aligned with installer destinations —
  enforced by `scripts/verify-release.ps1` after every build.

## Testing strategy

Pure logic dominates: parsers, matchers, sanitizers, selection, navigation —
plus property tests with seeded PRNGs traced to spec requirements
(`Validates: Requirements X.Y`). Filesystem effects use temp directories.
The REAL native pipeline is exercised by
`test/shared/services/taglib/taglib_round_trip_test.dart`, which loads the
repo's Windows DLL and skips elsewhere — a green run there is meaningful,
not vacuous.
