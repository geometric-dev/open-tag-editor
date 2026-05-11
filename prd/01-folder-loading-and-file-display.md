# PRD 01: Folder Loading & File Display

## Problem Statement

Users need to load a folder of audio files and immediately see a table of those files with their existing metadata (tags). This is the foundation of the entire workflow — every other feature depends on having files loaded and visible.

## Goals

- Let users select a folder and display all supported audio files with their tag metadata in a sortable table.
- Support recursive subfolder loading with a safety guard against accidentally loading massive directories.
- Keep the UI responsive even with hundreds of files.

## Functional Requirements

### Folder Selection
- User can select a folder via a system folder picker dialog.
- User can drag-and-drop a folder onto the app to load it.
- The selected path is displayed in an address bar for reference.
- Recent folders are remembered for quick re-access.

### Recursive Loading
- A toggle/option to load subfolders recursively.
- When recursive loading would exceed a threshold (configurable, default ~500 files), prompt the user for confirmation before proceeding. Display the detected count.
- If the user declines, fall back to loading only the top-level folder.

### File List Table
- Display all supported audio files (MP3, FLAC, OGG, M4A, WMA, WAV, AIFF, APE, OPUS — see `supported_formats.dart`).
- Columns (user can show/hide and reorder):
  - Tag indicator icon — a small icon showing whether the file contains metadata tags. Visually distinguishes: has tags (e.g., filled tag icon), no tags (empty/grey icon). Tooltip shows the tag format detected (ID3v1, ID3v2.3, ID3v2.4, Vorbis Comment, APE, etc.).
  - Filename
  - Artist
  - Title
  - Album
  - Year
  - Genre
  - Track #
  - Disc #
  - Bitrate
  - Duration
  - Album Artist
  - Comment
  - BPM
  - Composer
  - Conductor
  - File path (relative to loaded root)
- Sortable by any column (click header to toggle asc/desc).
- Multi-select support (Ctrl+click, Shift+click, Ctrl+A).
- Status bar showing: total files, selected files count, total duration, selected duration, total size.

### Metadata Reading
- Tags are read on load using the tag reader service.
- Reading happens asynchronously so the UI remains responsive.
- Files that fail to read display an error indicator in their row rather than crashing the load.

### Filtering
- A quick-filter text box that narrows the visible list by matching against any visible column.
- Option to show/hide selected files only.

## Non-Functional Requirements

- Loading 500 files should complete initial display within 3 seconds on a modern machine.
- Table should remain scrollable and responsive during background tag reading.
- Memory usage should stay reasonable for libraries up to ~5,000 files.

## Dependencies

- **PRD 00 (TagLib FFI Integration)** — Tag reading for all formats depends on the TagLib FFI layer being in place. The tag indicator icon and all metadata columns require reliable cross-format tag reading.

## Out of Scope (for this PRD)

- Editing tags (covered in Multi File Tag Editor).
- Renaming files (covered in PRD 02).
- Web lookup (covered in PRD 04).
- Folder tree navigation (may be added later; for now, a flat folder picker is sufficient).
