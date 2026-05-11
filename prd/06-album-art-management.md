# PRD 06: Album Art Management (P1)

## Problem Statement

The Album Art tab in the Tag Edit Panel presents Add, Export, and Remove buttons but the Add and Remove operations are not wired to the tag writing service. Users see a functional-looking UI that silently does nothing, which erodes trust in the editor.

## Goals

- Complete the album art write/remove workflow so the UI delivers on its promise.
- Support batch album art operations across multiple selected files.
- Provide convenient input methods (file picker, drag-and-drop, clipboard paste).

## Functional Requirements

### Add Album Art
- Clicking "Add" opens a file picker filtered to image types (JPEG, PNG, BMP, GIF, WebP).
- Selected image is written to all currently selected audio files via `TagWriterService.writeAlbumArt`.
- Operation is registered with `UndoRedoManager` as a single undoable command.
- If multiple files are selected, art is applied to all of them.
- Progress indicator for batch operations.

### Remove Album Art
- Clicking "Remove" calls `TagWriterService.removeAlbumArt` on all selected files.
- Operation is undoable.
- Confirmation prompt before removing from multiple files.

### Drag-and-Drop
- Users can drag an image file onto the Album Art panel to set it as cover art.
- Visual drop zone indicator when dragging over the panel.

### Clipboard Paste
- Ctrl+V while the Album Art tab is focused pastes clipboard image data as cover art.
- If clipboard contains a file path to an image, read and embed that image.

### Image Preview
- Show resolution and dimensions alongside existing size/MIME info.
- Click to view full-size in a modal.

### Batch Indicator
- When multiple files are selected with different album art, show a "mixed" indicator.
- When multiple files are selected with the same art, show that art.

## Non-Functional Requirements

- Writing album art to 50 files should complete within 10 seconds.
- Image files larger than 5 MB should trigger a warning (large embedded art bloats files).

## Dependencies

- PRD 00 (TagLib FFI) — `writeAlbumArt` and `removeAlbumArt` are already implemented.

## Out of Scope

- Image editing (crop, resize) — users should prepare images externally.
- Multiple art types per file (back cover, leaflet, etc.) — front cover only for now.
