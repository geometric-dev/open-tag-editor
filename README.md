# Open Tag Editor

An open-source music tag editor and file renamer built with Flutter (Windows today; macOS/Linux experimental).

## Features

- **Tag Reading & Writing** — Read and write tags across all major audio formats via native TagLib FFI integration. Atomic writes with optional backup ensure your files are never corrupted.
- **Batch Editing** — Select multiple files and edit shared tag fields in one operation. All changes are undoable.
- **File Renaming** — Rename files based on tag data using customizable mask patterns (e.g., `%artist - %album/%track - %title`). Live preview before committing.
- **Tags from Filename** — Extract tag values from file and folder names using the same mask syntax in reverse.
- **Online Metadata Lookup** — Search MusicBrainz, Discogs, and AcoustID (audio fingerprinting) to find and apply correct metadata and cover art.
- **Album Art** — View, add, remove, and export embedded cover art. Drag-and-drop and clipboard paste support.
- **Inline Cell Editing** — Double-click cells in the grid to edit tags directly, with Tab navigation and batch apply.
- **Resizable Columns** — Drag column borders to resize; double-click to auto-fit. Widths persist across sessions.
- **Undo/Redo** — Full undo history for all tag modifications and rename operations.
- **Cross-Platform** — Runs natively on Windows, macOS, and Linux.

## Supported Formats

| Format | Read | Write | Tag Type |
|--------|------|-------|----------|
| MP3    | ✓    | ✓     | ID3v1, ID3v2.3, ID3v2.4 |
| FLAC   | ✓    | ✓     | Vorbis Comments |
| OGG    | ✓    | ✓     | Vorbis Comments |
| Opus   | ✓    | ✓     | Vorbis Comments |
| M4A/AAC| ✓    | ✓     | MP4/iTunes atoms |
| WMA    | ✓    | ✓     | ASF |
| WAV    | ✓    | ✓     | RIFF INFO, ID3v2 |
| APE    | ✓    | ✓     | APEv2 |

## Windows Prerequisites

End-user machines need the [Microsoft Visual C++ 2015-2022 Redistributable (x64)](https://aka.ms/vs/17/release/vc_redist.x64.exe) installed (the TagLib native library links against it). Release bundles stage these DLLs automatically; a future installer will bundle them too.

After building, verify the bundle layout:

```powershell
flutter build windows --release
powershell -ExecutionPolicy Bypass -File scripts/verify-release.ps1
```

macOS and Linux need TagLib built from source first — see
[docs/platforms.md](docs/platforms.md), or just run
`bash scripts/build-taglib.sh`.

## Screenshots

*Coming soon*

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) >= 3.22.0
- Dart SDK >= 3.3.0

### Build & Run

```bash
# Clone the repository
git clone https://github.com/your-username/open-tag-editor.git
cd open-tag-editor

# Install dependencies
flutter pub get

# Run the app
flutter run -d windows   # or: -d macos, -d linux
```

> The generated TagLib FFI bindings (`lib/shared/services/taglib/taglib_bindings.g.dart`)
> are produced with [ffigen](https://pub.dev/packages/ffigen) and gitignored.
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
│   └── settings/              # App preferences
└── shared/
    ├── models/                # AudioFile, RenamePattern
    └── services/              # TagLib FFI reader/writer, rename service
```

### Key Technologies

- **Flutter** — Desktop UI framework
- **Riverpod** — Reactive state management
- **dart:ffi + TagLib** — Native C library for safe, cross-format tag I/O
- **ffigen** — Generates Dart FFI bindings from C headers

### Native Libraries

TagLib shared libraries are bundled per platform:

| Platform | Library |
|----------|---------|
| Windows  | `windows/taglib_c.dll` |
| macOS    | `macos/Frameworks/libtaglib_c.dylib` |
| Linux    | `linux/lib/libtaglib_c.so` |

## Roadmap

### Completed

- [x] **TagLib FFI Integration** — Native tag reading/writing for all formats with atomic writes and backup
- [x] **Folder Loading & File Display** — Folder picker, recursive loading, sortable data grid, multi-select, status bar
- [x] **Online Metadata Lookup** — MusicBrainz/Discogs search, AcoustID fingerprinting, Cover Art Archive, track matching
- [x] **File Renaming (basic)** — Rename by pattern with preset selector, live preview, batch execution
- [x] **Inline Cell Editing** — Double-click to edit, Tab/Enter navigation, batch apply, undo integration
- [x] **Column Resize** — Drag-to-resize headers, double-click auto-fit, persisted widths
- [x] **Album Art Management** — Add/remove/export cover art, drag-and-drop, batch operations

### In Progress

- [ ] **File Renaming (complete)** — Full-path masks with folder creation, user-defined presets, case transforms, conflict resolution UI, undo support
- [ ] **Tags from Filename** — Parse filenames/paths into tag fields using mask patterns, preview, write with overwrite/fill-empty options

### Planned

- [ ] **Unsaved Changes Protection** — Close/load confirmation dialogs, window title dirty indicator, "confirm before saving" setting
- [ ] **Keyboard Navigation** — Arrow keys, Page Up/Down, Home/End, Shift-select, action shortcuts (F2, F5, Delete)
- [ ] **Settings Completeness** — Wire all preference stubs (ID3v2 version, encoding, write ID3v1, default patterns)
- [ ] **Error Handling & Feedback** — Toast/snackbar system, error log panel, per-file failure reporting, retry actions
- [ ] **Empty State & Onboarding** — First-run guidance, format support info, setup prompts for API keys
- [ ] **Window State Persistence** — Remember window size/position, panel open/closed state, splitter positions
- [ ] **Accessibility & Theming** — High-contrast theme, user font scaling, text labels for toolbar, screen reader semantics
- [ ] **Drag-and-Drop Enhancements** — Column reorder via drag, track reorder in lookup dialog
- [ ] **Tag Deletion & Cleanup** — Bulk remove specific tag types, strip ID3v1, clean empty frames
- [ ] **ReplayGain Handling** — Read/display/preserve ReplayGain values
- [ ] **Multi-Value Tag Editing** — Support multiple artists, genres, and other multi-value fields
- [ ] **Online Lookup Enhancements** — Improved matching heuristics, result caching, batch fingerprinting

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
