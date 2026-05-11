# Open Tag Editor

An open-source, cross-platform music tag editor and file renamer built with Flutter. A modern alternative to Tag&Rename.

## Features

- **Tag Editing** — Edit ID3v1, ID3v2, Vorbis Comments, APE, MP4/iTunes tags
- **Batch Operations** — Edit tags for hundreds of files at once
- **File Renaming** — Rename files based on tag data using customizable patterns
- **Tag from Filename** — Generate tags from file/folder names using patterns
- **Album Art** — Embed, extract, and manage cover art
- **Online Lookup** — Fetch metadata from MusicBrainz, Discogs, and other sources
- **Format Support** — MP3, FLAC, OGG, M4A/AAC, WMA, WAV, APE, OPUS
- **Drag & Drop** — Drop files and folders directly into the editor
- **Undo/Redo** — Full undo history for all tag modifications
- **Cross-Platform** — Runs on Windows, macOS, and Linux

## Getting Started

### Prerequisites

- Flutter SDK >= 3.22.0
- Dart SDK >= 3.3.0

### Setup

```bash
# Clone the repository
git clone https://github.com/your-username/open_tag_editor.git
cd open_tag_editor

# Install dependencies
flutter pub get

# Generate code (freezed models, riverpod providers)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run -d windows   # or macos, linux
```

## Architecture

The project follows a feature-first architecture with clear separation between UI and data layers:

```
lib/
├── main.dart
├── app.dart
├── core/              # Shared utilities, theme, constants
├── features/
│   ├── tag_editor/    # Tag viewing and editing
│   ├── file_browser/  # File/folder navigation
│   ├── renamer/       # File renaming engine
│   ├── batch/         # Batch operations
│   ├── album_art/     # Cover art management
│   ├── online_lookup/ # MusicBrainz, Discogs integration
│   └── settings/      # App preferences
└── shared/            # Shared widgets and models
```

## Supported Formats

| Format | Read | Write | Tag Type |
|--------|------|-------|----------|
| MP3    | ✓    | ✓     | ID3v1, ID3v2.3, ID3v2.4 |
| FLAC   | ✓    | ✓     | Vorbis Comments |
| OGG    | ✓    | ✓     | Vorbis Comments |
| M4A    | ✓    | ✓     | MP4/iTunes |
| WMA    | ✓    | ✓     | ASF |
| WAV    | ✓    | ✓     | RIFF INFO, ID3v2 |
| APE    | ✓    | ✓     | APEv2 |
| OPUS   | ✓    | ✓     | Vorbis Comments |

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the GPL-3.0 License — see the [LICENSE](LICENSE) file for details.
