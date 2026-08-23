# Implementation Plan: UX Review Fixes (Issues 1–7)

## Overview

Seven targeted fixes addressing UX dead-ends identified during code review. Each fix is small and self-contained. No new services or models required — these are wiring, guards, and minor widget changes.

## Tasks

- [x] 1. Fix 1 — Wire up "Tags from Filename" toolbar button
  - [x] 1.1 Add ExtractorDialog toolbar button
    - In `lib/features/tag_editor/presentation/widgets/toolbar.dart`:
      - Add import for `extractor_dialog.dart`
      - Add a `_ToolbarButton` with `Icons.text_snippet` icon, tooltip "Tags from Filename"
      - Place it after the "Rename Files" button
      - `onPressed`: `showDialog(context: context, builder: (_) => const ExtractorDialog())`
      - Disable when `ref.watch(fileListProvider).isEmpty`
    - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Fix 2 — Make Album Art toolbar button functional
  - [x] 2.1 Add tagPanelActiveTabProvider
    - In `lib/features/tag_editor/data/providers/editor_state_provider.dart`:
      - Add `enum TagPanelTab { tags, albumArt, fileInfo }`
      - Add `final tagPanelActiveTabProvider = StateProvider<TagPanelTab>((ref) => TagPanelTab.tags);`
    - _Requirements: 2.1_

  - [x] 2.2 Wire TagEditPanel to watch the active tab provider
    - In `lib/features/tag_editor/presentation/widgets/tag_edit_panel.dart`:
      - Remove the local `_PanelTab` enum and `_activeTab` field
      - Replace with `ref.watch(tagPanelActiveTabProvider)` for reading the active tab
      - Tab button taps update `ref.read(tagPanelActiveTabProvider.notifier).state`
      - Map `TagPanelTab.tags/albumArt/fileInfo` to the existing tab content builders
    - _Requirements: 2.1, 2.2_

  - [x] 2.3 Update Album Art toolbar button
    - In `lib/features/tag_editor/presentation/widgets/toolbar.dart`:
      - Replace the TODO with:
        - `ref.read(tagPanelOpenProvider.notifier).state = true;`
        - `ref.read(tagPanelActiveTabProvider.notifier).state = TagPanelTab.albumArt;`
      - Disable when `ref.watch(selectedFilesProvider).isEmpty`
    - _Requirements: 2.1, 2.2, 2.3_

- [x] 3. Fix 3 — Make error snackbars dismissable
  - [x] 3.1 Update snackbar calls in toolbar.dart
    - In `lib/features/tag_editor/presentation/widgets/toolbar.dart`:
      - Change `duration: const Duration(days: 365)` to `duration: const Duration(seconds: 30)`
      - Add `showCloseIcon: true`
      - Add `ScaffoldMessenger.of(context).clearSnackBars()` before showing
    - _Requirements: 3.1, 3.2, 3.3_

  - [x] 3.2 Update snackbar calls in unsaved_changes_guard.dart
    - In `lib/shared/widgets/unsaved_changes_guard.dart`:
      - Same changes: duration 30s, showCloseIcon, clearSnackBars before show
    - _Requirements: 3.1, 3.2, 3.3_

  - [x] 3.3 Update snackbar calls in rename_dialog.dart
    - In `lib/features/renamer/presentation/widgets/rename_dialog.dart`:
      - Same changes: duration 30s, showCloseIcon, clearSnackBars before show
    - _Requirements: 3.1, 3.2, 3.3_

  - [x] 3.4 Update snackbar calls in notification_service.dart
    - In `lib/features/error_handling/services/notification_service.dart`:
      - Same changes: duration 30s, showCloseIcon, clearSnackBars before show
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 4. Fix 4 — Disable Rename button when no files loaded
  - [x] 4.1 Add file-list guard to Rename toolbar button
    - In `lib/features/tag_editor/presentation/widgets/toolbar.dart`:
      - Change the Rename button's `onPressed` to `null` when `ref.watch(fileListProvider).isEmpty`
    - _Requirements: 4.1, 4.2_

- [x] 5. Fix 5 — Disable Online Lookup button when no selection
  - [x] 5.1 Add selection guard to Online Lookup toolbar button
    - In `lib/features/tag_editor/presentation/widgets/toolbar.dart`:
      - Change the Lookup button's `onPressed` to `null` when `ref.watch(selectedFilesProvider).isEmpty`
      - Update tooltip: when disabled, show "Select files to look up metadata"
    - _Requirements: 5.1, 5.2_

- [x] 6. Fix 6 — Show-Selected-Only filter safety
  - [x] 6.1 Add visible filter chip when show-selected-only is active
    - In `lib/features/tag_editor/presentation/widgets/file_list_panel.dart` (`_FilterBar`):
      - When `showSelectedOnly` is true, render a `Chip` widget with label "Showing selected only" and a delete icon
      - `onDeleted`: sets `showSelectedOnlyProvider` to false
      - Place the chip between the filter text field and the toggle button
    - _Requirements: 6.1, 6.2_

  - [x] 6.2 Auto-deactivate filter when it would show zero files
    - In `lib/features/tag_editor/data/providers/filtered_sorted_file_list_provider.dart`:
      - After applying the show-selected-only filter, if the resulting list is empty AND the source list was non-empty, set `showSelectedOnlyProvider` to false (use `ref.read` to avoid circular watch)
      - Update `statusMessageProvider` with "Filter cleared — no selected files to show"
    - _Requirements: 6.3_

- [x] 7. Fix 7 — Remove selected files from list
  - [x] 7.1 Add Delete key handler in DataGrid
    - In `lib/features/tag_editor/presentation/widgets/data_grid/data_grid.dart` (`_handleKeyEvent`):
      - Handle `LogicalKeyboardKey.delete`: call a new helper `_removeSelectedFiles(ref)`
      - The helper checks if any selected files are modified; if so, shows a confirmation dialog ("Remove N files from list? M have unsaved changes that will be lost.")
      - On confirm, calls `ref.read(fileListProvider.notifier).removeFiles(selectedPaths)` and `ref.read(selectionProvider.notifier).clear()`
    - _Requirements: 7.1, 7.2, 7.4, 7.5_

  - [x] 7.2 Add "Remove Selected from List" to column header context menu
    - In `lib/features/tag_editor/presentation/widgets/data_grid/column_headers.dart` (`_showContextMenu`):
      - Add a separator and "Remove Selected from List" menu item (only shown when selection is non-empty)
      - On tap, call the same removal logic as the Delete key handler
    - _Requirements: 7.1, 7.3, 7.4, 7.5_

## Notes

- All fixes are independent and can be implemented in parallel.
- No new test files required for these fixes (they're UI wiring changes). Existing tests should continue to pass.
- The `tagPanelActiveTabProvider` is the only new piece of state introduced.
- The `removeFiles` method already exists on `FileListNotifier` — it just needs UI wiring.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "3.1", "3.2", "3.3", "3.4", "4.1", "5.1", "6.1", "6.2"] },
    { "id": 1, "tasks": ["2.2", "7.1", "7.2"] },
    { "id": 2, "tasks": ["2.3"] }
  ]
}
```
