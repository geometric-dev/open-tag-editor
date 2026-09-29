# PRD 20: Multi-Value Tag Editing (P2)

## Status: data layer and writing shipped; UI partially

The highest-risk part of this PRD was the one that was silently broken
before: **editing a joined multi-value field flattened it to a single
literal value on the next save.** Reading already joined values with `"; "`,
but the writer passed that joined string straight to `taglib_property_set`,
turning `["A", "B"]` into one property containing `"A; B"`.

Delivered:

- **Real multi-value writing.** Multi-value fields are now cleared and each
  value appended with `taglib_property_set_append`, so Vorbis Comments get
  repeated `ARTIST=` entries and ID3v2 gets its own multi-value encoding —
  whichever the library's binding layer provides. Verified against the real
  DLL on both MP3 (ID3v2) and FLAC (Vorbis Comment), including
  replace-does-not-append and clear-removes-every-value.
- **A closed set of multi-value fields** (`artist`, `albumArtist`, `genre`,
  `composer`, `conductor`, `lyricist`). Deliberately closed: a value that
  genuinely contains a semicolon, like `AC/DC; Live`, must not be shredded.
  Non-multi-value fields are never split, and there is a test for it.
- **Separator detection on read.** The null-byte, `"; "`, `";"`, `" / "`
  and `"/"` conventions are all recognised, so a file written by another tool
  stays readable regardless of what this install prefers.
- **Validation compares multi-value fields as value sets**, not as raw
  strings. Without this the writer's own normalisation (dropping empty
  segments) failed validation and aborted the write — validation would have
  made the feature unusable.
- **A chip editor in the tag panel** for the six multi-value fields: one
  removable chip per value, plus an inline add field. Each edit is a single
  undoable command.

Not delivered, and why:

- **Batch Set / Add / Remove / Replace across a multi-file selection.** These
  need per-file value *sets* rather than a joined string, which means changing
  `AudioFile.tags` to hold `List<String>` for these fields. That is a
  cross-cutting model change touching the reader, the grid, the export path
  and every existing command, and it is worth doing as its own piece of work
  rather than half-landed here.
- **Drag-to-reorder chips.** The list operations (`MultiValue.reorder`) exist
  and are tested; the drag affordance is not wired up.
- **The "×3" grid badge and per-value tooltips.** The joined display is
  unchanged, so a multi-value cell still looks like a single value.
- **The separator preference and the compatibility-mode preference.** The
  parser accepts every convention regardless, so the feature works without
  them; exposing a choice where all options behave identically would be
  noise. `MultiValueSeparator` exists as the seam to add the setting to.
- **Inline grid cell editing of multi-value cells.** They still open a plain
  text field.

## Problem Statement

Several tag fields legitimately contain multiple values — multiple artists on a track, multiple genres, multiple composers. Different tag formats handle this differently: Vorbis Comments and MP4 atoms support true multi-value fields (repeated field names), while ID3v2 uses separator characters (null byte, semicolon, or slash depending on the frame). Current tag editing treats all fields as single strings, which means:

- Users can't add or remove individual values from a multi-value field.
- Saving a multi-value field as a plain string may corrupt the separator format.
- Display truncates or concatenates values without indicating multiplicity.

## Goals

- Properly read, display, and write multi-value tag fields across all supported formats.
- Provide UI for adding, removing, and reordering individual values within a multi-value field.
- Preserve the correct multi-value encoding per tag format.

## Functional Requirements

### Multi-Value Aware Fields
The following fields support multiple values:
- **Artist** — multiple performing artists
- **Album Artist** — multiple album artists
- **Genre** — multiple genres
- **Composer** — multiple composers
- **Conductor** — multiple conductors (less common)
- **Lyricist** — multiple lyricists

Other fields (Title, Album, Year, Track #, etc.) remain single-value.

### Display
- In the file list grid, multi-value fields display values joined with "; " (semicolon + space) for readability.
- A subtle indicator (e.g., a small badge or "×3" suffix) shows when a cell contains multiple values vs. a single value that happens to contain a semicolon.
- Tooltip on hover shows each value on its own line.

### Tag Edit Panel — Multi-Value Editor
- Multi-value fields in the tag edit panel show as a chip/tag list:
  - Each value appears as a removable chip (with an × button).
  - An "Add" button or text input below the chips allows adding new values.
  - Chips can be reordered via drag-and-drop (order matters for "primary artist" conventions).
- Typing in the add field and pressing Enter adds a new value.
- Pressing × on a chip removes that value.
- The entire multi-value edit registers as a single undoable operation.

### Inline Grid Editing (if PRD 09 is implemented)
- Double-clicking a multi-value cell in the grid opens a small popup editor with the chip interface (not a plain text field).
- For quick edits, the user can also type semicolon-separated values which are parsed into individual values on confirm.

### Batch Multi-Value Operations
- When multiple files are selected:
  - "Add value to all" — appends a value to the multi-value field of all selected files (e.g., add genre "Electronic" to 50 files).
  - "Remove value from all" — removes a specific value from all selected files that contain it.
  - "Replace value in all" — replaces one value with another across all selected files (e.g., rename genre "Electronica" to "Electronic").
  - "Set values" — overwrites the entire multi-value field with a new set of values for all selected files.
- These operations are available via the tag edit panel when multiple files are selected, with clear radio/tab selection between "Set", "Add", "Remove", and "Replace" modes.

### Format-Correct Writing
- **Vorbis Comments (FLAC, OGG, Opus)**: Write as repeated field names (one ARTIST= per value). This is the native multi-value mechanism.
- **MP4/M4A**: Write as multiple values in the atom (native support).
- **ID3v2 (MP3)**: Write multiple values separated by null byte (0x00) in a single frame, per ID3v2.4 spec. For ID3v2.3 compatibility, use "/" separator for TCON (genre) and null byte for other frames.
- **APE tags**: Write as null-byte-separated values in a single item.
- **WMA/ASF**: Write as multiple attribute entries.
- When reading, detect and parse all common separator conventions (null byte, semicolon, slash, " / ", " ; ") to extract individual values.

### Separator Detection & Normalization
- On first read, detect which separator a file uses for multi-value fields.
- When writing back, use the format-correct separator (not necessarily what was originally in the file).
- Setting in preferences: "Normalize multi-value separators on save" (default: on). When enabled, files are updated to use the correct separator for their format even if no values were added/removed.

### Compatibility Mode
- Setting: "Treat semicolons in single-value fields as value separators" (default: off).
- When enabled, a field like `Genre: "Rock; Alternative"` is interpreted as two values ["Rock", "Alternative"].
- When disabled, it's treated as a single value "Rock; Alternative" (preserving user intent for fields that genuinely contain semicolons in their text).

## Non-Functional Requirements

- Multi-value parsing adds <1ms per file during load (negligible).
- The chip editor should handle up to 20 values per field without layout issues.
- Writing multi-value fields should not be slower than writing single-value fields.

## Dependencies

- **PRD 00 (TagLib FFI Integration)** — Requires reading/writing raw frame data to handle multi-value encoding correctly. The current abstract `writeTag(field, value)` interface may need extension to `writeTag(field, List<String> values)`.
- **PRD 01 (Folder Loading & File Display)** — Display changes in the grid.
- **PRD 09 (Inline Cell Editing)** — Multi-value popup editor for grid cells.

## Out of Scope

- Auto-suggesting values from existing library data (e.g., genre autocomplete from genres already used in loaded files) — future enhancement.
- Splitting a single-value field into multi-value based on regex (too error-prone for a default operation).
- Multi-value support for non-standard/custom tag fields (only the listed fields above).
