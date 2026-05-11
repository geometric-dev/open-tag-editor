# Implementation Plan: TagLib FFI Integration

## Overview

Replace the current pure-Dart tag reader/writer with FFI bindings to TagLib (`taglib_c`), implementing safe, atomic, format-complete metadata I/O for all 10 supported audio formats. The implementation preserves existing `TagReaderService` and `TagWriterService` interfaces, adds atomic writes with optional backup and post-write validation, and provides a graceful fallback to the pure-Dart reader when native libraries are unavailable.

## Tasks

- [x] 1. Set up FFI infrastructure and native library loading
  - [x] 1.1 Create the `native/` directory with `taglib_c.h` header and `ffigen.yaml` configuration
    - Add the TagLib C header file (`tag_c.h`) to `native/taglib_c.h`
    - Create `native/ffigen.yaml` with configuration targeting the header, specifying output to `lib/shared/services/taglib/taglib_bindings.g.dart`
    - Add `ffigen` to `dev_dependencies` in `pubspec.yaml`
    - Add `ffi` to `dependencies` in `pubspec.yaml`
    - _Requirements: 11.1, 11.2, 11.3_

  - [x] 1.2 Generate FFI bindings using ffigen
    - Run `dart run ffigen --config native/ffigen.yaml` to generate `lib/shared/services/taglib/taglib_bindings.g.dart`
    - Verify generated bindings cover: file operations, tag operations, properties API, complex properties API, audio properties, and memory management functions
    - _Requirements: 11.1, 11.2, 11.3_

  - [x] 1.3 Implement `NativeLibraryLoader` in `lib/shared/services/taglib/native_library_loader.dart`
    - Implement platform detection (Windows, macOS, Linux)
    - Resolve library path: `taglib_c.dll` adjacent to executable on Windows, `libtaglib_c.dylib` in Frameworks on macOS, `libtaglib_c.so` adjacent to executable then system paths on Linux
    - Implement `static DynamicLibrary load()` that throws `NativeLibraryException` with platform name and attempted path on failure
    - Implement `static bool get isAvailable` that returns true if library can be loaded
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [x] 1.4 Create `NativeLibraryException` and `TagFormat` enum in `lib/shared/services/taglib/taglib_types.dart`
    - Define `NativeLibraryException` with `message`, `platform`, and `attemptedPath` fields
    - Define `TagFormat` enum: `id3v1`, `id3v2_3`, `id3v2_4`, `vorbisComment`, `apeTag`, `asf`, `mp4Atoms`, `unknown`
    - _Requirements: 1.4, 2.4_

  - [ ]* 1.5 Write unit tests for `NativeLibraryLoader`
    - Test platform-specific path resolution logic for Windows, macOS, and Linux
    - Test that `NativeLibraryException` contains correct platform and path information
    - Test `isAvailable` returns false when library is missing
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Implement tag property mapper and reader service
  - [x] 2.1 Create `TagPropertyMapper` in `lib/shared/services/taglib/tag_property_mapper.dart`
    - Implement bidirectional mapping between app field names and TagLib property keys (e.g., `title` ↔ `TITLE`, `albumArtist` ↔ `ALBUMARTIST`, `year` ↔ `DATE`, etc.)
    - Handle special cases: `trackTotal` may be part of `TRACKNUMBER` as "3/12", `discTotal` may be part of `DISCNUMBER`
    - Implement `String? toTagLibKey(String appField)` and `String? toAppField(String tagLibKey)`
    - _Requirements: 2.1, 4.1_

  - [x] 2.2 Implement `TagLibReaderService` in `lib/shared/services/taglib/taglib_reader_service.dart`
    - Implement `TagReaderService` interface
    - In `readTags(String path)`: open file with `taglib_file_new`, validate with `taglib_file_is_valid`, read all properties via `taglib_property_keys`/`taglib_property_get`, read audio properties, read album art via `taglib_complex_property_get("PICTURE")`, free all resources in try/finally
    - Null-check every FFI pointer before dereferencing
    - Convert TagLib property values to `AudioFile` model using `TagPropertyMapper`
    - Throw `TagReadException` with file path for invalid/corrupt files
    - Return `AudioFile` with empty tags map for files with no tags (no exception)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [x] 2.3 Implement `readTagsBatch` in `TagLibReaderService`
    - Process each file independently, catching errors per-file
    - On failure, include file in result list with empty tags and error indication
    - Return results in same order as input paths
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ]* 2.4 Write property test: Tag read/write round-trip (Property 1)
    - **Property 1: Tag read/write round-trip**
    - Generate random tag maps (subset of standard fields with non-empty string values), write to test files, read back, assert equality
    - **Validates: Requirements 2.1, 8.1**

  - [ ]* 2.5 Write property test: Batch read order preservation (Property 4)
    - **Property 4: Batch read order preservation**
    - Generate random file path lists, batch read, assert i-th result path equals i-th input path
    - **Validates: Requirements 3.1**

  - [ ]* 2.6 Write property test: Batch read fault isolation (Property 5)
    - **Property 5: Batch read fault isolation**
    - Generate mixed valid/invalid path lists, batch read, assert result list same length as input, valid files have tags, invalid files have empty tags
    - **Validates: Requirements 3.2**

  - [ ]* 2.7 Write property test: Corrupt file safety (Property 3)
    - **Property 3: Corrupt file safety**
    - Generate random byte sequences, attempt read, assert no crash/segfault — either TagReadException or AudioFile with empty tags
    - **Validates: Requirements 2.5**

- [x] 3. Checkpoint - Ensure reader service tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement atomic write manager and backup manager
  - [x] 4.1 Implement `AtomicWriteManager` in `lib/shared/services/taglib/atomic_write_manager.dart`
    - Implement `writeAtomic(String originalPath, Future<void> Function(String tempPath) writeOperation)`
    - Copy original file to a temp file in the same directory (use unique suffix like `.tmp_<timestamp>`)
    - Call the write operation on the temp file
    - On success: rename temp file over original (single filesystem operation)
    - On write failure: delete temp file, leave original unchanged
    - On rename failure: retain both files, throw `TagWriteException` describing the failure
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 4.2 Implement `BackupManager` in `lib/shared/services/taglib/backup_manager.dart`
    - Accept settings provider to check if backup is enabled
    - Implement `createBackupIfEnabled(String path)` that copies original to `<path>.bak`
    - If backup is enabled and copy fails, throw `TagWriteException` and abort
    - If backup is disabled, skip and proceed
    - Expose `bool get isEnabled` from app settings
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [x] 4.3 Implement `ValidationEngine` in `lib/shared/services/taglib/validation_engine.dart`
    - Accept `TagLibReaderService` for re-reading files
    - Implement `validate(String path, Map<String, String> expectedTags)`
    - Re-read the file after write, compare written fields against intended values
    - On mismatch with backup available: restore from `.bak`, throw `TagWriteException` with field mismatch details
    - On mismatch without backup: throw `TagWriteException` with mismatch details, do not modify file
    - _Requirements: 8.1, 8.2, 8.3_

  - [ ]* 4.4 Write property test: Failed write leaves original unchanged (Property 9)
    - **Property 9: Failed write leaves original unchanged**
    - Simulate write failures on temp file, assert original file remains byte-for-byte identical
    - **Validates: Requirements 6.3**

  - [ ]* 4.5 Write property test: Backup creates identical copy (Property 10)
    - **Property 10: Backup creates identical copy**
    - Generate file content, trigger backup, assert `.bak` file bytes are identical to original before modification
    - **Validates: Requirements 7.1**

- [x] 5. Implement tag writer service
  - [x] 5.1 Implement `TagLibWriterService` in `lib/shared/services/taglib/taglib_writer_service.dart`
    - Implement `TagWriterService` interface
    - In `writeTags(String path, Map<String, String> tags)`: create backup if enabled → atomic write (open temp file, set properties via `taglib_property_set`, save) → validate
    - Handle empty string values by clearing the field (remove property)
    - Throw `TagWriteException` if target file does not exist
    - Use `TagPropertyMapper` for field name conversion
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [x] 5.2 Implement album art writing and removal in `TagLibWriterService`
    - In `writeAlbumArt(String path, AlbumArtData art)`: use complex property API with PICTURE key to embed front-cover image, replacing existing
    - In `removeAlbumArt(String path)`: set PICTURE complex property to null/empty to remove all album art
    - Both operations must preserve all non-art metadata fields
    - Apply atomic write + backup + validation to art operations
    - _Requirements: 5.1, 5.2, 5.3_

  - [x] 5.3 Implement `writeTagsBatch` in `TagLibWriterService`
    - Process each file independently, applying atomic write + backup + validation per file
    - Record failures in `TagWriteResult` per file, continue processing remaining files
    - Return list of `TagWriteResult` objects for all files
    - _Requirements: 9.1, 9.2, 9.3_

  - [ ]* 5.4 Write property test: Selective write with metadata preservation (Property 6)
    - **Property 6: Selective write with metadata preservation**
    - Generate existing tags + write subset, assert written fields have new values and non-written fields retain original values
    - **Validates: Requirements 4.1, 4.2**

  - [ ]* 5.5 Write property test: Empty string clears field (Property 7)
    - **Property 7: Empty string clears field**
    - Generate field names, write empty string, assert field is absent or empty when read back
    - **Validates: Requirements 4.3**

  - [ ]* 5.6 Write property test: Album art round-trip (Property 2)
    - **Property 2: Album art round-trip**
    - Generate random image bytes (valid JPEG/PNG headers) + MIME types, write/read album art, assert byte equality
    - **Validates: Requirements 2.2, 5.1**

  - [ ]* 5.7 Write property test: Art operations preserve non-art metadata (Property 8)
    - **Property 8: Art operations preserve non-art metadata**
    - Generate files with tags, perform writeAlbumArt or removeAlbumArt, assert all non-art tag fields unchanged
    - **Validates: Requirements 5.2, 5.3**

  - [ ]* 5.8 Write property test: Batch write fault isolation (Property 11)
    - **Property 11: Batch write fault isolation**
    - Generate mixed valid/invalid batch, assert TagWriteResult for every file, valid files succeed, invalid files fail with error message, no cross-contamination
    - **Validates: Requirements 9.1, 9.2**

- [x] 6. Checkpoint - Ensure writer service tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement service provider integration and fallback
  - [x] 7.1 Create `DisabledWriterService` in `lib/shared/services/taglib/disabled_writer_service.dart`
    - Implement `TagWriterService` interface
    - All methods throw `TagWriteException` with message "Native TagLib library not available. Writing is disabled."
    - `writeTagsBatch` returns list of failed `TagWriteResult` for all files
    - _Requirements: 10.4_

  - [x] 7.2 Update service providers in `lib/features/tag_editor/data/providers/service_providers.dart`
    - Update `tagReaderProvider`: if `NativeLibraryLoader.isAvailable`, create `TagLibReaderService` with bindings; otherwise fall back to `Id3ReaderService`
    - Update `tagWriterProvider`: if `NativeLibraryLoader.isAvailable`, create `TagLibWriterService` with bindings, backup manager, and validation engine; otherwise return `DisabledWriterService`
    - Select implementation at application startup based on native library availability
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [ ]* 7.3 Write unit tests for service provider fallback logic
    - Test that reader falls back to `Id3ReaderService` when native library unavailable
    - Test that writer returns `DisabledWriterService` when native library unavailable
    - Test that `DisabledWriterService` throws on all operations
    - _Requirements: 10.3, 10.4, 10.5_

- [x] 8. Set up platform binary bundling
  - [x] 8.1 Configure Windows binary bundling
    - Place `taglib_c.dll` in `windows/` directory
    - Update `windows/CMakeLists.txt` to include `taglib_c.dll` in the build output adjacent to the executable
    - _Requirements: 12.1, 12.4_

  - [x] 8.2 Configure macOS binary bundling
    - Place universal `libtaglib_c.dylib` (x64 + ARM64) in `macos/Frameworks/`
    - Update Xcode project configuration to bundle the dylib in the app's Frameworks directory
    - _Requirements: 12.2, 12.4_

  - [x] 8.3 Configure Linux binary bundling
    - Place `libtaglib_c.so` in `linux/lib/`
    - Update `linux/CMakeLists.txt` to include `libtaglib_c.so` in the build output adjacent to the executable
    - _Requirements: 12.3, 12.4_

- [x] 9. Add backup setting to application settings
  - [x] 9.1 Add backup toggle to settings page
    - Add a boolean setting "Create backup before writing" to the settings page at `lib/features/settings/presentation/pages/settings_page.dart`
    - Persist the setting using `shared_preferences`
    - Create a Riverpod provider for the backup setting accessible by `BackupManager`
    - _Requirements: 7.4_

- [x] 10. Create test fixtures and integration verification
  - [x] 10.1 Create test fixture files in `test/fixtures/`
    - Add minimal valid audio files for each format: `test.mp3`, `test.flac`, `test.ogg`, `test.m4a`, `test.mp4`, `test.wma`, `test.wav`, `test.ape`, `test.opus`, `test.aac`
    - Add `corrupt.bin` (random bytes for corruption testing)
    - Add `no_tags.mp3` (valid audio, no metadata)
    - Keep files small (< 10KB each)
    - _Requirements: 2.1, 2.5, 2.6_

  - [ ]* 10.2 Write integration tests for end-to-end read/write cycle
    - Test read/write cycle with real TagLib library for all 10 supported formats
    - Verify tag format detection for each format
    - Test album art read/write for formats that support it
    - Test that no-tag files return empty tags without exception
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6, 4.4, 5.1_

- [x] 11. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The `ffigen` generated bindings file should be committed to source control for reproducibility
- Test fixtures must be committed to source control for reproducible testing
- The `fast_check` package should be added to dev_dependencies for property-based testing
