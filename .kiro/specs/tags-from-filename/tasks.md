# Implementation Plan: Tags from Filename

## Overview

Implement the inverse of the file renaming via mask feature — extracting tag values from file paths using mask patterns. The approach starts with data models, then builds the pure-function core (`MaskExtractor`, `PathScopeResolver`), validates with property-based tests, then adds state management (`ExtractorStateNotifier`), the undoable write command, Riverpod providers, and finally the UI. Each step builds incrementally on the previous, maximizing reuse of existing renamer infrastructure (`MaskParser`, `MaskToken`, `TagVariable`, `CaseTransformer`, `PresetNotifier`, `PresetStorage`).

## Tasks

- [x] 1. Define data models and enums
  - [x] 1.1 Create ExtractionResult, PathScope, and WriteMode models
    - Create `lib/features/extractor/data/models/extraction_result.dart` with `ExtractionResult` class (filePath, matched, extractedTags map)
    - Create `lib/features/extractor/data/models/path_scope.dart` with `PathScope` enum (filenameOnly, relativePath, absolutePath) with displayName
    - Create `lib/features/extractor/data/models/write_mode.dart` with `WriteMode` enum (overwriteExisting, fillEmptyOnly) with displayName
    - _Requirements: 1.2, 1.3, 2.1, 4.3, 4.4_

  - [x] 1.2 Create ExtractorState, ExtractionPreview, and WriteExecutionResult models
    - Create `lib/features/extractor/data/models/extractor_state.dart` with `ExtractorState` class (pattern, tokens, parseError, extractionError, pathScope, caseOption, replaceUnderscores, trimWhitespace, writeMode, previews, deselectedFiles, isWriting, writeResult) with computed properties (matchedCount, unmatchedCount, selectedForWriteCount) and copyWith
    - Create `lib/features/extractor/data/models/extraction_preview.dart` with `ExtractionPreview` class (filePath, filename, matched, extractedTags, transformedTags)
    - Create `lib/features/extractor/data/models/write_execution_result.dart` with `WriteExecutionResult` class (writtenCount, skippedCount, errorCount, errors) and `WriteError` class (filePath, message)
    - _Requirements: 3.1, 3.2, 4.1, 4.2_

- [x] 2. Implement MaskExtractor
  - [x] 2.1 Implement MaskExtractor extract and validateForExtraction methods
    - Create `lib/features/extractor/data/mask_extractor.dart`
    - Implement `validateForExtraction(List<MaskToken> tokens)` that checks for adjacent variable/ignore tokens without a literal separator and returns an error message or null
    - Implement `extract(List<MaskToken> tokens, String path)` that:
      1. Validates tokens (no adjacent variables)
      2. Handles leading/trailing literals (verify path starts/ends with them, strip before splitting)
      3. Collects literal delimiters in order
      4. Splits path on delimiters left-to-right (first occurrence — greedy for leftmost variable)
      5. Assigns last variable all remaining text when no trailing literal
      6. Returns non-match if segment count doesn't match variable/ignore slot count
      7. Maps segments to TagVariable entries, skipping IgnoreToken segments
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 9.1, 9.2_

  - [ ]* 2.2 Write property test: Extraction splits on literal delimiters (Property 1)
    - **Property 1: Extraction splits on literal delimiters and assigns segments in order**
    - **Validates: Requirements 1.2, 1.3, 1.5**
    - Create `test/features/extractor/data/mask_extractor_test.dart`
    - Generate valid mask patterns (variables separated by literal delimiters) and matching paths
    - Assert: extracted values correspond to the segments between delimiters in left-to-right order

  - [ ]* 2.3 Write property test: Ignore token produces no tag entry (Property 2)
    - **Property 2: Ignore token produces no tag entry**
    - **Validates: Requirements 1.4**
    - In `test/features/extractor/data/mask_extractor_test.dart`
    - Generate masks with `%ignore` tokens and matching paths
    - Assert: extraction result contains no entry for ignore positions, other variables correctly assigned

  - [ ]* 2.4 Write property test: Adjacent variables without separator produce validation error (Property 3)
    - **Property 3: Adjacent variables without separator produce validation error**
    - **Validates: Requirements 1.6**
    - Generate masks with adjacent variable/ignore tokens (no literal between them)
    - Assert: `validateForExtraction` returns a non-null error message

  - [ ]* 2.5 Write property test: Greedy left-to-right delimiter matching (Property 5)
    - **Property 5: Greedy left-to-right delimiter matching**
    - **Validates: Requirements 1.8, 9.1**
    - Generate masks and paths where a segment contains the delimiter character sequence
    - Assert: split occurs at first occurrence, earlier variable gets longest prefix

  - [ ]* 2.6 Write property test: Non-matching paths are detected (Property 7)
    - **Property 7: Non-matching paths are detected**
    - **Validates: Requirements 3.2, 8.1, 8.2**
    - Generate masks and paths that do NOT match (missing delimiters, wrong segment count)
    - Assert: result has `matched == false` and empty `extractedTags`

  - [ ]* 2.7 Write property test: Last variable captures remainder (Property 12)
    - **Property 12: Last variable captures remainder**
    - **Validates: Requirements 9.2**
    - Generate masks where the last token is a variable (no trailing literal) and paths with extra text after last delimiter
    - Assert: final variable receives all remaining text

  - [ ]* 2.8 Write property test: Track values stored without modification (Property 13)
    - **Property 13: Track values stored without modification**
    - **Validates: Requirements 10.1, 10.2, 10.3**
    - Generate masks with `%track` and paths with zero-padded, non-padded, and non-numeric track values
    - Assert: extracted track value is identical to the raw segment from the filename

  - [ ]* 2.9 Write unit tests for MaskExtractor
    - Test concrete examples from PRD: `%artist/%year - %album/%track - %title` against `Pink Floyd/1973 - Dark Side of the Moon/03 - Time`
    - Test edge cases: empty pattern, single-variable mask, mask with all `%ignore`, mask with only literals, empty segments between delimiters
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 9.1, 9.2, 10.1_

- [x] 3. Implement PathScopeResolver
  - [x] 3.1 Implement PathScopeResolver resolve method
    - Create `lib/features/extractor/data/path_scope_resolver.dart`
    - Implement `resolve(AudioFile file, PathScope scope, String rootFolder)` that:
      - `filenameOnly`: returns filename without extension (no directory components)
      - `relativePath`: returns path relative to rootFolder without extension
      - `absolutePath`: returns full path without extension
    - Handle edge cases: root folder is `/`, file at root level, trailing slashes in rootFolder
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ]* 3.2 Write property test: Path scope selects correct path portion (Property 4)
    - **Property 4: Path scope selects correct path portion**
    - **Validates: Requirements 1.7, 2.2, 2.3, 2.4**
    - Create `test/features/extractor/data/path_scope_resolver_test.dart`
    - Generate audio files with random paths and root folders
    - Assert: `filenameOnly` has no directory separators and no extension; `relativePath` starts after root folder and has no extension; `absolutePath` is full path without extension

  - [ ]* 3.3 Write unit tests for PathScopeResolver
    - Test specific paths with known root folders, edge cases (root is `/`, file at root level, Windows-style paths, nested directories)
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 4. Implement value transformation logic
  - [x] 4.1 Implement value transformation pipeline in extractor context
    - The `CaseTransformer` is reused from the renamer. Add a `trimWhitespace` post-processing step in the extraction pipeline (applied after case transformation).
    - Transformation order: replace underscores → apply case option → trim whitespace
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

  - [ ]* 4.2 Write property test: Underscore replacement and whitespace trimming (Property 11)
    - **Property 11: Underscore replacement and whitespace trimming**
    - **Validates: Requirements 6.1, 6.2**
    - Create `test/features/extractor/data/value_transformer_test.dart`
    - Generate random strings with underscores and whitespace
    - Assert: when replaceUnderscores enabled, no underscores remain; when trimWhitespace enabled, no leading/trailing whitespace; transformations compose correctly (underscores first, then trimmed)

- [x] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement WriteTagsCommand
  - [x] 6.1 Implement WriteTagsCommand with execute and undo
    - Create `lib/features/extractor/data/write_tags_command.dart`
    - Implement `UndoableCommand` interface
    - `execute()`: apply extracted values to file tags via `FileListNotifier.updateFiles`, respecting `WriteMode` (overwrite vs. fill empty only)
    - `undo()`: restore previous tag values from stored snapshot
    - Store per-file previous tag maps for complete restoration
    - Handle graceful skip when file no longer exists in FileListNotifier state
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3_

  - [ ]* 6.2 Write property test: Write preserves non-mask tag fields (Property 8)
    - **Property 8: Write preserves non-mask tag fields**
    - **Validates: Requirements 4.2**
    - Create `test/features/extractor/data/write_tags_command_test.dart`
    - Generate audio files with existing tags and masks with a subset of tag variables
    - Assert: after write, tag fields NOT in the mask remain unchanged

  - [ ]* 6.3 Write property test: Write mode controls field overwriting (Property 9)
    - **Property 9: Write mode controls field overwriting**
    - **Validates: Requirements 4.3, 4.4**
    - Generate audio files with some populated and some empty tag fields
    - Assert: `overwriteExisting` replaces all; `fillEmptyOnly` only writes to empty fields

  - [ ]* 6.4 Write property test: Write-then-undo restores original tags (Property 10)
    - **Property 10: Write-then-undo restores original tags**
    - **Validates: Requirements 5.2**
    - Generate audio files with random tags, execute WriteTagsCommand, then undo
    - Assert: each file's tag map is identical to its state before execute

  - [ ]* 6.5 Write unit tests for WriteTagsCommand
    - Test execute/undo cycle with concrete tag maps, verify field preservation, test with files removed from state
    - _Requirements: 4.1, 4.2, 5.1, 5.2_

- [x] 7. Implement ExtractorStateNotifier
  - [x] 7.1 Implement ExtractorStateNotifier with full state management
    - Create `lib/features/extractor/data/extractor_state_notifier.dart`
    - Wire together `MaskParser`, `MaskExtractor`, `CaseTransformer`, `PathScopeResolver`
    - Implement `setPattern(String)`: parse tokens, validate for extraction, regenerate previews
    - Implement `setPathScope(PathScope)`: update scope, regenerate previews
    - Implement `setCaseOption(CaseOption)`: update case option, regenerate previews
    - Implement `setReplaceUnderscores(bool)`: toggle, regenerate previews
    - Implement `setTrimWhitespace(bool)`: toggle, regenerate previews
    - Implement `setWriteMode(WriteMode)`: update write mode
    - Implement `toggleFileSelection(String)`: add/remove from deselectedFiles set
    - Implement `writeTags()`: create WriteTagsCommand, execute via UndoRedoManager, return WriteExecutionResult
    - Preview generation: for each file, resolve path scope → extract → transform → build ExtractionPreview
    - _Requirements: 3.1, 3.4, 4.1, 5.1, 6.1, 6.2_

  - [ ]* 7.2 Write unit tests for ExtractorStateNotifier
    - Test state transitions: pattern change triggers preview regeneration, scope change triggers preview, option toggles regenerate previews
    - Test writeTags flow with mock FileListNotifier and UndoRedoManager
    - _Requirements: 3.1, 3.4, 4.1, 5.1_

- [x] 8. Implement Riverpod providers
  - [x] 8.1 Create extractor providers
    - Create `lib/features/extractor/data/providers/extractor_providers.dart`
    - Define `extractorStateProvider` (StateNotifierProvider.autoDispose) wired to `fileListProvider`, `selectionProvider`, `undoRedoProvider`, and folder root
    - Reuse existing `presetProvider` from renamer providers (shared preset pool)
    - _Requirements: 7.1, 7.4_

- [x] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Implement Mask Parser round-trip property test
  - [ ]* 10.1 Write property test: Mask parsing round-trip (Property 6)
    - **Property 6: Mask parsing round-trip**
    - **Validates: Requirements 1.9**
    - Create `test/features/extractor/data/mask_parser_roundtrip_test.dart`
    - Generate random valid mask patterns (combinations of literals and tag variables)
    - Assert: `parse(format(parse(pattern)))` produces token list equivalent to `parse(pattern)`

- [x] 11. Implement ExtractorDialog UI
  - [x] 11.1 Implement the extractor dialog widget
    - Create `lib/features/extractor/presentation/widgets/extractor_dialog.dart`
    - Include mask pattern text field with inline error display
    - Include path scope selector (dropdown or radio group for filenameOnly/relativePath/absolutePath)
    - Include case option selector (reuse pattern from renamer dialog)
    - Include "Replace underscores with spaces" toggle
    - Include "Trim whitespace" toggle (default on)
    - Include write mode selector (overwrite existing / only fill empty)
    - Include preset selector dropdown (reusing shared PresetNotifier)
    - Include "Write Tags" button (disabled when no files match)
    - _Requirements: 2.1, 3.3, 4.3, 4.4, 6.1, 6.2, 7.2, 7.5, 9.1_

  - [x] 11.2 Implement the preview panel widget
    - Create `lib/features/extractor/presentation/widgets/extractor_preview_panel.dart`
    - Display tabular preview: filename column + one column per tag variable in the mask
    - Highlight non-matching files with distinct visual indicator
    - Show per-file deselection checkboxes for matched files
    - Display summary counts (matched, unmatched, selected for write)
    - _Requirements: 3.1, 3.2, 3.3, 3.5, 8.3, 8.5_

  - [x] 11.3 Implement write execution UI with progress and summary
    - Add progress indicator during batch write
    - Display completion summary (written count, skipped count, error count)
    - Disable "Write Tags" button during execution and when no matches
    - _Requirements: 4.1, 4.6, 8.4_

  - [ ]* 11.4 Write widget tests for extractor dialog
    - Test mask input field, scope selector, option toggles, preset dropdown, preview display, write button state, non-match highlighting
    - _Requirements: 2.1, 3.1, 3.2, 3.3, 7.2_

- [x] 12. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate the 13 universal correctness properties defined in the design
- Unit tests validate specific examples and edge cases
- Pure-function core components (tasks 1–4) have no I/O dependencies and are fully testable in isolation
- The feature reuses `MaskParser`, `MaskToken`, `TagVariable`, `CaseTransformer`, `PresetNotifier`, and `PresetStorage` from the renamer feature — no duplication
- The shared preset pool means presets saved in either feature are available in both
