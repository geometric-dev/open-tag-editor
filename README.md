# Open Tag Editor

An open-source music tag editor and file renamer built with Flutter, running
natively on Windows, macOS and Linux.

## Features

- **Tag Reading & Writing** — Read and write tags across all major audio formats via native TagLib FFI integration. Atomic writes with optional backup ensure your files are never corrupted.
- **Multi-Value Fields** — Multiple artists, genres, composers and more, written as genuine repeated tag values rather than one joined string. Edit them as removable chips.
- **Batch Editing** — Select multiple files and edit shared tag fields in one operation. All changes are undoable.
- **File Renaming** — Rename files based on tag data using customizable mask patterns (e.g., `%artist - %album/%track - %title`). Live preview before committing.
- **Tags from Filename** — Extract tag values from file and folder names using the same mask syntax in reverse.
- **Online Metadata Lookup** — Search MusicBrainz, Discogs, and AcoustID (audio fingerprinting) to find and apply correct metadata and cover art. A preserved-tags list keeps fields such as ReplayGain from being overwritten.
- **Album Art** — View, add, remove, and export embedded cover art. Drag-and-drop and clipboard paste support. Batch resize and format conversion, undoable.
- **ReplayGain** — Read-only display of track/album gain and peak, optional grid columns, and a dedicated clear action. Values are preserved across unrelated edits.
- **Tag Cleanup** — Clear all tags, clear selected fields across a selection, or strip the ID3v1 block. Every operation is undoable.
- **Inline Cell Editing** — Double-click cells in the grid to edit tags directly, with Tab navigation and batch apply.
- **Resizable, Reorderable Columns** — Drag column borders to resize, double-click to auto-fit, or drag headers to reorder. Layout persists across sessions.
- **Undo/Redo** — Full undo history for all tag modifications and rename operations.
- **Keyboard Navigation** — Arrows, Page Up/Down, Home/End, Shift-select, Ctrl+Arrow to move focus without collapsing the selection, Ctrl+Space, F2, and F5 to refresh from disk.
- **Accessibility** — High-contrast themes, adjustable text scaling, and screen-reader semantics on the grid and status bar.
- **Cross-Platform** — Windows, macOS and Linux builds are produced and structurally verified on every push.

## Supported Formats

All read and write, via TagLib:

| Format | Tag Type |
|--------|----------|
| MP3 | ID3v1, ID3v2.3, ID3v2.4 |
| FLAC, OGG, Opus, Speex | Vorbis Comments |
| M4A, M4B, M4R, M4V, MP4, AAC | MP4/iTunes atoms |
| WMA | ASF |
| WAV | RIFF INFO, ID3v2 |
| APE, MPC, WavPack, TTA, OFR, DSF | APEv2 / Musepack / WavPack |

## Prerequisites

Release bundles include the Microsoft Visual C++ runtime that TagLib
links against, so no redistributable install is needed on a machine that
ran the installer or downloaded a CI artifact.

After building, verify the bundle layout:

```powershell
flutter build windows --release
powershell -ExecutionPolicy Bypass -File scripts/verify-release.ps1
```

macOS and Linux build TagLib from source — run
`bash scripts/build-taglib.sh`, or let CI do it. See
[docs/platforms.md](docs/platforms.md).

## Screenshots

*Coming soon*

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-platform/install) **3.41 or newer** (3.47.5 is pinned in `.fvmrc`; use it via [FVM](https://fvm.app) or the Flutter VS Code extension, both of which read that file)
- CMake and a C++ toolchain — required on every platform to build the native runner
- CMake only, plus `git` and curl, to regenerate the FFI bindings

The SDK version is pinned deliberately: `dart format` is not stable across
SDK releases, so a mismatch can make CI's format gate fail on files you never
touched. See [CONTRIBUTING.md](CONTRIBUTING.md#toolchain-version).

### Build & Run

```bash
# Clone the repository
git clone https://github.com/geometric-dev/open-tag-editor.git
cd open-tag-editor

# Install dependencies
flutter pub get

# Run the app
flutter run -d windows   # or: -d macos, -d linux
```

> The TagLib FFI bindings (`lib/shared/services/taglib/taglib_bindings.g.dart`)
> are **committed**, so a fresh clone builds without a native toolchain step.
> They are only regenerated when `native/taglib_c.h` changes:
>
> ```bash
> dart run ffigen --config native/ffigen.yaml
> ```
```

### Release Build

```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

## Architecture

The project uses a feature-first architecture with Riverpod for state management:

```
lib/
├── main.dart                  # App entry point
├── app.dart                   # MaterialApp configuration
├── core/                      # Theme, constants, undo system, utilities
├── features/
│   ├── tag_editor/            # File list grid, tag edit panel, folder loading
│   ├── renamer/               # File renaming via mask patterns
│   ├── extractor/             # Tags-from-filename extraction
│   ├── online_lookup/         # MusicBrainz, Discogs, AcoustID integration
│   ├── album_art/             # Cover art management
│   ├── tools/                 # Batch utilities: tag cleanup, ReplayGain, ID3v1 sync
│   ├── error_handling/        # Session error log, retry service, details panel
│   ├── folder_panel/          # Bookmarks, recent folders, sibling navigation
│   └── settings/              # App preferences
└── shared/
    ├── models/                # AudioFile, RenamePattern, rename results
    ├── services/              # TagLib FFI reader/writer, ID3v1 codec, export
    └── widgets/               # Save flow, unsaved-changes guard, shared UI
```

### Key Technologies

- **Flutter** — Desktop UI framework
- **Riverpod** — Reactive state management
- **dart:ffi + TagLib** — Native C library for safe, cross-format tag I/O
- **ffigen** — Generates Dart FFI bindings from C headers

### Native Libraries

TagLib's C bindings are loaded at runtime by `dart:ffi`:

| Platform | Library | Provided by |
|----------|---------|-------------|
| Windows  | `windows/taglib_c.dll`, `windows/tag.dll` | committed; installed next to the executable by the CMake build |
| macOS    | `macos/Frameworks/libtaglib_c.dylib` | built from source by `scripts/build-taglib.sh`, embedded by an Xcode phase |
| Linux    | `linux/lib/libtaglib_c.so` | built from source by `scripts/build-taglib.sh`, installed by `linux/CMakeLists.txt` |

Only the Windows binaries are committed. macOS and Linux are compiled from
upstream TagLib on each CI run, so no prebuilt blob from an unverified source
is ever shipped. Without the library the app still runs — it falls back to a
pure-Dart reader and **disables writing**.

## Roadmap

### Completed

Core features (PRDs 00–19 all shipped; see `prd/done/`):

- [x] **TagLib FFI Integration** — Native tag reading/writing for all formats, atomic writes, backup
- [x] **Folder Loading & File Display** — Folder picker, recursive loading, sortable grid, multi-select, status bar
- [x] **Online Metadata Lookup** — MusicBrainz/Discogs/GNUdb search, AcoustID fingerprinting, track matching, before/after comparison
- [x] **File Renaming** — Full-path masks, folder creation, user-defined presets, case transforms, conflict resolution, undo
- [x] **Tags from Filename** — Mask-based extraction with overwrite/fill-empty modes
- [x] **Inline Cell Editing** — Double-click to edit, Tab/Enter navigation, batch apply, undo
- [x] **Columns** — Drag-to-resize, auto-fit, persisted widths, and drag-to-reorder
- [x] **Album Art Management** — Add/remove/export, drag-and-drop, clipboard paste, batch resize/convert
- [x] **Unsaved Changes Protection** — Close/load guards, dirty title indicator, per-cell marker, confirm-before-save setting
- [x] **Keyboard Navigation** — Arrows, Page Up/Down, Home/End, Shift-select, Ctrl+Arrow, Ctrl+Space, F2, F5
- [x] **Settings Completeness** — All preferences wired and persisted
- [x] **Error Handling** — Snackbar notifications, session error log, details panel, per-file retry
- [x] **Empty State & Onboarding** — Open actions, recent folders, format list, feature highlights
- [x] **Window State Persistence** — Geometry, panel visibility, splitter positions
- [x] **Accessibility & Theming** — High-contrast themes, text scaling, screen-reader semantics
- [x] **Drag-and-Drop** — File/folder drop onto the window, image drop, column reorder
- [x] **Tag Deletion & Cleanup** — Clear all tags, clear selected fields, strip ID3v1
- [x] **ReplayGain** — Read-only display, optional columns, preserved through edits, clear action
- [x] **Multi-Value Writing** — Real repeated tag values, separator detection, chip editor
- [x] **Online Lookup Enhancements** — Preserved-tags list, partial-match apply, confidence badges

### In Progress

- [ ] **Multi-Value Editing (complete)** — batch Set/Add/Remove/Replace across a selection, and a `×N` grid badge. Both need `AudioFile.tags` to hold `List<String>` for these fields, which is a cross-cutting model change.
- [ ] **Album Clustering** — group-by view over the grid for online lookup, collapsible group rows, fuzzy tolerance.

### Known Limitations

- **Whole-block tag removal.** Whole *fields* can be cleared and the ID3v1 block stripped, but removing an entire ID3v2, APEv2 or Vorbis block is not possible: the bundled `native/taglib_c.h` exposes only field-level `taglib_property_set`, with no removal call. Needs a native change and a rebuilt `tag.dll`.
- **ReplayGain cannot be calculated**, only displayed, preserved and cleared. Computing it requires decoding audio; use `loudgain`, `foobar2000` or `mp3gain`.
- **A signed installer** is not yet produced. Windows bundles include the VC++ runtime, so no redistributable install is needed, but the bundle is distributed unsigned.
- **ID3v1 replace-in-place appends on Linux** — see [docs/known-issues.md](docs/known-issues.md). Undiagnosed; the test is skipped on non-Windows rather than papered over.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

Quick start:
1. Fork the repo and create a feature branch
2. Run `dart format .` — formatting is enforced in CI
3. Run `flutter analyze` — zero issues allowed, including lints
4. Run `flutter test` — all tests must pass
5. Open a PR with a clear description

CI additionally builds release bundles for Windows, macOS and Linux, and
verifies each one. See [docs/platforms.md](docs/platforms.md).

## License

This project is licensed under the **GNU General Public License v3.0** — see [LICENSE](LICENSE) for details.
