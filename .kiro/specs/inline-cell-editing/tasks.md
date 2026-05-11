# Implementation Plan: Inline Cell Editing

## Overview

Implement spreadsheet-like inline cell editing in the DataGrid. The approach starts with pure-function core components (column editability, navigation functions, command builder), then builds the state management layer (InlineCellEditNotifier), followed by the widget layer (EditableCell, InlineTextField, BatchConfirmDialog), and finally wires everything together with keyboard handling and visual feedback. Each step builds incrementally on the previous, ensuring no orphaned code.

## Tasks

- [x] 1. Define data models and pure functions
  - [x] 1.1 Create CellCoordinate value object and InlineCellEditState model
    - Create `lib/features/tag_editor/inline_cell_editing/models/cell_coordinate.dart` with `CellCoordinate` class (rowIndex, columnId, equality, hashCode)
    - Create `lib/features/tag_editor/inline_cell_editing/models/inline_cell_edit_state.dart` with `InlineCellEditState` class (focusedCell, editingCell, originalValue, currentValue, isEditing getter, copyWith)
    - _Requirements: 1.1, 2.1, 7.1_

  - [x] 1.2 Implement isColumnEditable pure function
    - Create `lib/features/tag_editor/inline_cell_editing/utils/column_editability.dart`
    - Define `readOnlyColumnIds` constant set: `{'tagIndicator', 'filename', 'bitrate', 'duration', 'relativePath'}`
    - Implement `bool isColumnEditable(String columnId)` that returns `!readOnlyColumnIds.contains(columnId)`
    - _Requirements: 9.1, 9.2_

  - [x] 1.3 Implement nextEditableColumn and previousEditableColumn pure functions
    - Create `lib/features/tag_editor/inline_cell_editing/utils/cell_navigation.dart`
    - Implement `CellCoordinate? nextEditableColumn(CellCoordinate current, List<String> visibleColumnIds, int totalRows)` — skips read-only columns, wraps to next row at end
    - Implement `CellCoordinate? previousEditableColumn(CellCoordinate current, List<String> visibleColumnIds, int totalRows)` — skips read-only columns, wraps to previous row at start
    - _Requirements: 4.1, 4.2, 4.4, 4.5_

  - [x] 1.4 Implement buildTagEditCommand pure function
    - Create `lib/features/tag_editor/inline_cell_editing/utils/build_tag_edit_command.dart`
    - Implement `TagEditCommand? buildTagEditCommand({...})` that gathers previous values, returns null for no-op edits, and creates a TagEditCommand for single or batch edits
    - _Requirements: 3.4, 6.1, 6.2_

  - [ ]* 1.5 Write property test: Column editability classification (Property 1)
    - **Property 1: Column editability classification**
    - **Validates: Requirements 2.2, 2.4, 9.1, 9.2**
    - Create `test/features/tag_editor/inline_cell_editing/inline_edit_properties_test.dart`
    - Generate random column IDs from both read-only and editable sets
    - Assert: read-only IDs return false, all others return true

  - [ ]* 1.6 Write property test: Tab/Shift+Tab navigation always lands on editable column (Property 7)
    - **Property 7: Tab/Shift+Tab navigation always lands on an editable column**
    - **Validates: Requirements 4.1, 4.2, 4.4, 4.5**
    - Generate random visible column lists (with at least one editable column) and random cell coordinates
    - Assert: returned coordinate's columnId satisfies `isColumnEditable`, or null at boundary

  - [ ]* 1.7 Write property test: Unchanged value produces no undo command (Property 6)
    - **Property 6: Unchanged value produces no undo command**
    - **Validates: Requirements 3.4**
    - Generate random file paths, column IDs, and tag values where newValue equals originalValue
    - Assert: `buildTagEditCommand` returns null

  - [ ]* 1.8 Write unit tests for pure functions
    - Test `isColumnEditable` with each known read-only and editable column
    - Test `nextEditableColumn` — middle of row, end of row wrap, last row returns null, single editable column
    - Test `previousEditableColumn` — middle of row, start of row wrap, first row returns null
    - Test `buildTagEditCommand` — null for unchanged value, correct previousValues map, correct filePaths for single and batch
    - _Requirements: 4.1, 4.2, 4.4, 4.5, 9.1, 3.4, 6.1, 6.2_

- [x] 2. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Implement InlineCellEditNotifier state management
  - [x] 3.1 Implement InlineCellEditNotifier with enter/confirm/cancel edit methods
    - Create `lib/features/tag_editor/inline_cell_editing/notifiers/inline_cell_edit_notifier.dart`
    - Implement `enterEditMode(CellCoordinate cell, {bool prePopulate, bool selectAll, String? initialCharacter})` — guards against read-only columns, confirms existing edit if active, sets state with originalValue from file tags
    - Implement `confirmEdit({bool batchMode})` — compares values, builds TagEditCommand, handles batch confirmation dialog, executes command via UndoRedoManager, exits edit mode
    - Implement `cancelEdit()` — resets state without creating a command
    - Implement `updateValue(String value)` — updates currentValue in state
    - Implement `moveFocus(CellCoordinate cell)` — sets focusedCell without entering edit mode
    - _Requirements: 1.1, 1.2, 2.1, 2.3, 3.1, 3.2, 3.3, 3.4, 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2_

  - [x] 3.2 Implement navigation methods (navigateNext, navigatePrevious, navigateDown)
    - Add `navigateNext()` — confirms current edit, calls `nextEditableColumn`, enters edit mode on target
    - Add `navigatePrevious()` — confirms current edit, calls `previousEditableColumn`, enters edit mode on target
    - Add `navigateDown()` — confirms current edit, moves to same column in next row, enters edit mode
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [x] 3.3 Create Riverpod provider for InlineCellEditNotifier
    - Create `lib/features/tag_editor/inline_cell_editing/providers/inline_cell_edit_provider.dart`
    - Define `inlineCellEditProvider` as `StateNotifierProvider<InlineCellEditNotifier, InlineCellEditState>`
    - Wire to existing `fileListProvider`, `selectionProvider`, and `undoRedoProvider`
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [ ]* 3.4 Write property test: Edit mode initialization preserves current value (Property 2)
    - **Property 2: Edit mode initialization preserves current value**
    - **Validates: Requirements 1.1**
    - Generate random AudioFile instances and editable column IDs
    - Assert: after `enterEditMode` with `prePopulate: true`, state's `originalValue` equals the file's tag value for that column

  - [ ]* 3.5 Write property test: Character-initiated edit mode contains only typed character (Property 3)
    - **Property 3: Character-initiated edit mode contains only the typed character**
    - **Validates: Requirements 2.3**
    - Generate random printable characters and editable columns
    - Assert: after `enterEditMode` with `initialCharacter`, state's `currentValue` equals exactly that character

  - [ ]* 3.6 Write property test: Cancel edit restores original value (Property 5)
    - **Property 5: Cancel edit restores original value (no state change)**
    - **Validates: Requirements 3.2**
    - Generate random edit states with modified currentValue
    - Assert: after `cancelEdit`, no TagEditCommand is created and state clears editing fields

  - [ ]* 3.7 Write property test: Single-file edit command contains exactly one file path (Property 9)
    - **Property 9: Single-file edit command contains exactly one file path**
    - **Validates: Requirements 6.1**
    - Generate single-file edit scenarios
    - Assert: resulting TagEditCommand has `filePaths.length == 1`

  - [ ]* 3.8 Write property test: Batch edit command contains all affected file paths (Property 10)
    - **Property 10: Batch edit command contains all affected file paths**
    - **Validates: Requirements 6.2**
    - Generate multi-file batch edit scenarios with N selected files
    - Assert: resulting TagEditCommand has `filePaths.length == N` containing all selected paths

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement EditableCell and InlineTextField widgets
  - [x] 5.1 Implement EditableCell widget
    - Create `lib/features/tag_editor/inline_cell_editing/widgets/editable_cell.dart`
    - Implement `EditableCell` as a `ConsumerWidget` that reads `inlineCellEditProvider`
    - Render static text when not editing, `InlineTextField` when this cell is the active edit cell
    - Show focus highlight border when this cell is the focused cell
    - Show edit mode border (visually distinct from selection) when in edit mode
    - Handle double-click to enter edit mode (check `isColumnEditable` first)
    - Show not-allowed cursor on read-only columns
    - _Requirements: 1.1, 1.3, 1.4, 1.5, 7.1, 7.2, 9.2, 9.3_

  - [x] 5.2 Implement InlineTextField widget
    - Create `lib/features/tag_editor/inline_cell_editing/widgets/inline_text_field.dart`
    - Implement `InlineTextField` as a `ConsumerStatefulWidget` with a `TextEditingController` and `FocusNode`
    - Auto-focus on mount, select all text if `selectAll` is true
    - Handle key events: Enter (confirm + navigate down), Escape (cancel), Tab (navigate next), Shift+Tab (navigate previous), Ctrl+Enter (batch confirm without prompt)
    - Match font size and padding of static cell text
    - Call `updateValue` on text changes
    - Confirm edit on focus loss (click outside)
    - _Requirements: 2.1, 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 5.5, 7.2, 10.1, 10.2_

  - [x] 5.3 Implement BatchConfirmDialog
    - Create `lib/features/tag_editor/inline_cell_editing/widgets/batch_confirm_dialog.dart`
    - Implement `showBatchConfirmDialog(BuildContext context, int selectedCount)` returning `Future<BatchConfirmResult>`
    - Display "Apply to all X selected files?" with Yes, No, and Cancel buttons
    - Define `BatchConfirmResult` enum: `yes`, `no`, `cancel`
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 5.4 Implement modified cell indicator
    - Create `lib/features/tag_editor/inline_cell_editing/widgets/modified_cell_indicator.dart`
    - Render a small colored corner triangle when the cell's tag value differs from the on-disk value
    - Remove indicator when file is saved or edit is undone to match on-disk value
    - _Requirements: 8.1, 8.2, 8.3_

  - [ ]* 5.5 Write property test: Confirm edit applies new value to file tags (Property 4)
    - **Property 4: Confirm edit applies new value to file tags**
    - **Validates: Requirements 3.1**
    - Generate random editable columns and new values differing from original
    - Assert: after confirm, the file's tag map contains the new value for that column

  - [ ]* 5.6 Write property test: Batch edit applies value to all selected files (Property 8)
    - **Property 8: Batch edit applies value to all selected files**
    - **Validates: Requirements 5.2, 5.5**
    - Generate multi-selection scenarios with random new values
    - Assert: after batch confirm, every selected file's tag map contains the new value

  - [ ]* 5.7 Write widget tests for EditableCell and InlineTextField
    - Test: double-click editable cell enters edit mode with text field
    - Test: double-click read-only cell shows tooltip and forbidden cursor
    - Test: Enter confirms edit, Escape cancels, Tab navigates next
    - Test: Ctrl+Enter applies batch without prompt
    - Test: focus loss confirms edit
    - Test: edit mode border is visually distinct from selection highlight
    - Test: text field uses same font size and padding as static cell
    - _Requirements: 1.1, 1.3, 1.4, 3.1, 3.2, 4.1, 5.5, 7.1, 7.2_

- [x] 6. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Integrate with DataGrid and wire keyboard handling
  - [x] 7.1 Add keyboard focus handling to DataGrid
    - Modify the existing DataGrid widget to support cell-level focus via arrow keys
    - Add `KeyboardListener` or `Focus` widget that handles F2 (enter edit mode with select all), printable character (enter edit mode with character), arrow keys (move focus)
    - Suppress side panel double-click behavior when edit mode is active
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 1.5, 10.3_

  - [x] 7.2 Wire EditableCell into DataGrid rows
    - Replace static cell rendering in DataRow with `EditableCell` widget for tag columns
    - Pass `isColumnEditable` result to each cell
    - Pass cell coordinate (row index from filtered list, column ID) to each cell
    - _Requirements: 1.1, 9.1, 9.2, 9.3_

  - [x] 7.3 Integrate undo/redo with inline edits
    - Ensure `confirmEdit` in `InlineCellEditNotifier` registers commands with existing `UndoRedoManager`
    - Verify undo restores previous values for single and batch edits
    - Verify redo re-applies edited values
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [ ]* 7.4 Write integration tests for full edit cycle
    - Test: enter edit mode → type value → confirm → verify file updated → undo → verify restored
    - Test: select multiple files → edit cell → confirm batch → verify all files updated → undo → verify all restored
    - Test: Tab through multiple cells, verify each enters edit mode on editable column
    - Test: double-click during edit mode does not open side panel
    - _Requirements: 1.1, 3.1, 4.1, 5.2, 6.1, 6.3_

- [x] 8. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate the 10 universal correctness properties defined in the design
- Unit tests validate specific examples and edge cases
- Pure-function core components (task 1) have no widget dependencies and are fully testable in isolation
- The existing `TagEditCommand` and `UndoRedoManager` are reused without modification
- Navigation functions and editability checks are pure functions for easy property-based testing

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3", "1.4", "1.5"] },
    { "id": 2, "tasks": ["1.6", "1.7", "1.8"] },
    { "id": 3, "tasks": ["3.1"] },
    { "id": 4, "tasks": ["3.2", "3.3"] },
    { "id": 5, "tasks": ["3.4", "3.5", "3.6", "3.7", "3.8"] },
    { "id": 6, "tasks": ["5.1", "5.3", "5.4"] },
    { "id": 7, "tasks": ["5.2", "5.5", "5.6"] },
    { "id": 8, "tasks": ["5.7"] },
    { "id": 9, "tasks": ["7.1", "7.2", "7.3"] },
    { "id": 10, "tasks": ["7.4"] }
  ]
}
```
