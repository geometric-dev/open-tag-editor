# PRD 18: Tag Deletion & Cleanup (P2)

## Status: shipped, with two parts blocked

Delivered (Tools menu, all undoable):

- **Clear All Tags…** — confirms with real counts, and names the ReplayGain
  values when any are in scope.
- **Clear Fields…** — lists only fields that carry a value, marks partial
  fields `in N of M files`, live affected-file preview.
- **Remove ID3v1 Tag** — strips the 128-byte trailer, reports
  modified / skipped / errors.

Not delivered, and why:

- **Whole-block removal of ID3v2, APEv2 and Vorbis Comments.** The bundled
  `native/taglib_c.h` exposes no removal call at all — only
  `taglib_property_set`, which addresses fields rather than blocks. This
  needs a native change and a rebuilt `tag.dll`. Clearing a *field* works;
  removing a whole *format* does not, and the UI says so rather than
  pretending otherwise.
- **Right-click context menu on grid rows.** The grid is custom-painted and
  has no context menu today. PRD 12 also wants one, so it is better built
  once for both.
- **Background progress overlay for large batches.** The clears route
  through the existing save path, which already runs writes off the UI
  thread; a separate progress dialog would duplicate that.

## Problem Statement

Users frequently need to strip tags from files — either removing all metadata to start fresh before applying online data, removing specific unwanted tag fields, or cleaning up legacy tag formats (e.g., removing APEv2 tags from MP3 files that should only have ID3v2, or stripping ID3 tags from FLAC files that should only use Vorbis Comments). Currently there is no explicit operation for tag removal or format cleanup.

## Goals

- Provide clear, intentional operations for removing tags from audio files.
- Support both bulk removal (clear all tags) and selective removal (specific fields or tag formats).
- Ensure safety through preview and undo support.

## Functional Requirements

### Clear All Tags
- "Clear All Tags" action available via right-click context menu and Edit menu on selected files.
- Removes all metadata fields from the selected files, leaving only audio data.
- Confirmation dialog: "This will remove all metadata from X file(s). This operation is undoable. Continue?"
- Operation is registered with `UndoRedoManager` (stores previous tag state for restoration).
- Audio properties (duration, bitrate, sample rate) remain readable after clearing (they come from the audio stream, not tags).

### Clear Specific Fields
- "Clear Fields..." action opens a dialog listing all tag fields present across the selected files.
- User checks which fields to remove (e.g., Comment, BPM, Composer).
- Fields present in some but not all selected files are shown with a partial indicator.
- "Select All" / "Select None" convenience buttons.
- Preview shows which files will be affected and what values will be removed.
- Operation is undoable.

### Remove Tag Format
- "Remove Tag Format..." action for format-level cleanup:
  - **MP3 files**:
    - Remove ID3v1 tags (keep ID3v2)
    - Remove APEv2 tags (keep ID3v2)
    - Remove ID3v2 tags (keep ID3v1) — with strong warning
  - **FLAC files**:
    - Remove ID3 tags (keep Vorbis Comments)
  - **Other formats**: show only applicable options.
- This removes the entire tag block of the specified format, not individual fields.
- Useful for cleaning up files that have accumulated redundant tag formats from different tools.
- Confirmation dialog explains what will be removed and what will be preserved.
- Operation is undoable.

### Batch Operations
- All three operations (clear all, clear fields, remove format) work on multi-file selections.
- Progress indicator for large batches.
- Summary after completion: X files modified, Y skipped (read-only or locked), Z errors.

### Safety
- Files are written using the atomic write mechanism from PRD 00 (temp file + rename).
- Backup option (from PRD 00 settings) applies to tag deletion operations.
- Dry-run validation before committing changes.
- If a file only has one tag format and the user tries to remove it, warn that this will leave the file with no metadata at all.

## Non-Functional Requirements

- Clearing tags from 100 files should complete within 10 seconds.
- The field selection dialog should load within 500ms even for 500 selected files (scan fields in background).

## Dependencies

- **PRD 00 (TagLib FFI Integration)** — Tag deletion requires TagLib's ability to remove specific tag formats and clear fields while preserving audio data.
- **PRD 01 (Folder Loading & File Display)** — Files must be loaded and selected.

## Out of Scope

- Tag format conversion (e.g., converting ID3v2.3 to ID3v2.4) — TagLib handles this implicitly when writing; explicit conversion is a separate concern.
- Removing non-tag data from files (e.g., padding, junk bytes) — that's file repair, not tag management.
- Removing embedded lyrics (could be added later as lyrics are a specific frame type).
