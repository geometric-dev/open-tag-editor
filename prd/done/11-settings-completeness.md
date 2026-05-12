# PRD 11: Settings Persistence & Completeness (P3)

## Problem Statement

The Settings page contains several controls that are visually present but not wired to any persisted state or behavioral logic. Users who configure these settings will find they have no effect, which is confusing and undermines confidence in the app.

## Goals

- Wire all existing settings UI controls to persisted preferences.
- Ensure each setting actually affects app behavior.
- Remove or clearly mark any settings that are intentionally deferred.

## Functional Requirements

### General Section
- **Confirm before saving**: Persist as boolean. When enabled, Save actions show a confirmation dialog listing files to be written. When disabled, save executes immediately.

### Tag Writing Section
- **Default ID3v2 version**: Persist choice (ID3v2.3 or ID3v2.4). Pass to `TagLibWriterService` to control which ID3v2 sub-version is written to MP3 files.
- **Write ID3v1 tags**: Persist as boolean. When enabled, also write an ID3v1 tag block to MP3 files alongside ID3v2. When disabled, only write ID3v2.
- **Default encoding**: Persist choice (UTF-8, UTF-16, Latin-1). Controls the text encoding used for ID3v2 frames.

### File Renaming Section
- **Default rename pattern**: Persist the user's preferred default pattern string. Pre-fill the rename dialog with this pattern instead of the first built-in preset.
- **Preview before renaming**: Persist as boolean. When enabled, the rename dialog always shows preview before allowing execution. When disabled, allow direct rename without preview step.

### Persistence
- All settings use `shared_preferences` with versioned keys.
- Corrupted or missing preferences fall back to sensible defaults.
- Settings take effect immediately (no restart required).

## Non-Functional Requirements

- Settings page should load in <100ms (no blocking I/O on the UI thread).

## Dependencies

- PRD 00 (TagLib FFI) — ID3v2 version and encoding settings need to be passed through to the writer.

## Out of Scope

- Settings import/export.
- Per-folder settings profiles.
