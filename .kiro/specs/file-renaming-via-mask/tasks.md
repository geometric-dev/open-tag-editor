# Implementation Plan: File Renaming via Mask

## Overview

Implement a token-based mask renaming engine for Open Tag Editor. The approach starts with pure-function core components (parser, evaluator, transformer, sanitizer, conflict detector), validates each with property-based tests, then builds the IO layer (executor, undo command, preset storage), state management, and finally the UI. Each step builds incrementally on the previous, ensuring no orphaned code.

## Tasks

- [x] 1. Define data models and enums
  - [x] 1.1 Create MaskToken sealed class hierarchy and TagVariable enum
    - Create `lib/features/renamer/data/models/mask_token.dart` with `MaskToken` sealed class, `LiteralToken`, `VariableToken`, and `IgnoreToken`
    - Create `lib/features/renamer/data/models/tag_variable.dart` with `TagVariable` enum (artist, title, album, year, genre, track, totalTracks, disc, totalDiscs, albumartist, comment, bpm, composer, conductor, filename, ext)
    - _Requirements: 1.1_

  - [x] 1.2 Create CaseOption enum and RenamerState model
    - Create `lib/features/renamer/data/models/case_option.dart` with `CaseOption` enum (none, lowercase, uppercase, capitalizeFirst, sentenceCase)
    - Create `lib/features/renamer/data/models/renamer_state.dart` with `RenamerState` class including pattern, tokens, parseError, caseOption, replaceUnderscores, conflictStrategy, previews, conflicts, isExecuting, executionResult
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [x] 1.3 Create RenamePreview, RenamePlan, RenameExecutionResult, and MaskPreset models
    - Create `lib/features/renamer/data/models/rename_preview.dart` with `RenamePreview` class and `RenamePreviewStatus` enum
    - Create `lib/features/renamer/data/models/rename_plan.dart` with `RenamePlan` class
    - Create `lib/features/renamer/data/models/rename_execution_result.dart` with `RenameExecutionResult` and `RenameError` classes
    - Create `lib/features/renamer/data/models/mask_preset.dart` with `MaskPreset` class
    - Create `lib/features/renamer/data/models/conflict_strategy.dart` with `ConflictStrategy` enum (skip, overwrite, autoIncrement)
    - _Requirements: 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 5.1, 6.3_

  - [x] 1.4 Create MaskParseException class
    - Create `lib/features/renamer/data/models/mask_parse_exception.dart` with position and message fields
    - _Requirements: 1.18_

- [x] 2. Implement MaskParser
  - [x] 2.1 Implement MaskParser parse and format methods
    - Create `lib/features/renamer/data/mask_parser.dart`
    - Implement `parse(String pattern)` that tokenizes a mask string into `List<MaskToken>` — recognize `%variableName` tokens, `%ignore`, and literal text segments
    - Implement `format(List<MaskToken> tokens)` that converts tokens back to a mask string
    - Throw `MaskParseException` for invalid variable names after `%`; treat trailing `%` as literal
    - _Requirements: 1.1, 1.18_

  - [ ]* 2.2 Write property test: Mask parsing round-trip (Property 1)
    - **Property 1: Mask parsing round-trip**
    - **Validates: Requirements 1.18**
    - Create `test/features/renamer/data/mask_parser_test.dart`
    - Generate random valid mask patterns (combinations of literals and tag variables)
    - Assert: `parse(format(parse(p)))` equals `parse(p)` for all valid patterns

  - [ ]* 2.3 Write property test: Tag variable substitution correctness (Property 2)
    - **Property 2: Tag variable substitution correctness**
    - **Validates: Requirements 1.1, 1.2, 1.14, 1.15**
    - In `test/features/renamer/data/mask_parser_test.dart`
    - Generate random masks with variables and audio files with non-empty tags
    - Assert: no unreplaced `%variable` tokens remain in evaluated output

  - [ ]* 2.4 Write unit tests for MaskParser
    - Test specific patterns from presets, empty pattern, pattern with only literals, consecutive variables, unknown variable names, trailing `%`
    - _Requirements: 1.1, 1.18_

- [x] 3. Implement MaskEvaluator
  - [x] 3.1 Implement MaskEvaluator evaluate method
    - Create `lib/features/renamer/data/mask_evaluator.dart`
    - Implement `evaluate(List<MaskToken> tokens, AudioFile file)` that resolves variables against file tags
    - Handle `%track`/`%disc` slash extraction and zero-padding
    - Handle `%totalTracks`/`%totalDiscs` extraction from slash format
    - Handle `%year` ISO date extraction
    - Handle `%comment` truncation to 64 chars
    - Handle `%filename` and `%ext` resolution
    - Trim whitespace from all resolved values
    - Implement delimiter collapsing for empty variables
    - Implement `%ignore` token removal with adjacent delimiter collapsing
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15, 1.16, 1.17_

  - [ ]* 3.2 Write property test: Track and disc number formatting (Property 3)
    - **Property 3: Track and disc number formatting**
    - **Validates: Requirements 1.3, 1.4, 1.5, 1.6, 1.7**
    - Create `test/features/renamer/data/mask_evaluator_test.dart`
    - Generate random track/disc values (slash-separated, plain numbers, non-numeric)
    - Assert formatting rules for each case

  - [ ]* 3.3 Write property test: Total tracks and total discs extraction (Property 4)
    - **Property 4: Total tracks and total discs extraction**
    - **Validates: Requirements 1.8, 1.9**
    - Generate track/disc values with and without slashes
    - Assert: portion after slash extracted, or empty string if no slash

  - [ ]* 3.4 Write property test: Year extraction (Property 5)
    - **Property 5: Year extraction**
    - **Validates: Requirements 1.8b, 1.9b**
    - Generate year values (ISO dates, plain years, two-digit, other formats)
    - Assert: four-digit year extracted from ISO dates, pass-through otherwise

  - [ ]* 3.5 Write property test: Comment truncation (Property 6)
    - **Property 6: Comment truncation**
    - **Validates: Requirements 1.11**
    - Generate random comment strings of varying lengths
    - Assert: output ≤ 64 chars; if input ≤ 64 chars, output equals trimmed input

  - [ ]* 3.6 Write property test: Whitespace trimming (Property 7)
    - **Property 7: Whitespace trimming**
    - **Validates: Requirements 1.12**
    - Generate tag values with leading/trailing whitespace
    - Assert: no leading/trailing whitespace in resolved output

  - [ ]* 3.7 Write property test: Delimiter collapsing on empty variables (Property 8)
    - **Property 8: Delimiter collapsing on empty variables**
    - **Validates: Requirements 1.13**
    - Generate masks with variables that resolve to empty strings
    - Assert: no double separators, no leading/trailing separators

  - [ ]* 3.8 Write property test: Ignore token removal (Property 9)
    - **Property 9: Ignore token removal**
    - **Validates: Requirements 1.17**
    - Generate masks containing `%ignore` tokens
    - Assert: ignored segments removed, adjacent delimiters collapsed

  - [ ]* 3.9 Write property test: Directory path interpretation (Property 16)
    - **Property 16: Directory path interpretation**
    - **Validates: Requirements 2.1**
    - Generate masks with directory separators
    - Assert: correct split into directory and filename portions

  - [ ]* 3.10 Write unit tests for MaskEvaluator
    - Test concrete examples: "01/12" → "01", "2023-05-14" → "2023", long comments, empty tags, `%ignore` between variables
    - _Requirements: 1.2, 1.3, 1.8, 1.11, 1.13, 1.17_

- [x] 4. Implement CaseTransformer
  - [x] 4.1 Implement CaseTransformer transform method
    - Create `lib/features/renamer/data/case_transformer.dart`
    - Implement `transform(String value, {required CaseOption option, bool replaceUnderscores = false})`
    - Handle all five case options: none, lowercase, uppercase, capitalizeFirst, sentenceCase
    - Handle replaceUnderscores preprocessing
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [ ]* 4.2 Write property test: Case transformation correctness (Property 10)
    - **Property 10: Case transformation correctness**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6**
    - Create `test/features/renamer/data/case_transformer_test.dart`
    - Generate random strings and case options
    - Assert: each option produces the specified transformation; replaceUnderscores converts `_` to space before transformation

  - [ ]* 4.3 Write unit tests for CaseTransformer
    - Test specific strings with mixed case, unicode, empty strings, strings with underscores
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement FilenameSanitizer
  - [x] 6.1 Implement FilenameSanitizer sanitize and validate methods
    - Create `lib/features/renamer/data/filename_sanitizer.dart`
    - Implement `sanitize(String filename)` that removes/replaces OS-illegal characters, returns `SanitizeResult`
    - Implement `validate(String fullPath)` that checks path length, illegal characters, reserved names
    - Create `SanitizeResult` and `ValidationError` helper classes
    - Handle platform-specific rules (Windows: `<>:"/\|?*` and reserved names; Unix: `/` and null byte)
    - _Requirements: 8.1, 8.3, 8.4, 8.5, 8.6_

  - [ ]* 6.2 Write property test: Filename sanitization idempotence (Property 12)
    - **Property 12: Filename sanitization idempotence**
    - **Validates: Requirements 8.4**
    - Create `test/features/renamer/data/filename_sanitizer_test.dart`
    - Generate random filenames including invalid characters
    - Assert: `sanitize(sanitize(x)) == sanitize(x)` and output contains no invalid characters

  - [ ]* 6.3 Write property test: Invalid filename and path validation (Property 13)
    - **Property 13: Invalid filename and path validation**
    - **Validates: Requirements 8.1, 8.3, 8.5**
    - Generate filenames with illegal characters and paths exceeding max length
    - Assert: validator returns errors for invalid inputs, no errors for valid inputs

  - [ ]* 6.4 Write property test: Reserved OS name rejection (Property 14)
    - **Property 14: Reserved OS name rejection**
    - **Validates: Requirements 8.6**
    - Generate filenames matching reserved names (CON, PRN, NUL, AUX, COM1-9, LPT1-9) with various cases and extensions
    - Assert: validator rejects all reserved names regardless of case or extension

  - [ ]* 6.5 Write unit tests for FilenameSanitizer
    - Test platform-specific illegal characters, reserved names with extensions, empty/whitespace-only filenames, max path length boundary
    - _Requirements: 8.1, 8.3, 8.4, 8.5, 8.6_

- [x] 7. Implement ConflictDetector
  - [x] 7.1 Implement ConflictDetector detectConflicts and auto-increment logic
    - Create `lib/features/renamer/data/conflict_detector.dart`
    - Implement `detectConflicts(Map<String, String> previews)` that identifies duplicate target paths
    - Implement auto-increment suffix generation for conflict resolution
    - _Requirements: 3.2, 2.6_

  - [ ]* 7.2 Write property test: Conflict detection completeness (Property 11)
    - **Property 11: Conflict detection completeness**
    - **Validates: Requirements 3.2**
    - Create `test/features/renamer/data/conflict_detector_test.dart`
    - Generate sets of rename previews with known duplicates
    - Assert: detected conflicts exactly equal actual duplicates

  - [ ]* 7.3 Write property test: Auto-increment uniqueness (Property 15)
    - **Property 15: Auto-increment uniqueness**
    - **Validates: Requirements 2.6**
    - Generate sets of conflicting target filenames
    - Assert: auto-increment produces unique filenames differing only by numeric suffix

  - [ ]* 7.4 Write unit tests for ConflictDetector
    - Test empty input, single file, all-conflicting batch, no conflicts
    - _Requirements: 3.2, 2.6_

- [x] 8. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Implement RenameExecutor and RenameCommand
  - [x] 9.1 Implement RenameExecutor with dry-run and execute methods
    - Create `lib/features/renamer/data/rename_executor.dart`
    - Implement `dryRun(List<RenamePlan> plans)` for pre-execution validation
    - Implement `execute(List<RenamePlan> plans, {required ConflictStrategy strategy})` with filesystem operations
    - Handle directory creation, conflict strategies (skip, overwrite, autoIncrement), cross-device moves, permission errors
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 6.1, 6.4, 8.1, 8.2_

  - [x] 9.2 Implement RenameCommand for undo/redo support
    - Create `lib/features/renamer/data/rename_command.dart`
    - Implement `UndoableCommand` interface with execute/undo that moves files between original and new paths
    - Handle graceful failure when files have been moved externally
    - Integrate with existing `UndoRedoManager`
    - _Requirements: 7.1, 7.2, 7.3_

  - [ ]* 9.3 Write unit tests for RenameCommand
    - Test undo/redo cycle with mock filesystem, external file move handling
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 10. Implement PresetNotifier and preset storage
  - [x] 10.1 Implement PresetNotifier and JSON-based preset persistence
    - Create `lib/features/renamer/data/preset_storage.dart` for JSON file persistence
    - Create `lib/features/renamer/data/preset_notifier.dart` with save, delete, isBuiltIn methods
    - Define built-in default presets (matching existing `RenamePattern.defaults` patterns adapted to new `%variable` syntax without trailing `%`)
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [ ]* 10.2 Write unit tests for PresetNotifier
    - Test save/load/delete cycle, built-in preset protection, persistence round-trip
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 11. Implement RenamerStateNotifier and Riverpod providers
  - [x] 11.1 Implement RenamerStateNotifier
    - Create `lib/features/renamer/data/renamer_state_notifier.dart`
    - Wire together MaskParser, MaskEvaluator, CaseTransformer, FilenameSanitizer, ConflictDetector
    - Implement `setPattern`, `setCaseOption`, `setReplaceUnderscores`, `setConflictStrategy`, `executeRename`
    - Auto-regenerate previews on pattern/option changes
    - _Requirements: 3.1, 3.4, 6.1, 6.2, 6.3_

  - [x] 11.2 Create Riverpod providers
    - Create `lib/features/renamer/data/providers/renamer_providers.dart`
    - Define `renamerStateProvider` (StateNotifierProvider), `presetProvider`, and service providers for parser, evaluator, transformer, sanitizer, conflict detector, executor
    - Wire to existing `fileListProvider`, `selectedFilesProvider`, and `undoRedoProvider`
    - _Requirements: 3.4, 6.1_

- [x] 12. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 13. Implement Mask Editor Dialog UI
  - [x] 13.1 Implement the mask editor dialog widget
    - Rewrite `lib/features/renamer/presentation/widgets/rename_dialog.dart` to use new architecture
    - Include mask pattern text field with cursor-position variable insertion
    - Include tag variable list/buttons for insertion
    - Include preset selector dropdown
    - Include case option selector and "replace underscores" toggle
    - Include conflict strategy selector
    - _Requirements: 9.1, 9.2, 9.3, 5.2_

  - [x] 13.2 Implement the preview panel widget
    - Create `lib/features/renamer/presentation/widgets/preview_panel.dart`
    - Display two-column list (original path → new path)
    - Highlight conflicts and errors with distinct visual indicators
    - Show file count summary (renamed, skipped, errors)
    - _Requirements: 3.1, 3.2, 3.3_

  - [x] 13.3 Implement rename execution UI with progress and summary
    - Add progress indicator during batch execution
    - Display completion summary (renamed count, skipped count, error count)
    - Disable rename button when no changes or conflicts unresolved
    - _Requirements: 6.2, 6.3_

  - [ ]* 13.4 Write widget tests for mask editor dialog
    - Test variable insertion at cursor, preset selection, pattern field update, preview display, conflict highlighting
    - _Requirements: 9.1, 9.2, 3.1, 3.2_

- [x] 14. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate the 16 universal correctness properties defined in the design
- Unit tests validate specific examples and edge cases
- Pure-function core components (tasks 1–8) have no filesystem dependencies and are fully testable in isolation
- IO layer (tasks 9–10) requires mock filesystem for testing
- The existing `RenamePattern` model and `RenameService` are superseded by the new implementation
