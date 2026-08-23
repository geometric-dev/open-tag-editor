# Implementation Plan: Folder Selection UX

## Overview

Implement a multi-faceted folder navigation system for Open Tag Editor. The approach starts with pure-function domain logic (`BreadcrumbParser`, `SiblingResolver`, `QuickSwitcherFilter`), then builds state management notifiers (`BookmarksNotifier`, `FolderPanelStateNotifier`, enhanced `RecentFoldersNotifier`), adds the `FolderValidator` and `SiblingNavigationService`, and finally integrates presentation widgets (`FolderPanel`, `BreadcrumbBar`, `QuickSwitcherOverlay`). Each step builds incrementally on the previous, reusing the existing `FolderLoadingService` and `UnsavedChangesGuard` infrastructure.

## Tasks

- [x] 1. Implement data models and pure-function domain logic
  - [x] 1.1 Create `BookmarkEntry` and `FolderEntry` data models
    - Create `lib/features/folder_panel/data/bookmark_entry.dart`
    - Implement `BookmarkEntry` with `path`, `name`, `fromPath` factory, `toJson`, `fromJson`, and `Equatable` props
    - Create `lib/features/folder_panel/data/folder_entry.dart`
    - Implement `FolderEntry` with `path`, `name`, `source` (enum `FolderEntrySource { bookmark, recent }`), and `Equatable` props
    - _Requirements: 2.9, 7.1_

  - [x] 1.2 Create `BreadcrumbParser` pure-function class
    - Create `lib/features/folder_panel/data/breadcrumb_parser.dart`
    - Implement `splitSegments(String folderPath)` that splits a folder path into segments (first segment is drive letter on Windows)
    - Implement `pathAtIndex(List<String> segments, int index)` that reconstructs the full path from segments [0..index] inclusive using platform separator
    - Return empty list for null or empty paths
    - _Requirements: 4.1, 4.2_

  - [x] 1.3 Create `QuickSwitcherFilter` pure-function class
    - Create `lib/features/folder_panel/data/quick_switcher_filter.dart`
    - Implement `filter(List<FolderEntry> entries, String query)` that returns entries where name or path contains query (case-insensitive substring match)
    - Return all entries if query is empty
    - _Requirements: 5.2_

  - [x] 1.4 Create `SiblingResolver` pure-function class
    - Create `lib/features/folder_panel/data/sibling_resolver.dart`
    - Implement `filterAndSort(List<String> directoryNames)` that excludes hidden folders (dot-prefixed) and sorts case-insensitively
    - Implement `resolve({required List<String> siblingNames, required String currentName, required SiblingDirection direction})` that returns next/previous sibling or null at boundaries
    - Define `SiblingDirection` enum in the same file
    - _Requirements: 6.1, 6.2, 6.8_

  - [x] 1.5 Create `FolderValidator` service
    - Create `lib/features/folder_panel/data/folder_validator.dart`
    - Implement `validate(String path)` returning `FolderValidationResult` (ok, notFound, notADirectory, permissionDenied)
    - Use `dart:io` `Directory` and `FileSystemEntity` for filesystem checks
    - _Requirements: 3.4, 3.5, 4.3_

- [x] 2. Write property-based tests for pure-function domain logic
  - [x] 2.1 Write property test for BreadcrumbParser (Property 7)
    - **Property 7: Breadcrumb path splitting and segment navigation**
    - **Validates: Requirements 4.1, 4.2**
    - Create `test/features/folder_panel/data/breadcrumb_parser_test.dart`
    - Generate random valid folder paths (Windows-style with drive letters, 1–8 segments)
    - Assert: reconstructing from all segments produces equivalent path; `pathAtIndex(segments, i)` is a proper prefix for i < last index
    - _Requirements: 4.1, 4.2_

  - [x] 2.2 Write property test for QuickSwitcherFilter (Property 8)
    - **Property 8: Quick Switcher filter correctness**
    - **Validates: Requirements 5.2**
    - Create `test/features/folder_panel/data/quick_switcher_filter_test.dart`
    - Generate random folder entry lists and query strings
    - Assert: every included entry contains query (case-insensitive) in name or path; every excluded entry does not
    - _Requirements: 5.2_

  - [x] 2.3 Write property test for SiblingResolver (Property 9)
    - **Property 9: Sibling folder resolution with hidden folder exclusion**
    - **Validates: Requirements 6.1, 6.2, 6.8**
    - Create `test/features/folder_panel/data/sibling_resolver_test.dart`
    - Generate random directory name lists (including dot-prefixed hidden names)
    - Assert: filterAndSort excludes hidden, sorts case-insensitively; resolve returns correct adjacent entry or null at boundaries
    - _Requirements: 6.1, 6.2, 6.8_

- [x] 3. Implement state management notifiers
  - [x] 3.1 Create `FolderPanelStateNotifier`
    - Create `lib/features/folder_panel/data/folder_panel_state_notifier.dart`
    - Implement `StateNotifier<bool>` with `loadFromPrefs()`, `toggle()`, `setVisible(bool)` methods
    - Persist visibility to SharedPreferences under a dedicated key
    - Default to `false` (collapsed) when no persisted state exists
    - Register as a Riverpod provider
    - _Requirements: 1.1, 1.3, 1.4, 1.5_

  - [x] 3.2 Create `BookmarksNotifier`
    - Create `lib/features/folder_panel/data/bookmarks_notifier.dart`
    - Implement `StateNotifier<List<BookmarkEntry>>` with `loadFromPrefs()`, `addBookmark(String path)`, `removeBookmark(String path)`, `reorder(int oldIndex, int newIndex)`
    - Enforce max 50 bookmarks, idempotent add (no duplicates), persist to SharedPreferences as JSON
    - Register as a Riverpod provider
    - _Requirements: 2.2, 2.3, 2.5, 2.6, 2.7, 2.8, 2.10_

  - [x] 3.3 Enhance `RecentFoldersNotifier` to support 20 entries and removal
    - Modify the existing `RecentFoldersNotifier` (or create enhanced version at `lib/features/folder_panel/data/recent_folders_notifier.dart`)
    - Increase max entries from 10 to 20
    - Add `removeFolder(String path)` method with persistence
    - Ensure MRU ordering: adding an existing path moves it to front
    - _Requirements: 7.2, 7.4_

- [x] 4. Write property-based tests for state notifiers
  - [x] 4.1 Write property test for FolderPanelStateNotifier (Property 1)
    - **Property 1: Folder panel visibility persistence round-trip**
    - **Validates: Requirements 1.4**
    - Create `test/features/folder_panel/data/folder_panel_state_test.dart`
    - Generate random boolean values; persist and reload; assert round-trip equality
    - _Requirements: 1.4_

  - [x] 4.2 Write property tests for BookmarksNotifier (Properties 2, 3, 4, 5, 6)
    - **Property 2: Bookmark add is append-only and idempotent**
    - **Property 3: Bookmark remove**
    - **Property 4: Bookmark persistence round-trip preserving order**
    - **Property 5: Bookmark reorder preserves elements**
    - **Property 6: Bookmark maximum capacity**
    - **Validates: Requirements 2.2, 2.3, 2.5, 2.6, 2.7, 2.8, 2.10**
    - Create `test/features/folder_panel/data/bookmarks_notifier_test.dart`
    - Generate random bookmark lists and operations; assert idempotent add, correct remove, round-trip serialization, reorder element preservation, max 50 cap
    - _Requirements: 2.2, 2.3, 2.5, 2.6, 2.7, 2.8, 2.10_

  - [x] 4.3 Write property tests for RecentFoldersNotifier (Properties 10, 11)
    - **Property 10: Recent folders bounded MRU list**
    - **Property 11: Recent folders remove**
    - **Validates: Requirements 7.2, 7.4**
    - Create `test/features/folder_panel/data/recent_folders_notifier_test.dart`
    - Generate random sequences of addFolder/removeFolder operations; assert max 20 entries, MRU ordering, no duplicates, correct removal
    - _Requirements: 7.2, 7.4_

- [x] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement SiblingNavigationService
  - [x] 6.1 Create `SiblingNavigationService`
    - Create `lib/features/folder_panel/data/sibling_navigation_service.dart`
    - Implement `navigate(BuildContext context, SiblingDirection direction)` that:
      - Checks if a folder is currently loaded (no-op if not)
      - Lists parent directory contents via `dart:io`
      - Calls `SiblingResolver.filterAndSort` then `SiblingResolver.resolve`
      - Shows unsaved-changes guard if needed
      - Validates target via `FolderValidator`
      - Loads folder via `FolderLoadingService.loadFolder()`
      - Displays status bar messages at boundaries or on errors
    - Register as a Riverpod provider
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

- [x] 7. Implement FolderPanel widget
  - [x] 7.1 Create `FolderPanel` widget with bookmarks and recent sections
    - Create `lib/features/folder_panel/presentation/folder_panel.dart`
    - Implement `ConsumerWidget` with two sections: Bookmarks (top) and Recent Folders (bottom)
    - Display each bookmark with folder name as primary label and full path as secondary line
    - Display each recent folder with bold name and truncated path with ellipsis
    - Show visual indicator for entries referencing non-existent paths
    - Limit Recent_Folders_List display to entries from the notifier
    - Wire `onFolderSelected` callback through `FolderLoadingService` with unsaved-changes guard
    - _Requirements: 1.2, 1.6, 2.9, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 7.1, 7.5_

  - [x] 7.2 Add context menus to FolderPanel entries
    - Add right-click context menu on recent folder entries with "Add to Bookmarks" option
    - Add right-click context menu on bookmark entries with "Remove Bookmark" option
    - Add right-click context menu on recent folder entries with "Remove from History" option
    - Wire context menu actions to `BookmarksNotifier` and `RecentFoldersNotifier`
    - _Requirements: 2.1, 2.4, 2.5, 7.3, 7.4_

  - [x] 7.3 Add drag-and-drop reordering to bookmarks section
    - Implement `ReorderableListView` or equivalent for bookmark entries
    - Wire reorder callbacks to `BookmarksNotifier.reorder()`
    - _Requirements: 2.7, 2.8_

  - [x] 7.4 Integrate FolderPanel into main layout with toggle
    - Add `FolderPanel` as a collapsible left panel (max 250px width) in the main layout
    - Add a toolbar button that toggles panel visibility via `FolderPanelStateNotifier`
    - Ensure panel restores visibility state on app launch
    - _Requirements: 1.1, 1.3, 1.4, 1.5, 1.6_

- [x] 8. Implement BreadcrumbBar widget
  - [x] 8.1 Refactor AddressBar to BreadcrumbBar with clickable segments
    - Modify or replace the existing `AddressBar` widget
    - Create `lib/features/folder_panel/presentation/breadcrumb_bar.dart`
    - Display path as clickable segments separated by chevron dividers
    - On segment click: navigate to that ancestor directory via `FolderLoadingService` with unsaved-changes guard
    - Preserve existing `onFolderSelected` callback contract
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 8.2 Add edit mode and overflow handling to BreadcrumbBar
    - On double-click or keyboard shortcut: switch to text input field pre-filled with full path, selected for overwrite
    - On Enter: validate and load the typed path; on Escape or focus loss: return to breadcrumb display
    - When path exceeds visible width: collapse leading segments into overflow dropdown button listing hidden segments
    - _Requirements: 4.4, 4.5, 4.6_

- [x] 9. Implement QuickSwitcher overlay
  - [x] 9.1 Create `QuickSwitcherOverlay` widget
    - Create `lib/features/folder_panel/presentation/quick_switcher_overlay.dart`
    - Implement as `OverlayEntry` positioned at top-center of window
    - Show text input field with combined list of bookmarks + recent folders
    - Filter results using `QuickSwitcherFilter` on each keystroke
    - Display "No matching folders" when no results match
    - _Requirements: 5.1, 5.2, 5.3_

  - [x] 9.2 Add keyboard navigation and activation to QuickSwitcher
    - Register `Ctrl+G` keyboard shortcut to open the overlay
    - Highlight first result by default; arrow keys navigate (with wrap-around)
    - Enter loads the highlighted folder via `FolderLoadingService` with unsaved-changes guard
    - Escape or click-outside dismisses without action
    - _Requirements: 5.1, 5.4, 5.5, 5.6_

- [x] 10. Wire sibling navigation keyboard shortcuts
  - [x] 10.1 Register Alt+Right and Alt+Left shortcuts for sibling navigation
    - Add keyboard shortcut handlers for `Alt+Right` and `Alt+Left` in the app's shortcut/intent system
    - Wire to `SiblingNavigationService.navigate()` with appropriate direction
    - Ensure no-op when no folder is loaded
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [x] 11. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 12. Write widget and integration tests
  - [x] 12.1 Write widget tests for FolderPanel
    - Create `test/features/folder_panel/presentation/folder_panel_test.dart`
    - Test: renders bookmarks and recent sections, context menu appears on right-click, click triggers folder loading, inline error indicator on invalid paths, drag-and-drop reorders bookmarks
    - _Requirements: 1.2, 2.1, 2.4, 2.5, 2.9, 3.1, 3.2, 3.4, 7.1, 7.3, 7.5_

  - [x] 12.2 Write widget tests for BreadcrumbBar
    - Create `test/features/folder_panel/presentation/breadcrumb_bar_test.dart`
    - Test: segments render correctly, click navigates to ancestor, double-click enters edit mode, Enter/Escape exits edit mode, overflow collapses leading segments into dropdown
    - _Requirements: 4.1, 4.2, 4.4, 4.5, 4.6_

  - [x] 12.3 Write widget tests for QuickSwitcherOverlay
    - Create `test/features/folder_panel/presentation/quick_switcher_overlay_test.dart`
    - Test: opens on Ctrl+G, filters on keystroke, arrow keys navigate results, Enter selects and loads, Escape dismisses, "No matching folders" shown when empty
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [x] 12.4 Write integration tests for sibling navigation and folder loading
    - Create `test/features/folder_panel/presentation/sibling_navigation_test.dart`
    - Test: Alt+Right loads next sibling, Alt+Left loads previous, boundary shows status message, unsaved-changes guard triggers, no-op when no folder loaded
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [x] 13. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate the 11 universal correctness properties defined in the design
- Unit tests validate specific examples and edge cases
- Pure-function domain logic (tasks 1.2–1.4) has no widget dependencies and is fully testable in isolation
- The existing `FolderLoadingService`, `UnsavedChangesGuard`, and `SharedPreferences` infrastructure are reused without modification
- Test files are organised under `test/features/folder_panel/`
- The `RecentFoldersNotifier` enhancement (task 3.3) modifies existing code — check for downstream impacts

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "1.4", "1.5"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3", "3.1", "3.2", "3.3"] },
    { "id": 2, "tasks": ["4.1", "4.2", "4.3", "6.1"] },
    { "id": 3, "tasks": ["7.1", "8.1", "9.1", "10.1"] },
    { "id": 4, "tasks": ["7.2", "7.3", "8.2", "9.2"] },
    { "id": 5, "tasks": ["7.4"] },
    { "id": 6, "tasks": ["12.1", "12.2", "12.3", "12.4"] }
  ]
}
```
