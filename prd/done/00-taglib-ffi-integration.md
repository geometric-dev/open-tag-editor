# PRD 00: TagLib FFI Integration (Safe Tag Reading & Writing)

## Problem Statement

The current pure-Dart tag reader/writer implementation has critical limitations:
- **Writing is unsafe**: rewrites entire files non-atomically, discards unmodified frames (cover art, comments, custom tags get silently deleted), and only supports MP3 and FLAC.
- **Reading is incomplete**: only MP3 and FLAC tags are actually parsed; 8 of 10 supported formats return empty tags.
- **No corruption protection**: no temp-file-then-rename pattern, no backup mechanism.

For a tool managing users' music libraries, file corruption is unacceptable. This must be the first item implemented — every other feature (display, rename, web lookup) depends on reliable tag I/O.

## Goals

- Replace the pure-Dart tag implementation with FFI bindings to TagLib, a battle-tested C++ library used by Picard, Clementine, Amarok, and most serious audio tagging tools.
- Support reading and writing tags for all 10 supported formats.
- Guarantee no data loss: preserve all existing tags/frames not being modified.
- Implement atomic writes and optional backup.

## Why TagLib

- Handles MP3 (ID3v1, ID3v2.3, ID3v2.4), FLAC, OGG Vorbis, Opus, M4A/MP4 (iTunes atoms), WMA (ASF), WAV, APE, AAC.
- Preserves frames/atoms it doesn't touch — writing a title won't delete your cover art.
- Atomic write behavior internally.
- 20+ years of production use, actively maintained.
- C API (`taglib_c`) is straightforward to bind via `dart:ffi`.

## Functional Requirements

### Tag Reading (all formats)
- Read standard fields: title, artist, album artist, album, year, genre, track number, disc number, comment, composer, conductor, lyricist, publisher, copyright, BPM, compilation.
- Read album art (embedded cover images).
- Read audio properties: duration, bitrate, sample rate, channels.
- Detect tag format present (ID3v1, ID3v2.3, ID3v2.4, Vorbis Comment, APE tag, ASF, MP4 atoms) — needed for the tag indicator icon in the file list.
- Graceful handling of corrupt/unreadable files (return error, never crash).

### Tag Writing (all formats)
- Write any subset of standard fields — only specified fields are modified, all others preserved.
- Write/replace/remove album art.
- Preserve all existing metadata not being explicitly changed.
- Support batch writing (multiple files).

### Safety Mechanisms
- **Atomic writes**: write to a temporary file in the same directory, then rename over the original. If the write fails, the original is untouched.
- **Optional backup**: setting to copy original to `<filename>.bak` before any write operation. Configurable in app settings (on by default initially).
- **Validation after write**: re-read the file after writing to confirm tags were persisted correctly. If validation fails, restore from backup/temp.
- **Dry-run mode**: ability to validate a write operation without committing (used by preview features in PRDs 02/03).

### Platform Support
- Windows (primary — x64)
- macOS (x64 + ARM64)
- Linux (x64)
- TagLib shared libraries (.dll / .dylib / .so) bundled with the app or documented as a dependency.

## Technical Approach

### Option A: dart:ffi bindings to taglib_c (Recommended)
- Use TagLib's C binding API (`taglib_c.h`) which provides a simplified interface.
- Generate FFI bindings using `package:ffigen`.
- Bundle pre-compiled TagLib binaries per platform.
- Wrap in the existing `TagReaderService` / `TagWriterService` interfaces — no changes needed to consuming code.

### Option B: Process-based wrapper (Fallback)
- If FFI proves problematic on a platform, shell out to a CLI tool (e.g., `kid3-cli`, `mutagen` via Python, or a custom thin C wrapper).
- Slower but still safe.

### Architecture
```
TagReaderService (abstract)          TagWriterService (abstract)
        │                                     │
        ▼                                     ▼
TagLibReaderService (FFI impl)       TagLibWriterService (FFI impl)
        │                                     │
        ▼                                     ▼
   taglib_c via dart:ffi              taglib_c via dart:ffi
        │                                     │
        ▼                                     ▼
   libtaglib.dll / .dylib / .so       (same native library)
```

## Non-Functional Requirements

- Reading a single file's tags: < 10ms.
- Writing a single file's tags (including atomic rename): < 100ms.
- Batch reading 500 files: < 3 seconds.
- Memory: TagLib operates on file handles, not full-file byte arrays — much lower memory footprint than current approach.
- No runtime dependency on Python, Node, or other interpreters.

## Migration Plan

1. Implement `TagLibReaderService` and `TagLibWriterService` behind the existing interfaces.
2. Keep `Id3ReaderService` / `Id3WriterService` as a fallback (read-only, for environments where native libs can't load).
3. Service provider selects implementation at startup based on native library availability.
4. Remove the pure-Dart writer from production paths entirely (it should never write to user files).

## Out of Scope

- Writing custom/non-standard frames (e.g., ReplayGain, MusicBrainz IDs) — can be added later.
- Tag format conversion (e.g., upgrading ID3v1 to ID3v2) — TagLib handles this implicitly when writing.
- GUI for this feature — it's infrastructure consumed by all other PRDs.

## Risks

- Bundling native binaries adds ~2-5MB per platform to the app size.
- FFI debugging can be tricky — need good error messages when the native lib fails to load.
- TagLib's C API is simpler but less feature-rich than the C++ API. If we need advanced features (e.g., reading specific ID3v2 frame flags), we may need a thin C++ wrapper exposing additional functions.
