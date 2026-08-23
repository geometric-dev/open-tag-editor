# FLAC Tags and Folder Clearing Bugfix Design

## Overview

Two bugs affect the core file loading workflow:

1. **FLAC tag reading fails for non-ASCII content** — The native TagLib FFI layer never calls `taglib_set_strings_unicode(1)`, so file paths with non-ASCII characters fail to open on Windows. Additionally, the fallback `Id3ReaderService` decodes Vorbis Comment bytes using `String.fromCharCodes` (Latin-1 interpretation) instead of UTF-8, garbling non-ASCII tag values.

2. **Toolbar file/folder loading appends instead of replacing** — The `_openFolder` and `_openFiles` methods in `toolbar.dart` call `notifier.addFiles(files)` without first clearing the existing file list, selection state, or error log. The `FolderLoadingService` (used by drag-and-drop and address bar) already does this correctly.

The fix is minimal and targeted: add the missing `taglib_set_strings_unicode(1)` call during library initialization, use `utf8.decode` in the Vorbis Comment reader, and add clearing calls to the toolbar methods.

## Glossary

- **Bug_Condition (C)**: The union of two conditions — (1) a FLAC file with non-ASCII path or tag values is read, OR (2) the user opens files/folders via the toolbar when files are already loaded
- **Property (P)**: (1) Tags are correctly decoded as UTF-8, (2) Previous files are cleared before new ones are loaded
- **Preservation**: MP3 tag reading, ASCII-only FLAC reading, drag-and-drop loading, address bar loading, and startup loading must remain unchanged
- **TagLibReaderService**: The FFI-based reader in `lib/shared/services/taglib/taglib_reader_service.dart` that uses native TagLib
- **Id3ReaderService**: The pure-Dart fallback reader in `lib/shared/services/id3_reader_service.dart`
- **FolderLoadingService**: The utility class in `lib/features/tag_editor/data/providers/folder_loading_provider.dart` that correctly clears state before loading
- **EditorToolbar**: The widget in `lib/features/tag_editor/presentation/widgets/toolbar.dart` containing `_openFolder` and `_openFiles`

## Bug Details

### Bug Condition

The bugs manifest in two independent scenarios:

**Bug A — FLAC Tag Decoding:**
The system fails to read tags when either (a) the file path contains non-ASCII characters and the native TagLib library is used, or (b) the file contains non-ASCII Vorbis Comment values and the fallback reader is used.

**Bug B — Toolbar File Clearing:**
The system appends files instead of replacing them when the user opens a new folder or files via the toolbar buttons, but only when files are already loaded.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type FileLoadAction
  OUTPUT: boolean
  
  // Bug A: FLAC tag decoding
  IF input.action = READ_TAGS THEN
    RETURN (input.path contains non-ASCII characters AND nativeLibraryAvailable)
           OR (input.format = FLAC AND input.tagValues contain non-ASCII AND NOT nativeLibraryAvailable)
  END IF
  
  // Bug B: Toolbar clearing
  IF input.action = TOOLBAR_OPEN THEN
    RETURN input.existingFileCount > 0
  END IF
  
  RETURN false
END FUNCTION
```

### Examples

- **Bug A1**: File at path `C:\Music\⭐️ Favorites\song.flac` — TagLib fails to open because path bytes are interpreted as locale-encoded (native reader)
- **Bug A2**: FLAC file with artist tag "東京事変" — `String.fromCharCodes` produces garbled output like "æ±äº¬äºå¤" (fallback reader)
- **Bug B1**: User has 10 MP3 files loaded, clicks "Open Folder" and selects a new folder with 5 files — result shows 15 files instead of 5
- **Bug B2**: User has files loaded, clicks "Open Files" and selects 3 files — result shows old files plus 3 new files

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- MP3 files with ID3v2 tags must continue to read correctly via both native and fallback readers
- FLAC files with ASCII-only tag values must continue to read correctly
- Drag-and-drop file loading must continue to clear previous files (already works via `FolderLoadingService.loadFromDrop`)
- Address bar folder loading must continue to clear previous files (already works via `FolderLoadingService.loadFolder`)
- Startup last-folder loading must continue to work correctly
- All other audio formats (M4A, OGG, WMA, APE) must continue to read correctly via native TagLib

**Scope:**
All inputs that do NOT involve non-ASCII FLAC content or toolbar-based file opening should be completely unaffected by this fix. This includes:
- Reading MP3 files with any tag content
- Reading FLAC files with ASCII-only tags
- Loading files via drag-and-drop
- Loading folders via the address bar
- Auto-loading the last folder on startup

## Hypothesized Root Cause

### Bug A — FLAC Tag Decoding

1. **Missing `taglib_set_strings_unicode(1)` call**: The `NativeLibraryLoader.load()` returns the `DynamicLibrary` but never configures TagLib for Unicode string handling. On Windows, TagLib defaults to locale encoding for file paths. The binding `taglib_set_strings_unicode` exists in `taglib_bindings.g.dart` but is never invoked.

2. **Latin-1 decoding of Vorbis Comments**: In `Id3ReaderService._readVorbisComment`, the line:
   ```dart
   final comment = String.fromCharCodes(bytes.sublist(pos, pos + commentLen));
   ```
   interprets each byte as a Unicode code point (effectively Latin-1). The Vorbis Comment specification mandates UTF-8 encoding, so this should use `utf8.decode`.

### Bug B — Toolbar File Clearing

3. **Missing clear calls in toolbar methods**: The `_openFiles` method calls `notifier.addFiles(files)` directly without clearing first. The `_loadFromPath` method (used by `_openFolder`) also calls `notifier.addFiles(files)` without clearing. Compare with `FolderLoadingService._loadFiles` which correctly calls:
   ```dart
   _ref.read(fileListProvider.notifier).clear();
   _ref.read(selectionProvider.notifier).clear();
   _ref.read(errorLogProvider.notifier).clear();
   ```

## Correctness Properties

Property 1: Bug Condition - FLAC Non-ASCII Tag Decoding

_For any_ FLAC file input where tag values contain non-ASCII UTF-8 characters (CJK, accented Latin, Cyrillic, emoji), the fallback `Id3ReaderService._readVorbisComment` function SHALL decode the Vorbis Comment values as valid UTF-8 strings that match the original encoded content, without garbling or data loss.

**Validates: Requirements 2.1, 2.2**

Property 2: Preservation - ASCII Tag Reading and Toolbar Clearing

_For any_ input where the file contains only ASCII tag values (isBugCondition returns false for Bug A), the fixed `_readVorbisComment` function SHALL produce the same result as the original function. Additionally, _for any_ toolbar open action, the file list after loading SHALL contain exactly the newly loaded files with no remnants from previous loads.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**

## Fix Implementation

### Changes Required

**File**: `lib/shared/services/taglib/taglib_reader_service.dart`

**Function**: `TagLibReaderService` constructor or `readTags`

**Specific Changes**:
1. **Add `taglib_set_strings_unicode(1)` call**: Call this once when the `TagLibReaderService` is first created, or ensure it's called before the first `taglib_file_new` invocation. This configures TagLib to treat all string parameters as UTF-8.

---

**File**: `lib/shared/services/id3_reader_service.dart`

**Function**: `_readVorbisComment`

**Specific Changes**:
2. **Import `dart:convert`**: Add `import 'dart:convert';` at the top of the file.
3. **Replace `String.fromCharCodes` with `utf8.decode`**: Change:
   ```dart
   final comment = String.fromCharCodes(bytes.sublist(pos, pos + commentLen));
   ```
   to:
   ```dart
   final comment = utf8.decode(bytes.sublist(pos, pos + commentLen), allowMalformed: true);
   ```

---

**File**: `lib/features/tag_editor/presentation/widgets/toolbar.dart`

**Function**: `_openFiles`

**Specific Changes**:
4. **Add clearing before `addFiles`**: Before calling `notifier.addFiles(files)`, add:
   ```dart
   notifier.clear();
   ref.read(selectionProvider.notifier).clear();
   ref.read(errorLogProvider.notifier).clear();
   ```

**Function**: `_loadFromPath`

**Specific Changes**:
5. **Add clearing before `addFiles`**: Before calling `notifier.addFiles(files)`, add:
   ```dart
   notifier.clear();
   ref.read(selectionProvider.notifier).clear();
   ref.read(errorLogProvider.notifier).clear();
   ```

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bugs on unfixed code, then verify the fixes work correctly and preserve existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate both bugs BEFORE implementing the fix. Confirm or refute the root cause analysis.

**Test Plan**: Write unit tests that exercise the `_readVorbisComment` method with non-ASCII UTF-8 byte sequences, and write widget/unit tests that verify toolbar methods append instead of replacing.

**Test Cases**:
1. **Vorbis Comment UTF-8 Test**: Create a byte array representing a Vorbis Comment block with CJK characters encoded as UTF-8, call `_readVorbisComment`, assert the decoded string matches the original (will fail on unfixed code — Latin-1 decoding produces garbled output)
2. **Vorbis Comment Accented Latin Test**: Create Vorbis Comment with accented characters like "Ñoño", verify correct decoding (will fail on unfixed code)
3. **Toolbar Open Folder Clearing Test**: Simulate loading files, then calling `_loadFromPath` — verify old files are gone (will fail on unfixed code — files accumulate)
4. **Toolbar Open Files Clearing Test**: Simulate loading files, then calling `_openFiles` flow — verify old files are gone (will fail on unfixed code)

**Expected Counterexamples**:
- `_readVorbisComment` with UTF-8 bytes `[0xE6, 0x9D, 0xB1, 0xE4, 0xBA, 0xAC]` ("東京") returns garbled string instead of "東京"
- File list contains 15 entries after opening a 5-file folder when 10 files were previously loaded

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed functions produce the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  IF input.action = READ_TAGS THEN
    result := readVorbisComment_fixed(input.bytes)
    ASSERT result = utf8.decode(input.bytes)
  END IF
  IF input.action = TOOLBAR_OPEN THEN
    result := toolbarOpen_fixed(input.newFiles)
    ASSERT fileList = input.newFiles  // no old files remain
  END IF
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed functions produce the same result as the original functions.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT readVorbisComment_original(input) = readVorbisComment_fixed(input)
  ASSERT toolbarOpen_original(input) = toolbarOpen_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many random ASCII-only Vorbis Comment payloads to verify identical decoding
- It catches edge cases (empty strings, single characters, max-length values)
- It provides strong guarantees that ASCII behavior is unchanged

**Test Plan**: Observe behavior on UNFIXED code first for ASCII-only Vorbis Comments and toolbar operations, then write property-based tests capturing that behavior.

**Test Cases**:
1. **ASCII Vorbis Comment Preservation**: For all ASCII-only Vorbis Comment byte sequences, verify `_readVorbisComment` produces identical output before and after fix
2. **MP3 Tag Reading Preservation**: Verify MP3 ID3v2 tag reading is completely unaffected by the UTF-8 change
3. **Drag-and-Drop Preservation**: Verify drag-and-drop loading continues to clear and load correctly
4. **Address Bar Preservation**: Verify address bar folder loading continues to clear and load correctly

### Unit Tests

- Test `_readVorbisComment` with various UTF-8 encoded strings (CJK, Cyrillic, emoji, accented Latin)
- Test `_readVorbisComment` with ASCII-only strings (preservation)
- Test `_readVorbisComment` with malformed UTF-8 (graceful handling via `allowMalformed: true`)
- Test toolbar `_loadFromPath` clears file list before adding
- Test toolbar `_openFiles` clears file list before adding

### Property-Based Tests

- Generate random valid UTF-8 strings, encode as Vorbis Comment bytes, verify round-trip decoding matches original
- Generate random ASCII strings, verify `_readVorbisComment` output is identical to `String.fromCharCodes` (preservation)
- Generate random file lists of varying sizes, verify toolbar operations always result in exactly the new files

### Integration Tests

- Test full flow: load FLAC files with non-ASCII tags via fallback reader, verify tags display correctly
- Test full flow: open folder via toolbar, then open another folder, verify only second folder's files are shown
- Test full flow: open files via toolbar, then open different files, verify only second set is shown
