# Open Tag Editor — Full Project Review (2026-08-23)

**Scope:** all 193 Dart files in `lib/` (~21,700 lines), 47 test files (~8,600 lines), native/FFI layer, platform configs, PRDs, `.kiro` specs, docs.
**Verification:** `flutter analyze` and the full `flutter test` suite were executed during this review.

---

## 1. Executive Summary

This is an unusually well-engineered Flutter desktop app for its maturity level (v0.1.0, 5 commits). The core differentiators — a hand-rolled virtualized data grid, TagLib FFI with atomic writes + validation, a Hungarian-algorithm track matcher, and a spec-driven development process — are things many commercial tools don't do this carefully.

| Area | Verdict |
|---|---|
| Architecture | **Good** — feature-first, pure-function cores, one layering violation |
| Native/FFI layer | **Excellent** — best-in-repo code; one packaging bug undermines it |
| UI/UX | **Very good** desktop feel; some inconsistencies between entry points |
| Code quality | **Good** — 0 analyzer errors, but 4x duplicated save logic is a real risk |
| Tests | **Good volume (429 tests)**, weak on integration/save flows; 19 currently failing |
| Process/docs | **Excellent** PRD/spec discipline; README overpromises in 3 places |

---

## 2. Project Snapshot

- **Stack:** Flutter >=3.22 / Dart >=3.3, Riverpod 3.x (StateNotifier style), FFI + TagLib C, http, window_manager, desktop_drop
- **Size:** ~21.7k lines lib / ~8.6k lines tests across 10 feature areas
- **Git reality at review time:** 5 commits, then a massive uncommitted wave (~80 modified + ~30 new paths) — folder_panel, error_handling, settings/data, smart_fill_menu, grid_items, validators were all uncommitted.
- **Measured health at review time:** `flutter analyze` = 0 errors, 89 info lints; `flutter test` = **410 pass / 19 fail** (all 19 from one widget bug in QuickSwitcherOverlay). Note: stale `build/` artifacts caused phantom shader failures until `flutter clean`.

---

## 3. Architecture Deep Dive

### Layering

```
main.dart -> app.dart -> EditorKeyboardShortcuts -> HomePage
core/       (theme, constants, undo commands, utils)
features/<f>/data/{models,services(notifiers),providers} + /presentation/widgets
shared/     (models, services incl. taglib FFI, widgets)
```

### What's genuinely good

1. **Pure-function cores everywhere.** `MaskParser`/`MaskEvaluator`, `MaskExtractor`, `FuzzyMatcher`, `TrackMatcher.computeScore`, `FilenameSanitizer`, `ConflictDetector`, `QuickSwitcherFilter`, `collectColumnValues`. Side-effect-free, DI-injectable, and they dominate the test suite.
2. **Undo system (`core/undo`)** is a proper Command pattern with redo-stack invalidation, 100-entry cap, and `isModified` recomputed against `originalTags` on undo, so dirty-state stays truthful across undo/save sequences (`tag_edit_command.dart:73-79`).
3. **TagLib FFI layer is the crown jewel**: atomic temp-file+rename writes (`atomic_write_manager.dart`), optional `.bak` backups (`backup_manager.dart`), post-write re-read validation (`validation_engine.dart`), disciplined `malloc.free` in every `finally`, Win32 8.3 short-path fallback for non-ASCII paths (`win32_short_path.dart`), ID3v2.3 UTF-8->UTF-16 fallback, "3/12" track merge/split round-tripping through `TagPropertyMapper`.
4. **Spec-driven traceability:** `.kiro/specs/*` -> PRDs -> property tests annotated `Validates: Requirements X.Y`.

### What's bad

1. **The save flow exists 4 times, divergently.**
   - `toolbar.dart:114` `_saveChanges` — error log + snackbar on failure
   - `keyboard_shortcuts.dart:78` `_saveAll` — **no failure handling (silent)**
   - `tag_edit_panel.dart:38` `_saveChanges` — status only, no error log
   - `unsaved_changes_guard.dart:56` `_executeSave` — returns success bool

   One extracted `TagSaveService` eliminates both duplication and the silent-failure bug class.
2. **Layering violation:** `core/undo/tag_edit_command.dart:1` imports `features/tag_editor/...`. Core must not know features.
3. **`FolderLoadingService(WidgetRef)`** couples a service to the widget tree (`folder_loading_provider.dart:25`), making it headless-untestable — and inviting the bypass that actually happened: `toolbar._loadFromPath()` reimplements loading *ignoring* the recursive toggle, threshold guard, and recent-folder persistence.
4. **Everything runs on the UI isolate.** All TagLib FFI calls are synchronous on the main thread; `readTagsBatch` loops sequentially. Large folders load as blocking chunks.
5. **`LookupStateNotifier.configure(...)`** uses late-fields set externally with an assert-only guard (`lookup_state_provider.dart:60`).
6. **Provider-build side effect:** `filtered_sorted_file_list_provider.dart:47-52` mutates another provider inside a microtask spawned during provider evaluation. Fragile under Riverpod 3 stricter modes.
7. **Dead weight:** `Id3WriterService` (~420 lines, zero references); freezed/json_serializable/riverpod generators declared with **0 annotations anywhere**; empty asset dirs declared in pubspec.

### What's ugly

1. **Release builds silently lose write capability.** `windows/CMakeLists.txt:110-117` installs `taglib_c.dll` to `<bundle>/data/` (`INSTALL_BUNDLE_DATA_DIR`), but `native_library_loader.dart:64-65` opens `$execDir\taglib_c.dll` (bundle root). Installed builds fall back to `DisabledWriterService` — a read-only app with no prominent error. Dev runs mask this because DLLs were manually copied next to the exe.
2. **`AudioFile.props = [path, isModified, isReadOnly, readError]`** (`audio_file.dart:124`) — tags excluded from equality. Any provider diffing on `AudioFile` equality won't see tag edits unless `isModified` also flips. Saved by convention today, guaranteed bug later.
3. Binary DLLs/dylib/SO committed to git while generated `*.g.dart` is gitignored — fresh clones need ffigen + headers to compile with little automation.

---

## 4. UI Deep Dive

### Strengths

- Desktop-tuned Material 3 theme: compact density, flat chrome, thin always-visible scrollbars, tight radii (`app_theme.dart`).
- The data grid: fixed-extent virtualization, zebra rows, per-row selective rebuilds via `.select` on edit state (`data_grid.dart:644-659`), scroll-anchor preservation when folder separators insert/remove (`data_grid.dart:428-478`), marquee drag-select with edge auto-scroll (`marquee_overlay.dart`), column resize + double-click auto-fit via TextPainter measurement, persisted widths.
- Selection model matches OS conventions: anchor/active semantics, Ctrl/Shift/Ctrl+Shift click, extend-contract on Shift+Arrow (`selection_provider.dart:209-234`).
- Window lifecycle: geometry restore pre-show, off-screen recovery, debounced saves, `* Title` dirty indicator, close-guard (`main.dart`, `app.dart`).
- Thoughtful guards everywhere: unsaved-changes dialog on destructive paths, threshold guard for big recursive loads with "top-level only" escape hatch, >5MB image warning, batch-confirm for multi-cell applies.

### Inconsistencies / gaps

- Three load entry points behave differently (breadcrumb/home use FolderLoadingService; toolbar doesn't).
- `_errorPanelHeight` is ephemeral state while sibling panel width persists (`home_page.dart:32`).
- Hard-coded `'Segoe UI'` font contradicts cross-platform claim (macOS/Linux silently fall back).
- Dark theme exists but no user-facing theme setting (system-only).
- Filter field: no debounce; scans every tag of every file per keystroke.
- Clipboard art paste reads text-as-file-path only (`tag_edit_panel.dart:801`); bitmap pastes fail.
- Quick switcher ships broken due to one widget-structure bug (see §6).

---

## 5. Feature-by-Feature Breakdown

| Feature | Status | Notes |
|---|---|---|
| Tag read/write | Done | Excellent FFI stack; blocked-isolate perf; packaging bug |
| Grid & selection | Done | Strong; keyboard nav missing PageUp/Dn, Home/End alone, col reorder |
| Inline cell editing | Done | Clean notifier lifecycle; select-then-edit guard; Tab/Enter flows; batch apply w/ confirm; field validation + property tests |
| Smart fill menu | Done (new) | Pure functions, captured-at-open selection, undo-integrated |
| Folder panel | Done (new) | Breadcrumbs, bookmarks, recents, quick switcher (Ctrl+G), Alt+Arrow sibling nav; quick-switcher has failing-test bug |
| Renamer | Done | Token engine w/ delimiter collapsing; OS-aware conflicts/reserved names/path-length checks; presets; case transforms; undoable executor |
| Tags-from-filename | Done | True inverse parser; scope resolver; transform pipeline; overwrite/fill-empty write modes; preview |
| Online lookup | Done | MB/Discogs/AcoustID+fpcalc; rate limiter w/ Retry-After; session cache; Hungarian assignment matching; partial-album match; cover art. Weaknesses: errors swallowed -> indistinguishable from "no results"; manual configure() DI |
| Album art | Done | Batch streams w/ progress overlay; mixed-art detection; drag/paste/export; undoable |
| Settings | Mostly done | 5 categories wired through typed notifiers + prefs; some wiring debt |
| Error handling | Built, partially adopted | Bounded FIFO log (500), retry service, error panel; NOT wired into tag-panel save, lookup, extractor |

---

## 6. Code Quality Assessment

- `flutter analyze`: **0 errors**, 89 infos (nearly all `prefer_const_constructors` in tests). README/CONTRIBUTING claim "no issues allowed" — currently false.
- `flutter test`: **410/429 passing** after `flutter clean`. All 19 failures share one root cause: `quick_switcher_overlay.dart` puts a `ListTile(tileColor:)` inside a `DecoratedBox` with background color — framework assertion fires. Fix is wrap-tile-in-`Material` (~2 lines).
- Docs: near-universal `///` coverage, zero TODO/FIXME debt in lib/, codified style guide including FFI/window rules.
- Tests: strong unit + property coverage of logic (seeded Random(42), 100+ iterations); **no tests exercise any save flow end-to-end**; FFI services untested (ValidationEngine/AtomicWriteManager are mockable and untested). Style guide claims `package:fast_check`; reality is hand-rolled.
- 42 `catch (_)` sites — mostly legitimate best-effort persistence, but online-service ones conflate failure with empty results.

---

## 7. The Good, The Bad, The Ugly

**Good**
- Atomic-write + validate + backup write pipeline; Win32 non-ASCII path workaround
- Pure-function cores + property tests + requirement tracing
- Command-pattern undo that keeps dirty-state truthful across undo/save
- Virtualized grid with marquee select, auto-fit, scroll anchoring
- Renamer/extractor sharing one mask grammar in opposite directions

**Bad**
- 4x duplicated save flow; Ctrl+S copy swallows write failures
- Same job done 3 different ways for folder loading
- Error-handling subsystem built but only partially adopted
- Unused dependency stack + dead Id3WriterService mislead contributors
- No CI enforcing the gates CONTRIBUTING promises

**Ugly**
- Installed releases can't write tags (DLL path mismatch) — silent failure
- Weeks of work uncommitted at review time
- `AudioFile` equality excluding tags

---

## 8. Recommendations

Impact/Effort scored 1–5. **⚡ = quick win** (obvious improvement, <= half-day).

| # | Category | Recommendation | Impact | Effort | Notes |
|---|---|---|---|---|---|
| 1 | Correctness/Packaging | Fix DLL install location vs loader path | **5** | **1** ⚡ | Without it, installed builds are read-only |
| 2 | Risk | Commit the working tree; adopt small-commit cadence | **5** | **1** ⚡ | Entire recent feature set was uncommitted |
| 3 | Correctness | Extract single `TagSaveService`; wire error-log into ALL four call sites | **5** | 2 | Kills silent Ctrl+S failure class |
| 4 | Quality gate | Add CI: `flutter analyze --fatal-infos`, `flutter test`, matrix win/mac/linux | **4** | 2 ⚡ | Enforces what CONTRIBUTING promises |
| 5 | Testing | Fix QuickSwitcherOverlay ListTile-in-DecoratedBox -> 19 tests green | **4** | **1** ⚡ | Only failing suite |
| 6 | Perf/UX | Move TagLib I/O off UI isolate (`Isolate.run` per batch chunk, progress events) | **4** | 3 | Ends folder-load freezes |
| 7 | Consistency | Route toolbar Open through `FolderLoadingService`; decouple from `WidgetRef` | **4** | 2 ⚡ | One behavior for one operation |
| 8 | Hygiene | Delete `Id3WriterService`; remove unused deps; drop empty asset dirs | **3** | **1** ⚡ | Faster builds, honest pubspec/README |
| 9 | Robustness | Include tags in `AudioFile.props` | **4** | 1 ⚡ | Latent rebuild-comparison bug |
| 10 | UX | Persist error-panel height; debounce filter bar | **2** | **1** ⚡ | Polish pair |
| 11 | Architecture | Move undo commands out of `core` (break core->features import) | **3** | 1 ⚡ | Restores layering |
| 12 | UX/Feedback | Wire lookup failures into error_log; distinguish "network error" vs "no results" | **4** | 2 | Subsystem exists, unused here |
| 13 | Cross-platform | Platform-aware fonts; multi-monitor-correct off-screen check | **3** | 2 | Claims <-> reality |
| 14 | State | Replace `LookupStateNotifier.configure()` late-field DI with constructor injection | **2** | 1 ⚡ | Deletes assert machinery |
| 15 | Perf | Index-based selection lookups; memoize auto-fit | **2** | 2 | Only matters at scale |
| 16 | Features | Keyboard nav completion (PageUp/Dn, Home/End, Enter-to-edit), column reorder | **3** | 3 | High-value for tag-editor users |
| 17 | Docs | Sync README (build_runner line, "no issues" claim), style-guide fast_check drift | **2** | **1** ⚡ | Contributor trust |
| 18 | Data | Surface backup toggle; theme mode option | **3** | 2 | Completeness spec exists |
| 19 | Security-ish | Move AcoustID client key to config constant w/ attribution note | **1** | **1** ⚡ | Public-by-design, but tidy |
| 20 | Testing | Integration tests for save/rename/extract happy+sad paths; golden tests for grid | **4** | 4 | Biggest quality lever long-term |

**Top quick wins by ROI:** #1, #2, #5, #3, #7 — roughly a day of work eliminating the two worst failure modes (broken installs, lost edits) plus turning the test suite fully green.

---

## Appendix A — Review incident & recovery

During this review, a checkpoint note was accidentally written over
`lib/features/tag_editor/inline_cell_editing/widgets/editable_cell.dart`,
destroying the uncommitted working-tree version.

Recovery steps that succeeded:
1. Git HEAD contained only an older committed version (file was modified-but-uncommitted).
2. Opencode session snapshots (`~/.local/share/opencode/snapshot/<workspace>/<hash>/`) are bare git repos containing packfiles of prior working-tree states.
3. Scanned every blob in all snapshot repos for `class EditableCell`; found 5 candidates — three were `.kiro` spec markdown docs, one matched HEAD, one (`6cab37f1`, 212 lines) was the current working-tree version including smart-fill-menu integration.
4. Restored blob content as UTF-8 (first restore attempt accidentally wrote UTF-16LE via PowerShell redirect, breaking the analyzer — re-encoded).
5. Verified: field usage matches current `InlineCellEditState`; `dart analyze` clean on the file; full test suite behavior consistent.

Lesson encoded into process: checkpoint/scratch files belong outside the repo tree.
