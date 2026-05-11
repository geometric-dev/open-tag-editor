# Requirements Document

## Introduction

Replace the current unsafe pure-Dart tag reader/writer with FFI bindings to TagLib (via `taglib_c`), providing safe, atomic, format-complete metadata reading and writing for all 10 supported audio formats. This is foundational infrastructure — every feature in the app depends on reliable tag I/O.

## Glossary

- **TagLib_FFI_Service**: The FFI-based implementation of tag reading and writing using TagLib's C API (`taglib_c`) via `dart:ffi`
- **Tag_Reader**: The component responsible for reading metadata from audio files, implementing the `TagReaderService` interface
- **Tag_Writer**: The component responsible for writing metadata to audio files, implementing the `TagWriterService` interface
- **Atomic_Write_Manager**: The component responsible for ensuring writes use a temp-file-then-rename pattern so originals are never corrupted
- **Backup_Manager**: The component responsible for creating `.bak` copies of files before modification
- **Validation_Engine**: The component responsible for re-reading files after writes to confirm tag persistence
- **Native_Library_Loader**: The component responsible for locating and loading the platform-specific TagLib shared library
- **Audio_Properties**: Duration, bitrate, sample rate, and channel count extracted from an audio file
- **Tag_Format**: The metadata container format present in a file (ID3v1, ID3v2.3, ID3v2.4, Vorbis Comment, APE tag, ASF, MP4 atoms)
- **Supported_Formats**: The 10 audio file extensions the app handles: MP3, FLAC, OGG, M4A, MP4, WMA, WAV, APE, OPUS, AAC

## Requirements

### Requirement 1: Native Library Loading

**User Story:** As a developer, I want the app to locate and load the correct TagLib shared library for the current platform, so that FFI bindings function on all supported operating systems.

#### Acceptance Criteria

1. WHEN the application starts on Windows x64, THE Native_Library_Loader SHALL load `taglib_c.dll` from the bundled assets directory
2. WHEN the application starts on macOS (x64 or ARM64), THE Native_Library_Loader SHALL load `libtaglib_c.dylib` from the bundled assets directory
3. WHEN the application starts on Linux x64, THE Native_Library_Loader SHALL load `libtaglib_c.so` from the bundled assets directory
4. IF the native library file is missing or fails to load, THEN THE Native_Library_Loader SHALL throw a descriptive exception containing the platform name and the attempted file path
5. WHEN the native library loads successfully, THE Native_Library_Loader SHALL expose all required TagLib C API function pointers to the FFI binding layer

### Requirement 2: Tag Reading for All Supported Formats

**User Story:** As a user, I want to open any of the 10 supported audio formats and see all embedded metadata, so that I can view and manage my music library regardless of file type.

#### Acceptance Criteria

1. WHEN a valid audio file of any Supported_Format is opened, THE Tag_Reader SHALL return an AudioFile populated with all standard tag fields present in the file (title, artist, album, album artist, year, genre, track number, track total, disc number, disc total, comment, composer, conductor, lyricist, publisher, copyright, BPM, compilation)
2. WHEN a valid audio file contains embedded album art, THE Tag_Reader SHALL extract the first front-cover image as an AlbumArtData object with correct bytes and MIME type
3. WHEN a valid audio file is opened, THE Tag_Reader SHALL read Audio_Properties (duration in seconds, bitrate in kbps, sample rate in Hz, channel count)
4. WHEN a valid audio file is opened, THE Tag_Reader SHALL detect and report which Tag_Format is present in the file
5. IF a file is corrupt or unreadable, THEN THE Tag_Reader SHALL throw a TagReadException with a descriptive message and the file path, without crashing the application
6. WHEN a file contains no tags, THE Tag_Reader SHALL return an AudioFile with an empty tags map and null albumArt, without throwing an exception
7. THE Tag_Reader SHALL read a single file in less than 10 milliseconds under normal conditions

### Requirement 3: Batch Tag Reading

**User Story:** As a user, I want to load an entire folder of audio files quickly, so that I can browse and edit my library without waiting.

#### Acceptance Criteria

1. WHEN a list of file paths is provided, THE Tag_Reader SHALL read tags from all files and return a list of AudioFile objects in the same order as the input paths
2. IF an individual file in a batch fails to read, THEN THE Tag_Reader SHALL include that file in the result list with empty tags and an error indication, without aborting the remaining files
3. WHEN 500 files are read in batch, THE Tag_Reader SHALL complete in less than 3 seconds

### Requirement 4: Tag Writing with Metadata Preservation

**User Story:** As a user, I want to edit specific tag fields and save them without losing any existing metadata I did not modify, so that my cover art, comments, and custom frames are never silently deleted.

#### Acceptance Criteria

1. WHEN a map of field names to values is provided, THE Tag_Writer SHALL write only the specified fields to the file
2. WHEN a write operation completes, THE Tag_Writer SHALL preserve all existing metadata fields not included in the write map (including album art, comments, custom frames, and non-standard tags)
3. WHEN a write operation specifies an empty string for a field, THE Tag_Writer SHALL clear that field in the file
4. THE Tag_Writer SHALL support writing tags to all 10 Supported_Formats
5. IF the target file does not exist, THEN THE Tag_Writer SHALL throw a TagWriteException with a descriptive message
6. THE Tag_Writer SHALL write a single file in less than 100 milliseconds under normal conditions

### Requirement 5: Album Art Writing

**User Story:** As a user, I want to add, replace, or remove album art from my audio files, so that my music player displays the correct cover images.

#### Acceptance Criteria

1. WHEN AlbumArtData is provided, THE Tag_Writer SHALL embed the image in the file as front-cover album art, replacing any existing front-cover image
2. WHEN album art removal is requested, THE Tag_Writer SHALL remove all embedded album art from the file without affecting other metadata
3. WHEN album art is written, THE Tag_Writer SHALL preserve all existing non-art metadata fields in the file

### Requirement 6: Atomic Write Operations

**User Story:** As a user, I want my original files to remain intact if a write operation fails partway through, so that I never end up with corrupted audio files.

#### Acceptance Criteria

1. WHEN a tag write is initiated, THE Atomic_Write_Manager SHALL write the modified content to a temporary file in the same directory as the original
2. WHEN the temporary file write completes successfully, THE Atomic_Write_Manager SHALL rename the temporary file over the original in a single filesystem operation
3. IF the write to the temporary file fails, THEN THE Atomic_Write_Manager SHALL delete the temporary file and leave the original file unchanged
4. IF the rename operation fails, THEN THE Atomic_Write_Manager SHALL retain both the temporary file and the original file, and throw a TagWriteException describing the failure

### Requirement 7: Optional Backup Before Write

**User Story:** As a user, I want the option to keep a backup of my original files before any modifications, so that I can recover from unintended edits.

#### Acceptance Criteria

1. WHERE the backup setting is enabled, THE Backup_Manager SHALL copy the original file to `<original_path>.bak` before any write operation begins
2. WHERE the backup setting is enabled, IF the backup copy fails, THEN THE Backup_Manager SHALL abort the write operation and throw a TagWriteException
3. WHERE the backup setting is disabled, THE Backup_Manager SHALL skip the backup step and proceed directly to writing
4. THE Backup_Manager SHALL expose a configurable setting accessible from the application settings page

### Requirement 8: Post-Write Validation

**User Story:** As a user, I want the app to verify that my tag changes were actually saved correctly, so that I can trust the editor is working properly.

#### Acceptance Criteria

1. WHEN a write operation completes, THE Validation_Engine SHALL re-read the written file and compare the written fields against the intended values
2. IF validation detects a mismatch between written and intended values, THEN THE Validation_Engine SHALL restore the original file from the backup (if available) and throw a TagWriteException describing which fields failed
3. IF validation detects a mismatch and no backup is available, THEN THE Validation_Engine SHALL throw a TagWriteException describing the mismatch without modifying the file further

### Requirement 9: Batch Tag Writing

**User Story:** As a user, I want to apply tag changes to multiple files at once, so that I can efficiently manage albums and compilations.

#### Acceptance Criteria

1. WHEN a map of file paths to tag maps is provided, THE Tag_Writer SHALL write tags to each file independently and return a list of TagWriteResult objects
2. IF an individual file in a batch fails to write, THEN THE Tag_Writer SHALL record the failure in the corresponding TagWriteResult and continue processing the remaining files
3. WHEN batch writing is performed, THE Tag_Writer SHALL apply atomic writes, optional backup, and post-write validation to each file individually

### Requirement 10: Service Integration and Fallback

**User Story:** As a developer, I want the TagLib FFI implementation to integrate behind the existing service interfaces with a pure-Dart read-only fallback, so that the app remains functional even if native libraries cannot load.

#### Acceptance Criteria

1. THE Tag_Reader SHALL implement the existing `TagReaderService` abstract interface without modifying the interface contract
2. THE Tag_Writer SHALL implement the existing `TagWriterService` abstract interface without modifying the interface contract
3. WHEN the native library fails to load, THE service provider SHALL fall back to the pure-Dart `Id3ReaderService` for read operations
4. WHEN the native library fails to load, THE service provider SHALL disable write operations and report the unavailability to the user rather than falling back to the unsafe pure-Dart writer
5. THE service provider SHALL select the implementation at application startup based on native library availability

### Requirement 11: FFI Binding Generation

**User Story:** As a developer, I want auto-generated FFI bindings from the TagLib C header, so that the bindings stay in sync with the native library and are maintainable.

#### Acceptance Criteria

1. THE TagLib_FFI_Service SHALL use `package:ffigen` to generate Dart FFI bindings from the `taglib_c.h` header file
2. THE generated bindings SHALL be committed to source control and regenerable via a documented command
3. THE generated bindings SHALL cover all TagLib C API functions needed for reading tags, writing tags, reading audio properties, and managing album art

### Requirement 12: Platform Binary Bundling

**User Story:** As a developer, I want pre-compiled TagLib binaries bundled per platform in the build output, so that end users do not need to install TagLib separately.

#### Acceptance Criteria

1. WHEN the application is built for Windows x64, THE build system SHALL include `taglib_c.dll` in the application bundle
2. WHEN the application is built for macOS (x64 and ARM64), THE build system SHALL include a universal `libtaglib_c.dylib` in the application bundle
3. WHEN the application is built for Linux x64, THE build system SHALL include `libtaglib_c.so` in the application bundle
4. THE bundled binaries SHALL be placed in a location discoverable by the Native_Library_Loader at runtime
