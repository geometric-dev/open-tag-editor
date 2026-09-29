# Changelog

All notable changes to Open Tag Editor are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/) while pre-1.0.

## [Unreleased]

### Added — Tag&Rename parity wave
- **GNUdb lookup** (freedb successor): matches selected album tracks by a
  virtual CD table-of-contents computed from durations; new source chip in
  the lookup dialog.
- **Export wizard formats**: true `.xlsx` via a dependency-free ZIP+OOXML
  writer (inline strings, numeric cells, CRC-checked archive), alongside
  CSV (RFC-4180 + BOM) and HTML.
- **Tags Synchronization wizard**: dialog with direction choice, MP3
  count, fill-preview, and results summary over the new ID3v1 codec
  (v1.1 track byte, Latin-1-safe encoding, in-place replace).
- **Cover art resize/convert**: batch downscale to a max dimension and
  convert JPEG/PNG through the pure-Dart `image` package; single undoable
  command restores every original.
- **Tools menu** hosting transforms, cover-art resize, and sync wizard;
  artist case tools are undoable per-file delta commands.
- `.cdg` karaoke companions now follow their audio file on rename.
- Multi-value tag properties join with `; ` on read instead of silently
  dropping all but the first value.

### Added — release engineering
- `scripts/build-taglib.sh` builds the TagLib C bindings from upstream
  source (universal on macOS) into the location each platform's packaging
  expects, so no prebuilt blob has to be trusted or committed.
- `scripts/bundle-crt.ps1` stages the Microsoft Visual C++ runtime into a
  Windows bundle from a licensed toolchain payload, and refuses to
  redistribute the System32 copy.
- `scripts/verify-release.sh` is the POSIX counterpart to the existing
  Windows verifier: it checks the native library's location, architecture
  agreement with the app binary, and that its dependencies actually resolve.
- macOS ships a universal `libtaglib_c.dylib` via a new "Embed TagLib"
  Xcode build phase that runs *before* Flutter's signing phase, so the
  library is covered by the bundle signature.
- Linux packaging installs `libtaglib_c.so` next to the executable (the
  loader's first probe) and the bundle rpath is `$ORIGIN/lib`.
- CI: `format` and `analyze` gates, tests on Windows and Linux, and
  verified release bundles for Windows, macOS and Linux uploaded as
  artifacts. macOS/Linux TagLib is rebuilt from source on every run.

### Changed
- SDK floor raised to Flutter 3.41 / Dart 3.10 (the version that replaced
  the APIs this project now uses) and the tree reformatted for the
  modern tall-style formatter; the tree is now analyzer-clean including
  lints, which CI enforces.

### Fixed
- ID3v1 `_hasTag` read its signature from the wrong offset, breaking
  replace-in-place; append mode no longer resurrects deleted files.
- Toolbar folder/file pickers used `BuildContext` after an `await` without
  re-checking `mounted`.


## [0.2.0] - 2026-08-23

Quality and trust release: single save path, background-isolate I/O,
verified Windows packaging, ReplayGain-preservation proof, completed
keyboard navigation, and an enforced CI gate.

### Fixed
- Installed Windows releases silently disabled tag writing: the installer
  placed `taglib_c.dll` under `data\` while the loader only probed the
  executable directory. Loader now probes ordered candidates per platform;
  installers place libraries correctly (verified against a real build).
- Ctrl+S swallowed write failures entirely; all four save entry points now
  share one `TagSaveService` and record failures in the error log.
- Quick switcher rows triggered the framework's invisible-ink assertion
  (19 failing tests).
- Toolbar "Open Folder" bypassed the recursive toggle, threshold guard and
  recent-folder persistence; all load entry points share one service.
- Toolbar no longer hard-codes Segoe UI; each platform uses its system font.
- Provider equality: `AudioFile` now includes tags/art in `==`, preventing
  missed rebuilds on tag-only changes.

### Added
- Keyboard navigation: PageUp/PageDown (move + Shift-extend, edge-clamped),
  Home/End (+Shift), Enter-to-edit, and scroll-follow for the active row.
- Column reorder via header context menu (Move Left/Right), persisted.
- Theme mode setting (System/Light/Dark); backup toggle now persists.
- Session error log records online-lookup failures (informational,
  non-retryable by design) instead of losing them when the dialog closes.
- GitHub Actions CI: analyze on Windows/Linux/macOS runners, tests on
  Windows; committed ffigen bindings so fresh clones compile.
- Tests: TagSaveService, AtomicWriteManager, ValidationEngine, rename
  executor integration, extractor write commands, selection paging, and
  REAL-TagLib round-trip/preservation suites (auto-skip without DLL).

### Changed
- Folder loading runs on a background isolate (`Isolate.run`); bulk saves
  execute atomic writes + validation off the UI thread via settings
  snapshots. Single-file operations stay interactive.
- Removed dead code (pure-Dart writer moved to test fixtures) and unused
  dependencies (freezed/json/riverpod-generator/mockito/logging/etc.).

### Docs
- Honest platform support table + `docs/platforms.md` build guide.
- `docs/2026-08-23-project-review.md`: full architecture/quality review.
- `scripts/verify-release.ps1` bundle checks incl. VC++ runtime warning.

## [0.1.0] - initial public baseline
