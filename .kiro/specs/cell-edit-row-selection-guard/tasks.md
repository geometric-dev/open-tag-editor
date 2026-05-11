# Implementation Plan: Cell Edit Row Selection Guard & Multi-Selection

## Overview

This plan implements standard desktop list-view selection and editing conventions for the DataGrid. It adds a row-selection guard for edit mode entry, focus-loss exit behaviour, marquee (rubber-band) drag selection, and full Ctrl/Shift multi-selection with keyboard support. Tasks are ordered so each step builds on the previous, with no orphaned code.

## Tasks

- [x] 1. Add new SelectionNotifier methods
  - [x] 1.1 Add `moveUp` and `moveDown` methods to SelectionNotifier
    - Implement `moveUp(List<String> orderedPaths)` that moves single selection to the previous row
    - Implement `moveDown(List<String> orderedPaths)` that moves single selection to the next row
    - Both methods set the new row as anchor and replace the selection with only that row
    - Boundary cases: `moveUp` at index 0 is a no-op; `moveDown` at last index is a no-op
    - File: `lib/features/tag_editor/data/providers/selection_provider.dart`
    - _Requirements: 4.7_

  - [x] 1.2 Add `extendUp`, `extendDown`, `extendToStart`, `extendToEnd` methods to SelectionNotifier
    - Implement `extendUp(List<String> orderedPaths)` that adds one row above the current selection edge
    - Implement `extendDown(List<String> orderedPaths)` that adds one row below the current selection edge
    - Implement `extendToStart(List<String> orderedPaths)` that extends selection from anchor to first row
    - Implement `extendToEnd(List<String> orderedPaths)` that extends selection from anchor to last row
    - All extend methods preserve the anchor unchanged
    - File: `lib/features/tag_editor/data/providers/selection_provider.dart`
    - _Requirements: 4.8, 4.9, 4.10_

  - [x] 1.3 Add `addRangeSelect`, `replaceSelection`, `addToSelection` methods to SelectionNotifier
    - Implement `addRangeSelect(String path, List<String> orderedPaths)` for Ctrl+Shift+click (union of existing selection and range from anchor to target)
    - Implement `replaceSelection(Set<String> paths)` for marquee without Ctrl (replaces entire selection)
    - Implement `addToSelection(Set<String> paths)` for Ctrl+marquee (union with existing)
    - File: `lib/features/tag_editor/data/providers/selection_provider.dart`
    - _Requirements: 3.4, 3.5, 4.4_

  - [ ]* 1.4 Write property tests for SelectionNotifier methods
    - **Property 8: Shift+click selects contiguous range from anchor**
    - **Property 9: Ctrl+click toggles without affecting others**
    - **Property 10: Shift+Arrow extends selection by exactly one row**
    - **Validates: Requirements 4.2, 4.3, 4.7, 4.8**
    - File: `test/features/tag_editor/selection/selection_properties_test.dart`

- [x] 2. Add row selection guard to InlineCellEditNotifier
  - [x] 2.1 Add row selection guard check to `enterEditMode`
    - After the existing row-index validation, read `selectionProvider` and get the file path at `cell.rowIndex`
    - If `!selection.isSelected(filePath)`, return early (do not enter edit mode)
    - This enforces the select-then-edit workflow for all entry paths (double-click, F2, printable char)
    - File: `lib/features/tag_editor/inline_cell_editing/notifiers/inline_cell_edit_notifier.dart`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

  - [ ]* 2.2 Write property tests for row selection guard
    - **Property 1: Row selection guard prevents edit on unselected rows**
    - **Property 2: Row selection guard allows edit on selected rows**
    - **Validates: Requirements 1.1, 1.2, 1.4, 1.5**
    - File: `test/features/tag_editor/inline_cell_editing/edit_guard_properties_test.dart`

- [x] 3. Update EditableCell to check row selection before entering edit mode
  - [x] 3.1 Update `EditableCell.onDoubleTap` to guard on row selection
    - Read `selectionProvider` and `filteredSortedFileListProvider` to get the file path for the cell's row
    - If the row is selected, call `enterEditMode(coordinate, prePopulate: true)`
    - If the row is NOT selected, do nothing (the row tap handler on `_DataRow` already selects it)
    - File: `lib/features/tag_editor/inline_cell_editing/widgets/editable_cell.dart`
    - _Requirements: 1.1, 1.2_

  - [ ]* 3.2 Write widget tests for EditableCell double-click guard
    - Verify double-click on unselected row does not enter edit mode
    - Verify double-click on selected row enters edit mode
    - **Validates: Requirements 1.1, 1.2**

- [x] 4. Checkpoint - Ensure row selection guard works
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Update DataGrid keyboard handling
  - [x] 5.1 Add arrow key navigation (Up/Down) to `_handleKeyEvent`
    - When not editing: Down arrow calls `selNotifier.moveDown(orderedPaths)`; Up arrow calls `selNotifier.moveUp(orderedPaths)`
    - When Shift is held: Down calls `selNotifier.extendDown(orderedPaths)`; Up calls `selNotifier.extendUp(orderedPaths)`
    - Return `KeyEventResult.handled` for all arrow key events
    - File: `lib/features/tag_editor/presentation/widgets/data_grid/data_grid.dart`
    - _Requirements: 4.7, 4.8_

  - [x] 5.2 Add Ctrl+A, Ctrl+Shift+Home, Ctrl+Shift+End to `_handleKeyEvent`
    - Ctrl+A calls `selNotifier.selectAll(orderedPaths)`
    - Ctrl+Shift+Home calls `selNotifier.extendToStart(orderedPaths)`
    - Ctrl+Shift+End calls `selNotifier.extendToEnd(orderedPaths)`
    - File: `lib/features/tag_editor/presentation/widgets/data_grid/data_grid.dart`
    - _Requirements: 4.9, 4.10, 4.11_

  - [x] 5.3 Ensure F2 and printable-char entry respect the row selection guard
    - The existing F2 and printable-char handlers already call `enterEditMode` which now has the guard
    - Verify the guard check in `enterEditMode` is sufficient (no additional widget-level check needed)
    - Remove the `Alt` key check from the printable-char condition if not needed, keep Ctrl check
    - File: `lib/features/tag_editor/presentation/widgets/data_grid/data_grid.dart`
    - _Requirements: 1.3, 1.4, 1.5, 1.6_

- [x] 6. Update DataGrid row tap handling
  - [x] 6.1 Add edit-mode confirmation on row tap and Ctrl+Shift+click support
    - At the start of `_handleRowTap`, check if `editState.isEditing` and call `confirmEdit()` if so
    - Add Ctrl+Shift modifier detection: when both are held, call `notifier.addRangeSelect(path, orderedPaths)`
    - Reorder modifier checks: Ctrl+Shift first, then Shift, then Ctrl, then plain click
    - File: `lib/features/tag_editor/presentation/widgets/data_grid/data_grid.dart`
    - _Requirements: 2.1, 2.2, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.12_

  - [ ]* 6.2 Write unit tests for row tap with edit mode active
    - Verify clicking another row while editing confirms the edit
    - Verify Ctrl+Shift+click adds range to existing selection
    - **Validates: Requirements 2.1, 2.2, 4.4, 4.12**

- [x] 7. Checkpoint - Ensure keyboard and click selection works
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Implement marquee selection pure function
  - [x] 8.1 Create `computeMarqueeIntersectedRows` pure function
    - Create file: `lib/features/tag_editor/presentation/widgets/data_grid/marquee_utils.dart`
    - Implement `Set<int> computeMarqueeIntersectedRows({required double marqueeTop, required double marqueeBottom, required double rowHeight, required int totalRows})`
    - Calculate first row as `(marqueeTop / rowHeight).floor().clamp(0, totalRows - 1)`
    - Calculate last row as `(marqueeBottom / rowHeight).floor().clamp(0, totalRows - 1)`
    - Return set of all indices from first to last inclusive
    - Handle edge case: if `totalRows == 0`, return empty set
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ]* 8.2 Write property tests for `computeMarqueeIntersectedRows`
    - **Property 5: Marquee intersects correct rows**
    - **Validates: Requirements 3.1, 3.2, 3.3**
    - File: `test/features/tag_editor/data_grid/marquee_utils_test.dart`

- [x] 9. Implement MarqueeOverlay widget
  - [x] 9.1 Create `MarqueeOverlay` ConsumerStatefulWidget
    - Create file: `lib/features/tag_editor/presentation/widgets/data_grid/marquee_overlay.dart`
    - Accept `child`, `rowHeight`, `scrollController`, `orderedPaths` as constructor params
    - Track local state: `isActive`, `startPosition`, `currentPosition`, `isCtrlHeld`, `preExistingSelection`
    - Use `Listener` widget to capture pointer down/move/up events
    - On pointer down: record start position and whether Ctrl is held; snapshot current selection if Ctrl held
    - On pointer move: if drag distance > 4px threshold, activate marquee; compute intersected rows using `computeMarqueeIntersectedRows`; update selection via `replaceSelection` or `addToSelection`
    - On pointer up: deactivate marquee, finalize selection
    - Render marquee rectangle using `CustomPaint` with semi-transparent fill and border
    - Define constants: `kMarqueeDragThreshold = 4.0`, marquee colours from theme
    - If edit mode is active when marquee starts, call `confirmEdit()` first
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [x] 9.2 Implement auto-scroll during marquee drag
    - When pointer is within 40px of the top or bottom viewport edge during active marquee, auto-scroll in that direction at 200px/s
    - Use a periodic timer or `Ticker` to drive smooth scrolling
    - Recalculate intersected rows on each scroll update
    - Cancel auto-scroll when pointer moves away from edge or marquee ends
    - File: `lib/features/tag_editor/presentation/widgets/data_grid/marquee_overlay.dart`
    - _Requirements: 3.8_

  - [ ]* 9.3 Write widget tests for MarqueeOverlay
    - Verify marquee rectangle renders during drag
    - Verify < 4px drag is treated as click (no marquee)
    - Verify Ctrl+drag adds to selection
    - Verify plain drag replaces selection
    - **Property 6: Ctrl+marquee is additive**
    - **Property 7: Plain marquee replaces selection**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**

- [x] 10. Wire MarqueeOverlay into the DataGrid
  - [x] 10.1 Integrate MarqueeOverlay into `_ScrollableDataGrid`
    - Wrap the `ListView.builder` (inside the `Expanded` widget) with `MarqueeOverlay`
    - Pass `DataGrid._rowHeight`, the vertical scroll controller, and `orderedPaths` (derived from `widget.files`)
    - Expose the `ListView`'s `ScrollController` as a field on `_ScrollableDataGridState` so it can be passed to `MarqueeOverlay`
    - File: `lib/features/tag_editor/presentation/widgets/data_grid/data_grid.dart`
    - _Requirements: 3.1, 3.2, 3.3, 3.8_

- [x] 11. Final checkpoint - Ensure all features work together
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- The row selection guard in `enterEditMode` covers all entry paths (double-click, F2, printable char) with a single check
- The design uses Dart throughout — no language selection needed
- The marquee overlay is decoupled from row hit-testing by using a `Listener` + `CustomPaint` approach

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["1.4", "2.1"] },
    { "id": 2, "tasks": ["2.2", "3.1"] },
    { "id": 3, "tasks": ["3.2", "5.1", "5.2", "5.3"] },
    { "id": 4, "tasks": ["6.1"] },
    { "id": 5, "tasks": ["6.2", "8.1"] },
    { "id": 6, "tasks": ["8.2", "9.1"] },
    { "id": 7, "tasks": ["9.2"] },
    { "id": 8, "tasks": ["9.3", "10.1"] }
  ]
}
```
