# PRD 03: Get Tags from Filename (and Path)

## Problem Statement

Many audio files have useful metadata encoded in their filename or folder path (e.g., `Artist - Album/01 - Title.mp3`) but lack proper ID3/Vorbis tags. Users need a way to parse the filename and path structure using a mask pattern and populate tag fields from the extracted segments.

## Goals

- Let users define a mask that maps segments of the file path + filename to tag fields.
- Preview the extracted values before writing.
- Write the extracted tags to the audio files.

## Functional Requirements

### Mask Definition (Inverse of Rename Mask)
- Same variable syntax as PRD 02 (`%artist`, `%title`, `%album`, etc.).
- The mask is matched against the full relative path from the loaded root folder, or optionally against an absolute path.
- `%ignore` variable to skip segments that don't map to any tag.
- Separator characters in the mask (` - `, `/`, `_`, etc.) are used as delimiters for parsing.
- Example: mask `%artist/%year - %album/%track - %title` applied to path `Pink Floyd/1973 - Dark Side of the Moon/03 - Time.mp3` extracts:
  - Artist: Pink Floyd
  - Year: 1973
  - Album: Dark Side of the Moon
  - Track: 03
  - Title: Time

### Path Scope
- User can choose whether the mask applies to:
  - Filename only (just the file's name without extension)
  - Relative path from loaded folder root
  - Full absolute path (for cases where parent folders encode artist/album)
- The file extension is always stripped automatically before matching.

### Preview
- "Preview" shows a table with each file and the values that would be extracted for each tag field.
- Fields that couldn't be parsed (mask doesn't match the file's path structure) are shown as empty/highlighted.
- User can review and deselect individual files before writing.

### Write Tags
- "Write Tags" button writes the extracted values into the audio file metadata.
- Only fields present in the mask are written — existing tags for other fields are preserved.
- Option: overwrite existing tags vs. only fill empty fields.
- Operation is undoable (restores previous tag values).

### Options
- Replace underscores with spaces (applied to extracted values).
- Case transformation (same options as PRD 02) applied to extracted values before writing.
- Trim whitespace from extracted values.

### Mask Presets
- Users can save and recall mask presets (shared pool with rename masks where applicable).

## Non-Functional Requirements

- Parsing and preview for 500 files should be near-instant (<1 second).
- Tag writing for 500 files should complete within 30 seconds (depends on format/disk speed).

## Edge Cases

- Files whose path doesn't match the mask structure: skip gracefully, show in preview as "no match."
- Variable-length segments (e.g., artist names with ` - ` in them): the parser uses the mask's literal separators as split points, left-to-right greedy. Document this behavior for users.
- Track numbers with or without zero-padding: accept both, store as integer.

## Dependencies

- **PRD 00 (TagLib FFI Integration)** — Writing extracted tags to files requires the safe TagLib writer (atomic writes, frame preservation).

## Out of Scope

- Regex-based extraction (mask pattern is sufficient).
- Automatic mask detection/suggestion (could be a future enhancement).
