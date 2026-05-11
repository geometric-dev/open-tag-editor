# Implementation Plan: Folder Loading & File Display

## Overview

This plan implements the full-featured file list panel per PRD 01, building incrementally on the existing `FileListPanel`. We start with data models and utility functions, then state management, then presentation widgets, wiring everything together at the end.

## Tasks

- [x] 1. Extend data models and add utility functions
  - [x] 1.1 Add `tagFormat` field to `AudioFile` model
    - Add `TagFormat` enum to `lib/shared/models/audio_file.dart` with values: `id3v1`, `id3v2_3`, `id3v2_4`, `vorbisComment`, `ape`, `unknown`
    - Add optional `tagFormat` field to `AudioFile` class
    - Update `copyWith`, `props`, and constructor
    - _Requirements: 1.4, 1.5_

  - [x] 1.2 Create `ColumnDefinition` model and default column list
    - Create `lib/features/tag_editor/data/models/column_definition.dart`
    - Define `ColumnDefinition` class with `id`, `label`, `defaultWidth`, `isFixed`, `valueExtractor`
    - Define the 17 default columns constant list (tagIndicator, filename, title, artist, album, year, genre, trackNumber, discNumber, bitrate, duration, albumArtist, comment, bpm, composer, conductor, relativePath)
    - Implement value extractors for each column (tag lookup, duration formatting, bitrate formatting, relative path computation)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 1.3 Create `SortState` model and `ColumnConfig` model
    - Create `lib/features/tag_editor/data/models/sort_state.dart` with `SortState` class and `SortDirection` enum
    - Create `lib/features/tag_editor/data/models/column_config.dart` with `ColumnConfig` class holding `visibleColumnIds` and `columnOrder`
    - _Requirements: 3.1, 4.1_

  - [x] 1.4 Create `SelectionState` model
    - Create `lib/features/tag_editor/data/models/selection_state.dart` with `SelectionState` class holding `selectedPaths` set and `anchorPath`
    - _Requirements: 6.1, 6.2, 6.3_

  - [x] 1.5 Implement formatting utility functions
    - Create `lib/core/utils/format_utils.dart`
    - Implement `formatDuration(double? seconds)` → "mm:ss" or "h:mm:ss"
    - Implement `formatTotalDuration(double totalSeconds)` → "Xh Ym"
    - Implement `formatFileSize(int bytes)` → human-readable units
    - Implement `computeRelativePath(String filePath, String rootFolder)` → relative path string
    - Implement `computeCommonParentDirectory(List<String> paths)` → common parent directory
    - _Requirements: 2.2, 2.3, 2.4, 7.3, 7.5, 8.4_

  - [ ]* 1.6 Write property tests for formatting utilities
    - **Property 2: Duration formatting follows time format rules**
    - **Property 3: Relative path computation strips root prefix**
    - **Property 14: File size formatting produces correct units**
    - **Property 15: Common parent directory computation**
    - **Validates: Requirements 2.2, 2.4, 7.5, 8.4**

  - [ ]* 1.7 Write property tests for column value extraction
    - **Property 1: Tag indicator state reflects tag presence**
    - **Property 4: Missing tag values produce empty strings**
    - **Validates: Requirements 1.2, 1.3, 2.5**

- [x] 2. Implement state management notifiers
  - [x] 2.1 Implement `SortStateNotifier`
    - Create `lib/features/tag_editor/data/providers/sort_state_provider.dart`
    - Implement three-click cycle: unsorted → ascending → descending → unsorted
    - Expose `toggleSort(String columnId)` method
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ]* 2.2 Write property test for sort state three-click cycle
    - **Property 6: Sort state three-click cycle**
    - **Validates: Requirements 3.3**

  - [x] 2.3 Implement `ColumnConfigNotifier` with persistence
    - Create `lib/features/tag_editor/data/providers/column_config_provider.dart`
    - Load/save column config from `shared_preferences` (key: `column_config_v1`)
    - Implement `toggleVisibility(String columnId)` — prevent hiding fixed columns
    - Implement `reorderColumn(int oldIndex, int newIndex)` — prevent moving tagIndicator from position 0
    - Implement `resetToDefaults()`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3_

  - [ ]* 2.4 Write property tests for column config operations
    - **Property 7: Column visibility toggle round-trip**
    - **Property 8: Fixed columns invariant**
    - **Property 9: Column reorder moves to target position**
    - **Validates: Requirements 4.2, 4.3, 4.5, 5.1, 5.3**

  - [x] 2.5 Implement `SelectionNotifier` with range selection
    - Create `lib/features/tag_editor/data/providers/selection_provider.dart`
    - Implement `select(String path)` — single click, replaces selection, sets anchor
    - Implement `toggleSelect(String path)` — Ctrl+click, toggles one path
    - Implement `rangeSelect(String path, List<String> orderedPaths)` — Shift+click, selects contiguous range from anchor
    - Implement `selectAll(List<String> paths)` — Ctrl+A
    - Implement `clear()`
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [ ]* 2.6 Write property tests for selection operations
    - **Property 10: Single click replaces selection**
    - **Property 11: Ctrl+click toggles only the target file**
    - **Property 12: Shift+click selects contiguous range**
    - **Validates: Requirements 6.1, 6.2, 6.3**

  - [x] 2.7 Implement `RecentFoldersNotifier` with persistence
    - Create `lib/features/tag_editor/data/providers/recent_folders_provider.dart`
    - Load/save from `shared_preferences` (key: `recent_folders_v1`)
    - Implement `addFolder(String path)` — adds to front, deduplicates, caps at 10
    - Implement `removeFolder(String path)`
    - _Requirements: 9.1, 9.2, 9.3, 9.5_

  - [ ]* 2.8 Write property test for recent folders bounded FIFO
    - **Property 16: Recent folders bounded FIFO**
    - **Validates: Requirements 9.1, 9.2, 9.3**

  - [x] 2.9 Implement `RecursiveLoadingNotifier` with persistence
    - Create `lib/features/tag_editor/data/providers/recursive_loading_provider.dart`
    - Load/save from `shared_preferences` (key: `recursive_loading_enabled`)
    - Expose toggle method
    - _Requirements: 10.1, 10.7_

  - [x] 2.10 Implement `FilteredSortedFileListProvider`
    - Create `lib/features/tag_editor/data/providers/filtered_sorted_file_list_provider.dart`
    - Chain: fileListProvider → text filter → "show selected only" filter → sort
    - Add `showSelectedOnlyProvider` StateProvider
    - Implement sorting logic with numeric sort for track/disc/bitrate/duration/year/bpm columns
    - _Requirements: 3.5, 3.6, 11.1, 11.2, 11.3, 11.4_

  - [ ]* 2.11 Write property tests for sort and filter logic
    - **Property 5: Sort produces correctly ordered output**
    - **Property 17: Show-selected-only filter passes exactly selected files**
    - **Validates: Requirements 3.1, 3.2, 3.5, 3.6, 11.2, 11.3**

- [x] 3. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement folder loading with recursive toggle and threshold guard
  - [x] 4.1 Extend `FileUtils` with recursive folder scanning
    - Update `lib/core/utils/file_utils.dart`
    - Add method to scan folder for audio files with recursive option
    - Return list of file paths found
    - _Requirements: 10.2, 10.3_

  - [x] 4.2 Implement threshold guard dialog
    - Create `lib/features/tag_editor/presentation/widgets/threshold_guard_dialog.dart`
    - Show dialog when recursive scan finds >500 files
    - Provide "Load All", "Top-Level Only", and "Cancel" actions
    - _Requirements: 10.4, 10.5, 10.6_

  - [x] 4.3 Implement folder loading orchestration
    - Create `lib/features/tag_editor/data/providers/folder_loading_provider.dart`
    - Add `loadedFolderPathProvider` StateProvider
    - Implement `loadFolder(String path)` function that:
      - Checks recursive toggle state
      - Scans folder (recursively or not)
      - Triggers threshold guard if needed
      - Reads tags for all files
      - Updates file list, address bar, and recent folders
    - Handle drag-and-drop of folders and individual files (compute common parent)
    - _Requirements: 8.1, 8.3, 8.4, 9.1, 9.4, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [ ]* 4.4 Write property test for common parent directory
    - **Property 15: Common parent directory computation**
    - **Validates: Requirements 8.4**

- [x] 5. Implement presentation widgets
  - [x] 5.1 Implement `AddressBar` widget
    - Create `lib/features/tag_editor/presentation/widgets/address_bar.dart`
    - Display loaded folder path or placeholder text
    - Include recent folders dropdown button
    - Include recursive toggle switch
    - _Requirements: 8.1, 8.2, 8.3, 9.6, 10.1_

  - [x] 5.2 Implement `DataGrid` column headers with sort, reorder, and context menu
    - Create `lib/features/tag_editor/presentation/widgets/data_grid/column_headers.dart`
    - Render column headers based on visible column config
    - Click to sort (show sort direction arrow indicator)
    - Drag to reorder (prevent tagIndicator from moving)
    - Right-click context menu for show/hide columns
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 5.1, 5.3_

  - [x] 5.3 Implement `DataGrid` virtualized rows
    - Create `lib/features/tag_editor/presentation/widgets/data_grid/data_grid.dart`
    - Use `ListView.builder` with fixed `itemExtent` for virtualized scrolling
    - Render cells based on visible columns and value extractors
    - Tag indicator column: filled icon if tags present, grey unfilled if not, tooltip with tag format
    - Handle click with modifier key detection (none, Ctrl, Shift) for selection
    - Highlight selected rows with distinct background color
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 6.1, 6.2, 6.3, 6.5, 12.1, 12.4_

  - [x] 5.4 Implement enhanced `StatusBar` widget
    - Create `lib/features/tag_editor/presentation/widgets/status_bar.dart`
    - Display: total files, selected files, total duration (Xh Ym), selected duration (Xh Ym), total file size (human-readable), modified count
    - Use computed providers for aggregate values
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

  - [ ]* 5.5 Write property test for total duration computation
    - **Property 13: Total duration equals sum of individual durations**
    - **Validates: Requirements 7.3, 7.4**

  - [x] 5.6 Implement "show selected only" toggle
    - Add toggle button to the file list panel toolbar/filter area
    - Wire to `showSelectedOnlyProvider`
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

- [x] 6. Wire everything together in FileListPanel
  - [x] 6.1 Refactor `FileListPanel` to use new components
    - Replace existing `_FileListView` with new `DataGrid` widget
    - Add `AddressBar` above the filter bar
    - Replace existing status display with new `StatusBar` widget
    - Add "show selected only" toggle to filter area
    - Wire `SelectionNotifier` to replace `selectedFilePathsProvider` usage
    - Update keyboard shortcut handler for Ctrl+A to use `SelectionNotifier.selectAll`
    - _Requirements: 1.1, 2.1, 6.4, 8.1, 11.1_

  - [x] 6.2 Wire folder loading to address bar and recent folders
    - Connect folder picker and drag-and-drop to `loadFolder` orchestration
    - Update address bar on folder load
    - Add loaded folder to recent folders
    - Wire recent folders menu selection to trigger folder loading
    - _Requirements: 8.1, 8.3, 8.4, 9.1, 9.4_

  - [x] 6.3 Ensure column config and recent folders persist across sessions
    - Verify `shared_preferences` read/write on app startup and state changes
    - Handle corrupted/missing preferences gracefully (fall back to defaults)
    - _Requirements: 4.4, 5.2, 9.5, 10.7_

  - [ ]* 6.4 Write widget tests for FileListPanel integration
    - Test column headers render correctly
    - Test sort arrow appears on active sort column
    - Test selected rows have distinct background
    - Test address bar shows loaded folder path
    - Test recursive toggle is present
    - Test show-selected-only toggle filters display
    - _Requirements: 3.4, 6.5, 8.1, 10.1, 11.1_

- [x] 7. Performance validation
  - [x] 7.1 Verify virtualized scrolling with large file lists
    - Ensure `ListView.builder` with fixed `itemExtent` is used
    - Verify only visible rows are rendered (check widget tree in tests)
    - Test with 500 mock AudioFile entries to confirm initial display completes within 3 seconds
    - _Requirements: 12.1, 12.2, 12.3, 12.4_

- [x] 8. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit/widget tests validate specific examples and edge cases
- The existing `selectedFilePathsProvider` will be replaced by the new `SelectionNotifier` — update all references
- `shared_preferences` is already a project dependency (used by settings)
