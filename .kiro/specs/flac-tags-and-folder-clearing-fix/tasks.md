# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - FLAC Non-ASCII Tag Decoding and Toolbar Clearing
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate both bugs exist
  - **Scoped PBT Approach**: Scope the property to concrete failing cases:
    - Construct a Vorbis Comment block with UTF-8 encoded CJK bytes (e.g., "東京" = `[0xE6, 0x9D, 0xB1, 0xE4, 0xBA, 0xAC]`) and verify `Id3ReaderService._readVorbisComment` returns "東京" (not garbled Latin-1)
    - Construct a Vorbis Comment block with accented Latin bytes (e.g., "Ñoño" = `[0xC3, 0x91, 0x6F, 0xC3, 0xB1, 0x6F]`) and verify correct decoding
    - For toolbar clearing: create a `FileListNotifier`, add initial files, then simulate the toolbar `_loadFromPath` flow (call `addFiles` without clearing) and assert the list contains ONLY the new files
  - Test file: `test/shared/services/id3_reader_vorbis_utf8_test.dart`
  - Run test on UNFIXED code - expect FAILURE (this confirms the bugs exist)
  - Document counterexamples found (e.g., "東京" decoded as "æ±äº¬" via Latin-1)
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - ASCII Tag Reading Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe: `Id3ReaderService._readVorbisComment` with ASCII-only bytes produces correct strings on unfixed code (e.g., "title=Hello World" → `{'title': 'Hello World'}`)
  - Observe: `String.fromCharCodes` and `utf8.decode` produce identical results for all ASCII byte sequences (bytes 0x20–0x7E)
  - Write property-based test: for 100+ random ASCII-only Vorbis Comment payloads, verify `_readVorbisComment` output matches expected key-value pairs
  - Write property-based test: for random ASCII strings of varying lengths, verify `utf8.decode(bytes)` equals `String.fromCharCodes(bytes)` (proving the fix doesn't change ASCII behavior)
  - Test file: `test/shared/services/id3_reader_preservation_property_test.dart`
  - Verify tests pass on UNFIXED code
  - _Requirements: 3.1, 3.2, 3.5, 3.6_

- [x] 3. Fix FLAC tag decoding and toolbar clearing

  - [x] 3.1 Add `taglib_set_strings_unicode(1)` call to TagLibReaderService
    - In `lib/shared/services/taglib/taglib_reader_service.dart`, call `_bindings.taglib_set_strings_unicode(1)` in the constructor of `TagLibReaderService`
    - This ensures TagLib interprets all string parameters (including file paths) as UTF-8
    - _Bug_Condition: isBugCondition(input) where input.path contains non-ASCII AND nativeLibraryAvailable_
    - _Expected_Behavior: TagLib successfully opens files at non-ASCII paths_
    - _Preservation: All existing native TagLib reading for ASCII paths remains unchanged_
    - _Requirements: 2.1_

  - [x] 3.2 Fix UTF-8 decoding in `Id3ReaderService._readVorbisComment`
    - In `lib/shared/services/id3_reader_service.dart`, add `import 'dart:convert';`
    - Replace `String.fromCharCodes(bytes.sublist(pos, pos + commentLen))` with `utf8.decode(bytes.sublist(pos, pos + commentLen), allowMalformed: true)`
    - The `allowMalformed: true` parameter ensures graceful handling of corrupted files
    - _Bug_Condition: isBugCondition(input) where input.format = FLAC AND tagValues contain non-ASCII_
    - _Expected_Behavior: Vorbis Comment values decoded as valid UTF-8 strings_
    - _Preservation: ASCII-only Vorbis Comments produce identical output (utf8.decode and String.fromCharCodes are equivalent for ASCII)_
    - _Requirements: 2.2_

  - [x] 3.3 Add clearing to toolbar `_loadFromPath` method
    - In `lib/features/tag_editor/presentation/widgets/toolbar.dart`, in `_loadFromPath`, before `notifier.addFiles(files)`, add:
      ```dart
      notifier.clear();
      ref.read(selectionProvider.notifier).clear();
      ref.read(errorLogProvider.notifier).clear();
      ```
    - Import `selection_provider.dart` if not already imported
    - _Bug_Condition: isBugCondition(input) where input.action = TOOLBAR_OPEN AND existingFileCount > 0_
    - _Expected_Behavior: File list contains only newly loaded files_
    - _Preservation: FolderLoadingService paths (drag-and-drop, address bar) remain unchanged_
    - _Requirements: 2.3_

  - [x] 3.4 Add clearing to toolbar `_openFiles` method
    - In `lib/features/tag_editor/presentation/widgets/toolbar.dart`, in `_openFiles`, before `notifier.addFiles(files)`, add:
      ```dart
      notifier.clear();
      ref.read(selectionProvider.notifier).clear();
      ref.read(errorLogProvider.notifier).clear();
      ```
    - _Bug_Condition: isBugCondition(input) where input.action = TOOLBAR_OPEN AND existingFileCount > 0_
    - _Expected_Behavior: File list contains only newly selected files_
    - _Preservation: FolderLoadingService paths remain unchanged_
    - _Requirements: 2.4_

  - [x] 3.5 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - FLAC Non-ASCII Tag Decoding and Toolbar Clearing
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bugs are fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [x] 3.6 Verify preservation tests still pass
    - **Property 2: Preservation** - ASCII Tag Reading Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all tests still pass after fix (no regressions)

- [x] 4. Checkpoint - Ensure all tests pass
  - Run full test suite: `flutter test`
  - Ensure all tests pass, ask the user if questions arise
  - Verify no regressions in existing tag reading or file loading functionality
