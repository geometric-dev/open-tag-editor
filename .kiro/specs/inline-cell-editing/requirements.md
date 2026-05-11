# Requirements Document

## Introduction

Inline Cell Editing enables direct in-place editing of tag values within the DataGrid, eliminating the two-step workflow of selecting a file and editing in the side panel. This feature targets power users who expect spreadsheet-like editing with keyboard navigation, batch application across selected files, and full undo/redo integration.

## Glossary

- **DataGrid**: The main virtualized table widget displaying audio files and their tag values in rows and columns.
- **Cell**: A single intersection of a row (audio file) and a column (tag field or metadata field) in the DataGrid.
- **Edit_Mode**: The state in which a Cell displays an active text input field allowing the user to modify the tag value.
- **Editable_Column**: A column whose values correspond to writable tag fields (e.g., Title, Artist, Album). Excludes read-only metadata columns.
- **Read_Only_Column**: A column displaying computed or file-level metadata that cannot be modified inline (Tag Indicator, Filename, Bitrate, Duration, Relative Path).
- **Focused_Cell**: The Cell that currently has keyboard focus, indicated by a visible focus highlight.
- **Active_Edit_Cell**: The Cell currently in Edit_Mode with a text input field displayed.
- **Batch_Edit**: An edit operation applied to the same column across all currently selected rows.
- **UndoRedoManager**: The existing Riverpod-based state notifier that manages a stack of UndoableCommand instances for undo and redo operations.
- **TagEditCommand**: The existing command class that encapsulates a tag field edit on one or more files for undo/redo support.
- **Selection**: The set of currently selected rows (file paths) managed by the SelectionProvider.

## Requirements

### Requirement 1: Enter Edit Mode via Double-Click

**User Story:** As a user, I want to double-click a cell to start editing its value inline, so that I can quickly correct tag values without opening the side panel.

#### Acceptance Criteria

1. WHEN the user double-clicks an Editable_Column Cell, THE DataGrid SHALL replace the Cell content with a text input field pre-populated with the current tag value.
2. WHEN the user double-clicks an Editable_Column Cell, THE DataGrid SHALL place the text cursor at the end of the pre-populated value.
3. WHEN the user double-clicks a Read_Only_Column Cell, THE DataGrid SHALL display a tooltip indicating the Cell is not editable.
4. WHEN the user double-clicks a Read_Only_Column Cell, THE DataGrid SHALL display a forbidden cursor style.
5. WHILE a Cell is in Edit_Mode, THE DataGrid SHALL NOT open the side panel tag editor on double-click.

### Requirement 2: Enter Edit Mode via Keyboard

**User Story:** As a power user, I want to press F2 or start typing to enter edit mode on the focused cell, so that I can edit without reaching for the mouse.

#### Acceptance Criteria

1. WHEN the user presses the F2 key while a Focused_Cell is on an Editable_Column, THE DataGrid SHALL enter Edit_Mode on that Cell with the full current value selected.
2. WHEN the user presses the F2 key while a Focused_Cell is on a Read_Only_Column, THE DataGrid SHALL ignore the keypress and remain in the current state.
3. WHEN the user types a printable character while a Focused_Cell is on an Editable_Column and Edit_Mode is not active, THE DataGrid SHALL enter Edit_Mode with the text input field containing only the typed character.
4. WHEN the user types a printable character while a Focused_Cell is on a Read_Only_Column, THE DataGrid SHALL ignore the keypress.

### Requirement 3: Confirm and Cancel Edits

**User Story:** As a user, I want clear ways to confirm or cancel my edits, so that I can control when changes are applied.

#### Acceptance Criteria

1. WHEN the user presses Enter while in Edit_Mode, THE DataGrid SHALL confirm the edit and apply the new value to the file's tag.
2. WHEN the user presses Escape while in Edit_Mode, THE DataGrid SHALL cancel the edit and restore the Cell to its original value.
3. WHEN the user clicks outside the Active_Edit_Cell, THE DataGrid SHALL confirm the edit and apply the new value to the file's tag.
4. WHEN the edit is confirmed with an unchanged value, THE DataGrid SHALL exit Edit_Mode without creating an undo command.

### Requirement 4: Navigation While Editing

**User Story:** As a power user, I want to navigate between editable cells using Tab and Enter, so that I can efficiently edit multiple fields without using the mouse.

#### Acceptance Criteria

1. WHEN the user presses Tab while in Edit_Mode, THE DataGrid SHALL confirm the current edit and move focus to the next Editable_Column Cell in the same row.
2. WHEN the user presses Shift+Tab while in Edit_Mode, THE DataGrid SHALL confirm the current edit and move focus to the previous Editable_Column Cell in the same row.
3. WHEN the user presses Enter while in Edit_Mode, THE DataGrid SHALL confirm the current edit and move focus to the same column in the next row.
4. WHEN Tab is pressed on the last Editable_Column in a row, THE DataGrid SHALL wrap focus to the first Editable_Column of the next row.
5. WHEN Shift+Tab is pressed on the first Editable_Column in a row, THE DataGrid SHALL wrap focus to the last Editable_Column of the previous row.
6. WHEN the navigation target Cell is reached, THE DataGrid SHALL automatically enter Edit_Mode on that Cell.

### Requirement 5: Batch Inline Editing

**User Story:** As a user editing multiple files, I want to apply an inline edit to all selected files at once, so that I can make bulk corrections efficiently.

#### Acceptance Criteria

1. WHEN the user confirms an edit while multiple rows are selected, THE DataGrid SHALL display a confirmation prompt asking "Apply to all X selected files?" with Yes, No, and Cancel options.
2. WHEN the user selects Yes on the batch confirmation prompt, THE DataGrid SHALL apply the new value to the same column for all selected rows.
3. WHEN the user selects No on the batch confirmation prompt, THE DataGrid SHALL apply the new value only to the single edited row.
4. WHEN the user selects Cancel on the batch confirmation prompt, THE DataGrid SHALL discard the edit and restore the original value.
5. WHEN the user presses Ctrl+Enter while in Edit_Mode with multiple rows selected, THE DataGrid SHALL apply the edit to all selected rows without displaying a confirmation prompt.

### Requirement 6: Undo/Redo Integration

**User Story:** As a user, I want inline edits to be undoable, so that I can revert mistakes without manually re-entering previous values.

#### Acceptance Criteria

1. WHEN a single-cell inline edit is confirmed, THE DataGrid SHALL register a single TagEditCommand with the UndoRedoManager.
2. WHEN a batch inline edit is confirmed, THE DataGrid SHALL register a single TagEditCommand covering all affected files with the UndoRedoManager.
3. WHEN the user triggers undo after an inline edit, THE UndoRedoManager SHALL restore the previous value for all files affected by that edit.
4. WHEN the user triggers redo after undoing an inline edit, THE UndoRedoManager SHALL re-apply the edited value for all files affected by that edit.

### Requirement 7: Visual Feedback for Edit Mode

**User Story:** As a user, I want clear visual distinction between a selected cell and an actively edited cell, so that I always know the current editing state.

#### Acceptance Criteria

1. WHILE a Cell is in Edit_Mode, THE DataGrid SHALL display a visible border around the Active_Edit_Cell that is visually distinct from the row selection highlight.
2. WHILE a Cell is in Edit_Mode, THE DataGrid SHALL display the text input field with the same font size and padding as the non-editing Cell text.
3. THE DataGrid SHALL render the transition into and out of Edit_Mode within 50 milliseconds.

### Requirement 8: Modified Cell Indicator

**User Story:** As a user, I want to see which cells have been modified but not yet saved to disk, so that I can track my unsaved changes.

#### Acceptance Criteria

1. WHILE a Cell's tag value differs from the on-disk value, THE DataGrid SHALL display a subtle visual indicator on that Cell (e.g., a colored corner triangle).
2. WHEN the file is saved to disk, THE DataGrid SHALL remove the modified indicator from all Cells of that file.
3. WHEN an edit is undone and the value matches the on-disk value, THE DataGrid SHALL remove the modified indicator from that Cell.

### Requirement 9: Non-Editable Column Behavior

**User Story:** As a user, I want read-only columns to clearly communicate they cannot be edited, so that I don't waste time attempting to edit metadata fields.

#### Acceptance Criteria

1. THE DataGrid SHALL treat the following columns as Read_Only_Column: Tag Indicator, Filename, Bitrate, Duration, and Relative Path.
2. WHEN the user attempts to enter Edit_Mode on a Read_Only_Column Cell via any method, THE DataGrid SHALL prevent Edit_Mode activation.
3. WHILE the mouse hovers over a Read_Only_Column Cell, THE DataGrid SHALL display a not-allowed cursor style.

### Requirement 10: Performance

**User Story:** As a user, I want edit mode transitions and cell navigation to feel instant, so that the editing workflow does not interrupt my concentration.

#### Acceptance Criteria

1. THE DataGrid SHALL enter Edit_Mode within 50 milliseconds of the triggering action.
2. THE DataGrid SHALL exit Edit_Mode within 50 milliseconds of the confirming or cancelling action.
3. WHEN navigating between cells via Tab or Enter, THE DataGrid SHALL complete the transition without visible flicker or layout shift.
