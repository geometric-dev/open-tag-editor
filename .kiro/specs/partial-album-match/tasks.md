# Implementation Plan: Partial Album Match

## Overview

Implement multi-signal track matching (filename track number, fuzzy title, duration) with a Hungarian algorithm for optimal assignment, a `PartialMatchApplicator` that separates album-level from track-level metadata, and an extended apply panel showing all files with per-file opt-out, confidence indicators, and matched/unmatched visual distinction.

## Tasks

- [x] 1. Create FilenameParser and FuzzyMatcher utilities
  - [x] 1.1 Implement FilenameParser
    - Create `lib/features/online_lookup/data/filename_parser.dart`
    - Implement `extractTrackNumber(String filename)` — parse leading digits before first non-digit separator, return int or null
    - Implement `extractTitle(String filename)` — remove extension, strip leading digits + separator, replace underscores/hyphens/dots with spaces, trim
    - _Requirements: 1.1, 1.6, 2.1_
    - _Subagent: delegate_

  - [x] 1.2 Implement FuzzyMatcher
    - Create `lib/features/online_lookup/data/fuzzy_matcher.dart`
    - Implement `similarity(String a, String b)` — Levenshtein distance normalised by longer string length, case-insensitive, returns [0.0, 1.0]
    - Handle edge cases: empty strings → 0.0, identical strings → 1.0
    - _Requirements: 2.2_
    - _Subagent: delegate_

  - [x] 1.3 Write property tests for FilenameParser (Properties 1, 2)
    - File: `test/features/online_lookup/data/filename_parser_property_test.dart`
    - **Property 1: Track number extraction** — filenames with leading digits return correct int; filenames without leading digits return null
    - **Property 2: Filename normalisation preserves words** — output has no extension, no leading digit prefix, no underscores/hyphens/dots; alphabetic tokens are subset of original
    - **Validates: Requirements 1.1, 1.6, 2.1**
    - _Subagent: delegate_

  - [x] 1.4 Write property test for FuzzyMatcher (Property 3)
    - File: `test/features/online_lookup/data/fuzzy_matcher_property_test.dart`
    - **Property 3: Fuzzy similarity is case-insensitive** — `similarity(a, b) == similarity(a.toUpperCase(), b.toLowerCase())` for any non-empty strings
    - **Validates: Requirements 2.2**
    - _Subagent: delegate_

- [x] 2. Implement multi-signal TrackMatcher
  - [x] 2.1 Extend TrackMatcher with multi-signal scoring
    - Modify `lib/features/online_lookup/data/track_matcher.dart`
    - Add `computeScore(AudioFile file, TrackInfo track)` using weighted signals: trackNumber (0.5), title (0.3), duration (0.2)
    - Implement short-title penalty (weight halved for titles ≤ 3 chars)
    - Implement minimum title similarity threshold (0.4) — below threshold, title signal treated as 0.0
    - Integrate `FilenameParser` and `FuzzyMatcher` into score computation
    - _Requirements: 1.2, 1.3, 1.4, 2.3, 2.4_
    - _Subagent: delegate_

  - [x] 2.2 Implement optimal assignment via Hungarian algorithm
    - Build score matrix for all file-track pairs
    - Implement or integrate Hungarian algorithm to find assignment maximising total score
    - Return `List<TrackFileMatch>` with composite scores and confidence levels (high ≥ 0.7, medium ≥ 0.4, low < 0.4)
    - Preserve existing order-based matching when file count equals track count
    - _Requirements: 1.5, 1.7, 1.8_
    - _Subagent: delegate_

  - [x] 2.3 Write property tests for TrackMatcher (Properties 4, 5, 6)
    - File: `test/features/online_lookup/data/track_matcher_property_test.dart`
    - **Property 4: Title signal attenuation** — short titles (≤3 chars) use half weight; scores below minTitleSimilarity contribute 0.0
    - **Property 5: Score validity and weighted composition** — computeScore returns [0.0, 1.0] and equals the weighted formula
    - **Property 6: Optimal assignment maximises total score** — for small inputs (1–5 tracks, 2–8 files), autoMatch total score ≥ any other valid assignment
    - **Validates: Requirements 1.2, 1.3, 1.4, 1.5, 1.7, 1.8, 2.3, 2.4**
    - _Subagent: delegate_

- [x] 3. Checkpoint — Core matching logic
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement PartialMatchApplicator
  - [x] 4.1 Create PartialMatchApplicator
    - Create `lib/features/online_lookup/data/partial_match_applicator.dart`
    - Define `albumFields` (album, albumArtist, year, genre) and `trackFields` (title, artist, discNumber)
    - Implement `apply()` method: iterate all non-opted-out files, write album metadata to all, write track metadata only to files with track assignment
    - Format track number as "position/totalFileCount" for partial matches
    - Leave track number unchanged on unmatched files
    - Handle cover art application to all non-opted-out files
    - Delegate actual tag writes to existing `MetadataApplicator` / `TagWriterService`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 9.1, 9.2, 9.3, 10.1, 10.2_
    - _Subagent: delegate_

  - [x] 4.2 Write property tests for PartialMatchApplicator (Properties 7, 8, 9, 10)
    - File: `test/features/online_lookup/data/partial_match_applicator_property_test.dart`
    - **Property 7: Album metadata applied to exactly non-opted-out files** — album fields written to all files not in opted-out set, regardless of match status
    - **Property 8: Track metadata applied only to matched non-opted-out files** — track fields written only to files with assignment AND not opted out
    - **Property 9: Track number formatting** — matched files get "P/N" format; unmatched files unchanged
    - **Property 10: Summary count reflects opt-out state** — count equals (matched + unmatched - opted_out)
    - **Validates: Requirements 3.1, 3.3, 3.4, 4.1, 4.3, 5.2, 5.4, 8.1, 9.1, 9.2, 10.1, 10.2**
    - _Subagent: delegate_

- [x] 5. Extend data models and state management
  - [x] 5.1 Extend TrackFileMatch and add MatchConfidence enum
    - Update `TrackFileMatch` to include optional `score` field
    - Add `high`, `medium`, `low` values to `MatchConfidence` enum with score thresholds
    - Create `PartialMatchFileEntry` UI model class
    - _Requirements: 13.1, 13.2_
    - _Subagent: delegate_

  - [x] 5.2 Extend LookupStateNotifier for partial match workflow
    - Add `isPartialMatch`, `optedOutPaths`, `allSelectedFiles` fields to lookup state
    - Implement `matchFilesPartial()` method that triggers multi-signal matching
    - Implement `toggleFileOptOut(String path)` method
    - Implement `reassignTrack(String filePath, TrackInfo? track)` method for manual reassignment
    - Implement `clearTrackAssignment(String filePath)` method
    - _Requirements: 5.1, 5.2, 5.3, 11.1, 11.2, 13.3_
    - _Subagent: delegate_

- [x] 6. Checkpoint — Domain logic and state complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Extend LookupMatchPanel for partial match activation
  - [x] 7.1 Add "Apply as Partial Match" button
    - Modify `LookupMatchPanel` to detect when `trackListing.length < selectedFiles.length`
    - Show "Apply as Partial Match" button in that scenario
    - Wire button to `LookupStateNotifier.matchFilesPartial()`
    - Preserve existing full-match workflow when track count ≥ file count
    - _Requirements: 11.1, 11.2, 11.3_
    - _Subagent: delegate_

- [x] 8. Extend LookupApplyPanel for partial match display
  - [x] 8.1 Display all selected files with matched/unmatched distinction
    - Show all selected files in the panel (matched + unmatched)
    - Group matched files before unmatched files
    - Show "Album info only" badge on unmatched file rows
    - Apply reduced opacity or distinct background to unmatched rows
    - Show full metadata preview (album + track) on matched rows
    - Show album-only metadata preview on unmatched rows
    - Show "(no change)" for track metadata fields on unmatched rows
    - Display formatted track number "P/N" in preview for matched files
    - _Requirements: 6.1, 6.2, 6.3, 7.1, 7.2, 7.3, 12.1, 12.2, 12.3_
    - _Subagent: delegate_

  - [x] 8.2 Add per-file opt-out checkboxes
    - Add checkbox/toggle per file row (matched and unmatched)
    - Default all checkboxes to checked (opted-in)
    - Wire toggle to `LookupStateNotifier.toggleFileOptOut()`
    - Update summary count on opt-out change
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
    - _Subagent: delegate_

  - [x] 8.3 Add confidence indicators and track reassignment
    - Display confidence indicator (high/medium/low) on each matched file row
    - Highlight low-confidence rows to draw user attention
    - Add reassign/clear action on matched file rows
    - Wire reassignment to `LookupStateNotifier.reassignTrack()`
    - _Requirements: 13.1, 13.2, 13.3_
    - _Subagent: delegate_

  - [x] 8.4 Add track count awareness summary
    - Display summary: "{matched} of {total} files matched to tracks • {unmatched} files will receive album info only"
    - When all files matched, show: "{total} file(s) matched"
    - Update summary to reflect opt-out count: "Applying to X of Y files"
    - _Requirements: 8.1, 8.2, 5.4_
    - _Subagent: delegate_

  - [x] 8.5 Write property test for display ordering (Property 11)
    - File: `test/features/online_lookup/presentation/partial_apply_panel_property_test.dart`
    - **Property 11: Display ordering invariant** — all matched entries appear before all unmatched entries in the displayed list
    - **Validates: Requirements 7.3**
    - _Subagent: delegate_

- [x] 9. Wire partial match apply action
  - [x] 9.1 Connect apply button to PartialMatchApplicator
    - Wire the apply panel's apply action to `PartialMatchApplicator.apply()`
    - Pass opted-out paths, selected fields, total file count, cover art, and album metadata
    - Handle per-file write failures gracefully (show "X updated, Y failed" summary)
    - Disable apply button when no fields selected and no cover art
    - _Requirements: 3.1, 4.1, 5.2, 9.1_
    - _Subagent: delegate_

- [x] 10. Write unit tests
  - [x] 10.1 Unit tests for FilenameParser
    - File: `test/features/online_lookup/data/filename_parser_test.dart`
    - Test: "01_Take_Me_Away.mp3" → trackNumber: 1, title: "Take Me Away"
    - Test: "12 - Song Name.flac" → trackNumber: 12, title: "Song Name"
    - Test: "Song Without Number.mp3" → trackNumber: null, title: "Song Without Number"
    - Test: "1.mp3" → trackNumber: 1, title: ""
    - Test: "001_a.mp3" → trackNumber: 1, title: "a"
    - _Requirements: 1.1, 1.6, 2.1_
    - _Subagent: delegate_

  - [x] 10.2 Unit tests for FuzzyMatcher
    - File: `test/features/online_lookup/data/fuzzy_matcher_test.dart`
    - Test: identical strings → 1.0
    - Test: completely different strings → close to 0.0
    - Test: "Take Me Away" vs "Take Me Away" → 1.0
    - Test: empty string vs non-empty → 0.0
    - _Requirements: 2.2_
    - _Subagent: delegate_

  - [x] 10.3 Unit tests for TrackMatcher (partial match scenarios)
    - File: `test/features/online_lookup/data/track_matcher_test.dart`
    - Test: 11 tracks, 16 files → 11 matched, 5 unmatched
    - Test: files with correct track numbers → high confidence
    - Test: files with no track numbers but matching titles → title-based matching
    - Test: conflicting signals → composite score wins
    - _Requirements: 1.5, 1.7, 1.8_
    - _Subagent: delegate_

  - [x] 10.4 Unit tests for PartialMatchApplicator
    - File: `test/features/online_lookup/data/partial_match_applicator_test.dart`
    - Test: album fields written to unmatched files
    - Test: track fields NOT written to unmatched files
    - Test: opted-out files receive nothing
    - Test: track number format "3/16" in partial mode vs "3/11" in full mode
    - _Requirements: 3.1, 3.4, 4.3, 5.2, 9.1, 9.3_
    - _Subagent: delegate_

- [x] 11. Write widget tests
  - [x] 11.1 Widget tests for LookupMatchPanel partial trigger
    - "Apply as Partial Match" button appears when trackCount < fileCount
    - Button does not appear when trackCount ≥ fileCount
    - _Requirements: 11.1, 11.3_
    - _Subagent: delegate_

  - [x] 11.2 Widget tests for LookupApplyPanel (partial mode)
    - All files displayed (matched + unmatched)
    - Checkboxes present and default to checked
    - Confidence indicators on matched rows
    - "Album info only" badge on unmatched rows
    - Unmatched rows have reduced opacity
    - Matched rows grouped before unmatched
    - Summary text shows correct counts
    - Opt-out updates summary count
    - Reassign/clear actions available on matched rows
    - _Requirements: 5.1, 5.3, 5.4, 6.1, 6.2, 6.3, 7.1, 7.2, 7.3, 8.1, 8.2, 13.1, 13.2, 13.3_
    - _Subagent: delegate_

- [x] 12. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.
  - Run `flutter analyze` and `flutter test` to confirm no regressions.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests use `package:fast_check` with minimum 100 iterations per property
- The Hungarian algorithm implementation may use an existing Dart package or a custom implementation depending on availability
- The existing order-based matching (file count == track count) is preserved unchanged
- Track number denominator logic differs between partial mode (total file count) and full mode (matched track count)

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3", "1.4", "2.1"] },
    { "id": 2, "tasks": ["2.2"] },
    { "id": 3, "tasks": ["2.3", "4.1", "5.1"] },
    { "id": 4, "tasks": ["4.2", "5.2", "10.1", "10.2"] },
    { "id": 5, "tasks": ["7.1", "10.3", "10.4"] },
    { "id": 6, "tasks": ["8.1", "8.2", "8.3", "8.4", "11.1"] },
    { "id": 7, "tasks": ["8.5", "9.1"] },
    { "id": 8, "tasks": ["11.2"] }
  ]
}
```
