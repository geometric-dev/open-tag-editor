# PRD 19: ReplayGain Tag Handling (P3)

## Status: shipped

Delivered:

- Read-only "ReplayGain" section in the tag panel, collapsed by default,
  showing `varies` for a mixed selection and `Not set` when absent.
- Optional `RG Track Gain` / `RG Album Gain` columns, hidden by default.
- Tools ▸ *Clear ReplayGain…*, undoable, clearing only those four fields.
- "Clear All Tags" names the ReplayGain count in its confirmation; "Clear
  Fields…" lists the fields individually (via PRD 18).
- Mapped in `TagPropertyMapper` in both directions, so the values are
  explicit rather than surviving only incidentally. Verified against the
  real library on ID3v2 and Vorbis Comment files.

Not delivered, and why:

- **ID3v2 vs APEv2 discrepancy display.** The Properties API exposes one
  value per field; it cannot report which container a value came from, so
  "display ID3v2 and note the discrepancy" is not achievable without
  dropping to TagLib's per-container API.
- **Normalize / recalculate.** Out of scope per this PRD — it requires
  decoding audio.

## Problem Statement

ReplayGain tags store loudness normalization data calculated from audio analysis. Many users rely on these values for consistent playback volume across their library. Tag editors that don't explicitly handle ReplayGain risk silently destroying these values during tag operations, or confusing users by displaying them alongside editable metadata without context.

## Goals

- Display ReplayGain values as read-only informational fields.
- Preserve ReplayGain tags during all tag write operations by default.
- Provide explicit options for users who want to clear or recalculate ReplayGain data.

## Functional Requirements

### Display ReplayGain Data
- Show ReplayGain values in the tag edit panel under a dedicated "ReplayGain" section (collapsed by default):
  - Track Gain (e.g., "-6.5 dB")
  - Track Peak (e.g., "0.988")
  - Album Gain (e.g., "-8.2 dB")
  - Album Peak (e.g., "1.000")
- These fields are displayed as read-only (not editable inline) since they are calculated values, not user-authored metadata.
- When multiple files are selected, show "varies" if values differ, or the common value if identical.
- Files without ReplayGain data show "Not set" in these fields.

### Optional Column Display
- ReplayGain Track Gain and Album Gain available as optional columns in the file list (hidden by default).
- Useful for quickly identifying files missing ReplayGain data.

### Preservation During Tag Operations
- ReplayGain tags are added to the preserved tags list by default (see PRD 04 Preserved Tags List).
- During online metadata apply, tag-from-filename, or any batch tag write, ReplayGain fields are never overwritten unless the user explicitly removes them from the preserved list.
- The "Clear All Tags" operation (PRD 18) removes ReplayGain along with everything else — but the confirmation dialog explicitly mentions "including ReplayGain loudness data" so users are aware.
- The "Clear Specific Fields" operation (PRD 18) lists ReplayGain fields individually so users can selectively remove them.

### Clear ReplayGain
- A dedicated "Clear ReplayGain" action (right-click context menu) removes only the four ReplayGain fields from selected files.
- Useful when users want to recalculate with an external tool (e.g., foobar2000, loudgain, mp3gain).
- Operation is undoable.

### ReplayGain Tag Format Awareness
- Read ReplayGain from the correct location per format:
  - MP3 (ID3v2): `TXXX:replaygain_track_gain`, `TXXX:replaygain_track_peak`, etc.
  - MP3 (APEv2): `REPLAYGAIN_TRACK_GAIN`, etc.
  - FLAC/OGG (Vorbis Comment): `REPLAYGAIN_TRACK_GAIN`, etc.
  - MP4/M4A: Custom atoms or iTunes-style tags.
  - WMA: Custom attributes.
- When both ID3v2 and APEv2 ReplayGain exist on an MP3, display the ID3v2 values (primary) and note the discrepancy.

## Non-Functional Requirements

- Reading ReplayGain values adds negligible overhead to file loading (they're just tag fields).
- The ReplayGain section in the tag panel should not increase panel load time.

## Dependencies

- **PRD 00 (TagLib FFI Integration)** — Reading custom/non-standard frames (TXXX, custom Vorbis comments) is required. Note: PRD 00 currently lists "custom/non-standard frames" as out of scope — this PRD requires that capability to be added.
- **PRD 04 (Online Metadata Lookup)** — Preserved tags list integration.
- **PRD 18 (Tag Deletion & Cleanup)** — ReplayGain fields appear in the clear-fields dialog.

## Out of Scope

- Calculating ReplayGain values (requires audio analysis; users should use dedicated tools like loudgain, foobar2000, or mp3gain).
- R128 gain tags (similar concept, different standard — could be added later).
- Displaying a waveform or loudness visualization.
