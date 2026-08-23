# Implementation Plan: Recursive Folder Separators

## Overview

Implement folder separator rows in the DataGrid for recursive loading mode. The approach introduces a `GridItem` sealed class hierarchy, a pure `buildGridItems` function for computing the mixed file/separator list, navigation helpers for skipping separators, a `gridItemsProvider` for reactive state, and a `FolderSeparatorRow` widget. The DataGrid is then updated to render from grid items and skip separators during selection/navigation.

## Tasks

- [x] 1. Create GridItem model and pure computation logic
  - [x] 1.1 Create GridItem sealed class hierarchy
    - Create `lib/features/tag_editor/data/models/grid_item.dart`
    - Define `sealed class GridItem`
    - Define `FileGridItem` with `file: AudioFile` and `fileIndex: int` fields
    - Define `SeparatorGridItem` with `relativePath: String` field
    - _Requirements: 1.1, 2.2_
    - _Subagent: delegate_

  - [x] 1.2 Implement computeRelativePath pure function
    - Create `lib/features/tag_editor/data/models/grid_item.dart` (add to same file or separate utility)
    - Implement `String computeRelativePath(String folderPath, String rootFolder)`
    - Normalise platform path separators before computing relative path
    - Replace platform separators with " / " (space-slash-space) in output
    - When folderPath equals rootFolder, return only the final segment of rootFolder
    - _Requirements: 1.2, 1.3_
    - _Subagent: delegate_

  - [x] 1.3 Implement buildGridItems pure function
    - Create `lib/features/tag_editor/data/providers/grid_items_provider.dart`
    - Implement `List<GridItem> buildGridItems({required List<AudioFile> files, required String? rootFolder, required bool isRecursive, required bool isSorted})`
    - When `isRecursive` is false or `isSorted` is true, return `FileGridItem` wrappers only
    - When separators are shown: group files by parent directory, sort groups alphabetically (root first), sort files within groups by filename (case-insensitive), insert `SeparatorGridItem` before each group
    - Handle null rootFolder by returning FileGridItem wrappers only
    - Handle empty file list by returning empty list
    - Only insert separators for directories that directly contain files (not intermediate dirs)
    - _Requirements: 1.1, 1.4, 1.5, 4.1, 4.2, 4.3_
    - _Subagent: delegate_

- [x] 2. Create navigation helpers and gridItemsProvider
  - [x] 2.1 Implement navigation helper functions
    - Create `lib/features/tag_editor/presentation/helpers/grid_navigation.dart`
    - Implement `int? nextFileRowIndex(List<GridItem> items, int currentIndex)` — returns next FileGridItem index or null
    - Implement `int? previousFileRowIndex(List<GridItem> items, int currentIndex)` — returns previous FileGridItem index or null
    - Implement `List<String> filePathsFromGridItems(List<GridItem> items)` — extracts file paths excluding separators
    - _Requirements: 2.3, 2.5, 2.6_
    - _Subagent: delegate_

  - [x] 2.2 Create gridItemsProvider
    - Add `gridItemsProvider` to `lib/features/tag_editor/data/providers/grid_items_provider.dart`
    - Watch `filteredSortedFileListProvider`, `recursiveLoadingProvider`, `sortStateProvider`, `loadedFolderPathProvider`
    - Delegate to `buildGridItems` pure function
    - _Requirements: 1.1, 4.3, 5.5_
    - _Subagent: delegate_

- [x] 3. Checkpoint - Verify core logic compiles
  - Ensure `flutter analyze` passes with no errors on new files, ask the user if questions arise.

- [x] 4. Create FolderSeparatorRow widget
  - [x] 4.1 Implement FolderSeparatorRow widget
    - Create `lib/features/tag_editor/presentation/widgets/data_grid/folder_separator_row.dart`
    - Wrap in `IgnorePointer` to block all pointer interactions
    - Use same height as `DataGrid.rowHeight` (28px itemExtent)
    - Render with `colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)` background
    - Display folder icon (14px), 8px SizedBox gap, then Expanded Text with relativePath
    - Text style: fontSize 12, fontWeight bold, colorScheme.onSurfaceVariant
    - Text overflow: ellipsis
    - Span full width (no column boundaries)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 2.1_
    - _Subagent: delegate_

- [x] 5. Integrate grid items into DataGrid
  - [x] 5.1 Update DataGrid to render from gridItemsProvider
    - Modify `lib/features/tag_editor/presentation/widgets/data_grid/data_grid.dart`
    - Replace direct file list iteration with `gridItemsProvider` watch
    - Pattern-match each `GridItem`: render `FolderSeparatorRow` for `SeparatorGridItem`, existing `_DataRow` for `FileGridItem`
    - Update `itemCount` to use grid items length
    - Maintain fixed `itemExtent` for both row types (same height)
    - Update total scroll extent calculation to include separator rows
    - _Requirements: 1.1, 6.1, 6.2, 6.3_
    - _Subagent: main thread (cross-file wiring)_

  - [x] 5.2 Update keyboard navigation to skip separators
    - Modify arrow key handlers (Arrow Up/Down, Shift+Arrow) to use `nextFileRowIndex` / `previousFileRowIndex`
    - Modify Tab/Shift+Tab inline edit navigation to use navigation helpers
    - Ensure focus always lands on a FileGridItem
    - _Requirements: 2.3, 2.6_
    - _Subagent: main thread (cross-file wiring)_

  - [x] 5.3 Update selection logic to exclude separators
    - Modify single-click, Ctrl+click, Shift+click handlers to operate on FileGridItem indices only
    - Update Ctrl+A to select all file paths via `filePathsFromGridItems`
    - Update marquee/rubber-band selection to filter out separator indices
    - Ensure separator rows never appear in selection state
    - _Requirements: 2.2, 2.4, 2.5_
    - _Subagent: main thread (cross-file wiring)_

  - [x] 5.4 Implement scroll preservation on separator add/remove
    - When sort is toggled or filter changes cause separators to appear/disappear, preserve scroll offset so previously visible content remains in view
    - Compute which file was at top of viewport before change, scroll to maintain visibility after change
    - Clamp scroll offset to valid bounds if top file is filtered out
    - _Requirements: 6.4_
    - _Subagent: main thread (cross-file wiring)_

- [x] 6. Checkpoint - Verify integration compiles and basic behaviour works
  - Ensure `flutter analyze` passes and `flutter test` runs without new failures, ask the user if questions arise.

- [x] 7. Write unit tests for pure functions
  - [x] 7.1 Unit tests for computeRelativePath
    - File: `test/features/tag_editor/data/models/grid_item_test.dart`
    - Test single level deep, multiple levels, root folder itself, Windows paths, Unix paths, trailing separators
    - _Requirements: 1.2, 1.3_
    - _Subagent: delegate_

  - [x] 7.2 Unit tests for buildGridItems
    - File: `test/features/tag_editor/data/providers/grid_items_test.dart`
    - Test: recursive=false → no separators; sort active → no separators; empty list → empty output; single file; all files in root; multi-folder ordering (root first, alphabetical); intermediate dirs skipped
    - _Requirements: 1.1, 1.4, 1.5, 4.1, 4.2, 4.3_
    - _Subagent: delegate_

  - [x] 7.3 Unit tests for navigation helpers
    - File: `test/features/tag_editor/presentation/helpers/grid_navigation_test.dart`
    - Test: adjacent file rows, multiple separators in a row, at boundaries, out of bounds, filePathsFromGridItems excludes separators
    - _Requirements: 2.3, 2.6_
    - _Subagent: delegate_

- [ ] 8. Write property-based tests
  - [ ]* 8.1 Property 1: Separator insertion correctness
    - **Property 1: Separator insertion correctness**
    - For any list of audio files with various parent directories and a valid root folder, `buildGridItems` (recursive enabled, no sort) inserts exactly one SeparatorGridItem before each contiguous group of files sharing the same parent directory, and no separators for directories with no direct files
    - **Validates: Requirements 1.1, 1.5**
    - File: `test/features/tag_editor/data/providers/grid_items_properties_test.dart`
    - _Subagent: delegate_

  - [ ]* 8.2 Property 2: Relative path formatting round-trip
    - **Property 2: Relative path formatting round-trip**
    - For any valid root folder path and any descendant subfolder path, `computeRelativePath` produces a string where splitting on " / " and re-joining with the platform separator reconstructs the original subfolder path. When subfolder equals root, result is the final path segment.
    - **Validates: Requirements 1.2, 1.3**
    - File: `test/features/tag_editor/data/providers/grid_items_properties_test.dart`
    - _Subagent: delegate_

  - [ ]* 8.3 Property 3: Sort suppresses all separators
    - **Property 3: Sort suppresses all separators**
    - For any list of audio files and any active sort state (isSorted=true), `buildGridItems` returns zero SeparatorGridItem instances regardless of recursive loading state
    - **Validates: Requirements 1.4, 4.3, 5.5**
    - File: `test/features/tag_editor/data/providers/grid_items_properties_test.dart`
    - _Subagent: delegate_

  - [ ]* 8.4 Property 4: Selection excludes separators
    - **Property 4: Selection excludes separators**
    - For any list of grid items produced by `buildGridItems`, `filePathsFromGridItems` returns only paths from FileGridItem entries and never contains entries corresponding to SeparatorGridItem rows
    - **Validates: Requirements 2.2, 2.5**
    - File: `test/features/tag_editor/data/providers/grid_items_properties_test.dart`
    - _Subagent: delegate_

  - [ ]* 8.5 Property 5: Navigation always lands on a file row
    - **Property 5: Navigation always lands on a file row**
    - For any list of grid items containing at least one FileGridItem and any valid starting index, `nextFileRowIndex` returns an index pointing to a FileGridItem (or null). Same for `previousFileRowIndex` in reverse.
    - **Validates: Requirements 2.3, 2.6**
    - File: `test/features/tag_editor/data/providers/grid_items_properties_test.dart`
    - _Subagent: delegate_

  - [ ]* 8.6 Property 6: Default ordering — folders alphabetical, root first
    - **Property 6: Default ordering — folders alphabetical, root first**
    - For any list of audio files spanning multiple directories, when buildGridItems produces separators, SeparatorGridItem entries appear in case-insensitive alphabetical order of relativePath with root separator first. Within each group, FileGridItem entries are ordered by filename case-insensitively.
    - **Validates: Requirements 4.1, 4.2**
    - File: `test/features/tag_editor/data/providers/grid_items_properties_test.dart`
    - _Subagent: delegate_

  - [ ]* 8.7 Property 7: Separator visibility tracks visible files
    - **Property 7: Separator visibility tracks visible files**
    - For any list of audio files and any filter applied, `buildGridItems` (applied to the filtered list) produces a SeparatorGridItem for a directory if and only if at least one file in that directory is present in the filtered list
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4**
    - File: `test/features/tag_editor/data/providers/grid_items_properties_test.dart`
    - _Subagent: delegate_

  - [ ]* 8.8 Property 8: Total grid item count invariant
    - **Property 8: Total grid item count invariant**
    - For any output of `buildGridItems`, total items equals FileGridItem count plus SeparatorGridItem count, and FileGridItem count equals input file list length
    - **Validates: Requirements 6.2**
    - File: `test/features/tag_editor/data/providers/grid_items_properties_test.dart`
    - _Subagent: delegate_

- [ ] 9. Write widget tests
  - [ ]* 9.1 FolderSeparatorRow widget tests
    - Verify folder icon present, 8px gap, bold text, ellipsis overflow, distinct background colour
    - Verify IgnorePointer blocks tap, double-tap, right-click
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 2.1_
    - _Subagent: delegate_

  - [ ]* 9.2 DataGrid integration widget tests
    - Verify separator rows appear between file groups in recursive mode
    - Verify no separator rows when sort is active
    - Verify arrow key navigation skips separator rows
    - Verify Tab/Shift+Tab skips separator rows during inline editing
    - Verify marquee selection excludes separator rows
    - _Requirements: 1.1, 2.3, 2.5, 2.6, 4.3_
    - _Subagent: delegate_

  - [ ]* 9.3 Scroll preservation widget tests
    - Verify scroll position maintained when toggling sort on/off
    - Verify scroll position maintained when filter adds/removes separators
    - _Requirements: 6.4_
    - _Subagent: delegate_

- [x] 10. Final checkpoint
  - Ensure all tests pass with `flutter test`, run `flutter analyze`, and verify build with `flutter build windows`. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests use `package:fast_check` with minimum 100 iterations per property
- The `GridItem` sealed class enables exhaustive pattern matching in Dart 3
- Navigation helpers are pure functions for easy testability
- Separator rows use the same fixed height (28px) as file rows to maintain virtualized scroll performance
- `CellCoordinate.rowIndex` maps to `FileGridItem.fileIndex`, not the grid item index, preserving inline editing compatibility

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["2.1", "2.2"] },
    { "id": 3, "tasks": ["4.1", "7.1"] },
    { "id": 4, "tasks": ["5.1", "7.2", "7.3"] },
    { "id": 5, "tasks": ["5.2", "5.3"] },
    { "id": 6, "tasks": ["5.4"] },
    { "id": 7, "tasks": ["8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8"] },
    { "id": 8, "tasks": ["9.1", "9.2", "9.3"] }
  ]
}
```
