# Implementation Plan: UX Medium Fixes (Issues 8–13)

## Overview

Six targeted fixes for medium-severity UX issues. Each is a small change to existing widgets — no new models or services.

## Tasks

- [x] 1. Fix 8 — Filter bar clear button immediate rebuild
  - [x] 1.1 Add TextEditingController listener in _FilterBarState
    - In `lib/features/tag_editor/presentation/widgets/file_list_panel.dart` (`_FilterBarState`):
      - In `initState`, add `_filterController.addListener(() => setState(() {}));`
      - This ensures the suffix icon (clear button) visibility updates immediately when text changes
    - _Requirements: 8.1, 8.2_

- [x] 2. Fix 9 — Tag panel field commit on focus loss
  - [x] 2.1 Add FocusNodes and focus-loss commit logic
    - In `lib/features/tag_editor/presentation/widgets/tag_edit_panel.dart` (`_TagFieldsTabState`):
      - Add `final _focusNodes = <String, FocusNode>{};`
      - In `initState`, create a `FocusNode` per field and add a listener that calls `_onFieldChanged(field, _controllers[field]!.text)` when `!focusNode.hasFocus` and the value differs from the model
      - In `dispose`, dispose all focus nodes
      - In `_buildField`, pass the focus node to the `TextField` via `focusNode: _focusNodes[field]`
    - _Requirements: 9.1, 9.2_

  - [x] 2.2 Guard _syncControllers against overwriting focused fields
    - In `lib/features/tag_editor/presentation/widgets/tag_edit_panel.dart` (`_TagFieldsTabState._syncControllers`):
      - Skip updating a controller if its corresponding focus node has focus (`_focusNodes[field]!.hasFocus`)
      - This prevents selection changes from discarding in-progress edits before the focus-loss commit fires
    - _Requirements: 9.2, 9.3_

- [x] 3. Fix 10 — Clipboard paste feedback for album art
  - [x] 3.1 Add feedback message when clipboard has no valid image
    - In `lib/features/tag_editor/presentation/widgets/tag_edit_panel.dart` (`_AlbumArtTabState._handleClipboardPaste`):
      - At the end of the method (after all checks fail), add: `_showError('No image found on clipboard');`
      - Ensure the SnackBar uses `duration: const Duration(seconds: 3)`
    - _Requirements: 10.1, 10.2_

- [x] 4. Fix 11 — Read-only cell cursor
  - [x] 4.1 Change forbidden cursor to basic cursor on non-editable cells
    - In `lib/features/tag_editor/inline_cell_editing/widgets/editable_cell.dart`:
      - Change `SystemMouseCursors.forbidden` to `SystemMouseCursors.basic`
    - _Requirements: 11.1, 11.2_

- [x] 5. Fix 12 — Double-click consistency on non-editable cells
  - [x] 5.1 Refine onDoubleTap suppression condition in _DataRow
    - In `lib/features/tag_editor/presentation/widgets/data_grid/data_grid.dart` (`_DataRow.build`):
      - Change the `isEditRow` watch to specifically check if this row is being *edited* (not just focused):
        ```dart
        final isEditingThisRow = ref.watch(
          inlineCellEditProvider.select(
            (s) => s.editingCell?.rowIndex == rowIndex,
          ),
        );
        ```
      - Change `onDoubleTap: isEditRow ? null : onDoubleTap` to `onDoubleTap: isEditingThisRow ? null : onDoubleTap`
      - Keep the existing `isEditRow` watch for row background/rebuild purposes
    - _Requirements: 12.1, 12.2, 12.3_

- [x] 6. Fix 13 — Lookup dialog step indicator
  - [x] 6.1 Add step indicator to lookup dialog header
    - In `lib/features/online_lookup/presentation/widgets/lookup_dialog.dart` (`_LookupDialogState.build`):
      - Compute the current step based on state: search=1, results=2, match=3, apply=4
      - Add a `Text` widget in the header row showing "Step N of 4" or a simple breadcrumb like "Search › Results › Tracks › Apply" with the current step highlighted
      - Style: `fontSize: 12, color: colorScheme.onSurfaceVariant`
    - _Requirements: 13.1, 13.2, 13.3_

## Notes

- All fixes are independent and can be implemented in parallel.
- Fix 9 is the most involved (adds focus nodes), but follows the same pattern used in `_TextFieldRow` in settings_page.dart.
- Fix 13 was revised during design — the navigation logic is actually correct, so we're adding clarity via a step indicator rather than changing navigation.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "3.1", "4.1", "5.1", "6.1"] },
    { "id": 1, "tasks": ["2.2"] }
  ]
}
```
