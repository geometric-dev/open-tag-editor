# PRD 02: File Renaming via Mask

## Problem Statement

Users with large music libraries need to quickly rename (and optionally relocate) audio files into a consistent naming convention derived from their metadata tags. This must support full path masks so files can be moved into an organized folder hierarchy in a single operation.

## Goals

- Let users define a filename mask using tag variables to batch-rename selected files.
- Support full-path masks that create folder structures and move files to their final location.
- Provide a live preview before committing changes.
- Include case transformation and character replacement options.

## Functional Requirements

### Mask Definition
- A text input where users type a mask pattern using variables:
  - `%artist` — Artist
  - `%title` — Title
  - `%album` — Album
  - `%year` — Year
  - `%genre` — Genre
  - `%track` — Track number (zero-padded)
  - `%disc` — Disc number
  - `%albumartist` — Album Artist
  - `%comment` — Comment
  - `%bpm` — BPM
  - `%composer` — Composer
  - `%conductor` — Conductor
  - `%filename` — Original filename (without extension)
  - `%ext` — File extension
  - `%ignore` — Skip/discard a segment (useful in "tags from filename" inverse)
- Mask can include folder separators (e.g., `D:\Music\%artist\%year - %album\%track - %title`).
- A "Mask Editor" button opens a helper dialog for building masks visually.
- Saved mask presets — users can save, name, and recall frequently used masks.

### Path & Folder Creation
- If the mask contains directory separators, the rename operation creates any missing folders.
- Files are moved to the new path (not copied — the original is removed).
- If a target filename already exists, prompt the user (skip, overwrite, or auto-increment).

### Preview
- A "Preview" action shows a two-column list: current filename → new filename.
- Conflicts (duplicate targets) are highlighted.
- Files where the mask produces an empty or invalid filename are flagged.

### Case Options
- Checkbox: Replace underscores with spaces.
- Case transformation radio group:
  - None (as-is from tag)
  - lowercase
  - UPPERCASE
  - Capitalize First Letter (of each word)
  - Capitalize first word (sentence case)

### Rename Execution
- "Rename" button applies the rename to all selected (or all visible) files.
- Operation is undoable (undo moves files back and restores original names).
- Progress indicator for large batches.
- Summary after completion: X files renamed, Y skipped, Z errors.

### Safety
- Refuse to rename if the resulting path exceeds OS path length limits.
- Warn if the target directory is outside the currently loaded folder (since files will "disappear" from the list).
- Dry-run validation before any filesystem changes.

## Non-Functional Requirements

- Preview generation for 500 files should be near-instant (<1 second).
- Rename of 500 files (in-place, no move) should complete within 10 seconds.
- Undo history persists for the session (lost on app close).

## Out of Scope

- Renaming based on web-fetched metadata (user must populate tags first via PRD 04, then rename).
- Regex-based renaming (mask variables are sufficient for the target audience).
