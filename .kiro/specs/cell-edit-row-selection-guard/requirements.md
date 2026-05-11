# Requirements Document

## Introduction

This feature refines the DataGrid's selection and editing behaviour to match standard desktop list-view conventions. It enforces a row-selection prerequisite before entering edit mode, exits edit mode immediately on focus loss, adds marquee (rubber-band) drag selection, and implements full Ctrl/Shift multi-selection with both mouse and keyboard. The goal is a predictable, Windows Explorer-like interaction model where select-then-edit is the norm and all standard modifier-key selection patterns work as expected.

## Glossary

- **DataGrid**: The main virtualized table widget displaying audio files and their tag values in rows and columns.
- **Cell**: A single intersection of a row (audio file) and a column (tag field) in the DataGrid.
- **Edit_Mode**: The state in which a Cell displays an active text input field allowing the user to modify the tag value.
- **Selected_Row**: A row whose file path is present in the current Selection state, indicated by a visual highlight.
- **Selection**: The set of currently selected rows (file paths) managed by the SelectionProvider.
- **Editable_Column**: A column whose values correspond to writable tag fields (e.g., Title, Artist, Album).
- **InlineCellEditNotifier**: The Riverpod state notifier that manages the inline cell editing lifecycle.
- **Focus_Loss**: The event that occurs when the user clicks outside the Active_Edit_Cell, including clicking another row, clicking empty space, or clicking a non-editable area.
- **Marquee**: A semi-transparent selection rectangle drawn by clicking and dragging across the DataGrid, used to select all rows whose bounds intersect the rectangle (also known as rubber-band selection or lasso selection).
- **Anchor_Row**: The row from which Shift+click and Shift+arrow range selections are measured. Set on plain click or Ctrl+click; preserved during Shift-based operations.

## Requirements

### Requirement 1: Row Selection Guard for Edit Mode Entry

**User Story:** As a user, I want to be prevented from entering edit mode on an unselected row, so that accidental double-clicks on unselected rows do not trigger editing and I have a clear two-step workflow of select-then-edit.

#### Acceptance Criteria

1. WHEN the user double-clicks an Editable_Column Cell on a Selected_Row, THE DataGrid SHALL enter Edit_Mode on that Cell.
2. WHEN the user double-clicks an Editable_Column Cell on a row that is not a Selected_Row, THE DataGrid SHALL NOT enter Edit_Mode on that Cell and SHALL select that row without entering Edit_Mode.
3. WHEN the user presses F2 while the Focused_Cell is on an Editable_Column of a Selected_Row, THE InlineCellEditNotifier SHALL enter Edit_Mode on that Cell.
4. WHEN the user presses F2 while the Focused_Cell is on a row that is not a Selected_Row, THE InlineCellEditNotifier SHALL NOT enter Edit_Mode.
5. WHEN the user types a printable character while the Focused_Cell is on a row that is not a Selected_Row, THE InlineCellEditNotifier SHALL NOT enter Edit_Mode.
6. WHEN the user types a printable character while the Focused_Cell is on an Editable_Column of a Selected_Row and Edit_Mode is not active, THE InlineCellEditNotifier SHALL enter Edit_Mode with the text input field containing only the typed character.

### Requirement 2: Exit Edit Mode on Focus Loss

**User Story:** As a user, I want edit mode to immediately end when I click outside the active cell (such as clicking another row), so that I have a clean transition between editing and navigating.

#### Acceptance Criteria

1. WHEN the user clicks a different row while a Cell is in Edit_Mode, THE InlineCellEditNotifier SHALL confirm the current edit, apply the new value to the file's tag, and exit Edit_Mode.
2. WHEN the user clicks a different row while a Cell is in Edit_Mode, THE DataGrid SHALL replace the current row selection with the newly clicked row.
3. WHEN the user clicks any area outside the Active_Edit_Cell (including non-row areas within the DataGrid, other UI panels, or the window background) while a Cell is in Edit_Mode, THE InlineCellEditNotifier SHALL confirm the current edit, apply the new value to the file's tag, and exit Edit_Mode.
4. WHEN the InlineTextField loses focus due to user interaction (such as clicking elsewhere or tabbing away) while in Edit_Mode, THE InlineCellEditNotifier SHALL confirm the current edit and exit Edit_Mode.
5. IF the InlineTextField loses focus as a result of the user pressing Escape, THEN THE InlineCellEditNotifier SHALL cancel the edit, restore the original value, and exit Edit_Mode without applying changes.

### Requirement 3: Marquee (Rubber-Band) Row Selection

**User Story:** As a user, I want to click and drag a rectangle over multiple rows in the DataGrid to select them all at once, so that I can quickly select a contiguous range of files without holding Shift or clicking each row individually.

#### Acceptance Criteria

1. WHEN the user presses the primary mouse button on empty space or a row and drags without releasing, THE DataGrid SHALL display a semi-transparent selection rectangle (marquee) from the drag start point to the current pointer position.
2. WHILE the user is dragging the marquee, THE DataGrid SHALL continuously update the Selection to include all rows whose bounds intersect the marquee rectangle.
3. WHEN the user releases the mouse button after dragging a marquee, THE DataGrid SHALL finalize the Selection to contain exactly the rows intersected by the marquee at the moment of release, and SHALL hide the marquee rectangle.
4. IF the user holds Ctrl while initiating a marquee drag, THEN THE DataGrid SHALL add the marquee-intersected rows to the existing Selection without deselecting previously selected rows.
5. IF the user does not hold Ctrl while initiating a marquee drag, THEN THE DataGrid SHALL replace the existing Selection with only the marquee-intersected rows.
6. WHEN the marquee drag distance is less than 4 logical pixels in both axes, THE DataGrid SHALL treat the gesture as a normal click (single-row select) rather than a marquee selection.
7. WHILE a Cell is in Edit_Mode and the user initiates a marquee drag, THE InlineCellEditNotifier SHALL confirm the current edit and exit Edit_Mode before the marquee selection begins.
8. WHEN the user drags the marquee beyond the visible viewport boundary, THE DataGrid SHALL auto-scroll in the drag direction to reveal additional rows for selection.

### Requirement 4: Standard Multi-Selection (Ctrl+Click, Shift+Click, Keyboard)

**User Story:** As a user, I want standard table multi-selection behaviour using Ctrl, Shift, and keyboard modifiers, so that I can select discrete rows, contiguous ranges, and extend selections the same way I would in Windows Explorer or any standard list view.

#### Acceptance Criteria

**Click behaviour:**

1. WHEN the user clicks a row without modifier keys, THE DataGrid SHALL deselect all other rows and select only the clicked row (single select).
2. WHEN the user Ctrl+clicks a row, THE DataGrid SHALL toggle that row's selected state without affecting any other rows in the Selection.
3. WHEN the user Shift+clicks a row, THE DataGrid SHALL select the contiguous range from the Anchor_Row to the clicked row (inclusive), replacing any previous Selection.
4. WHEN the user Ctrl+Shift+clicks a row, THE DataGrid SHALL add the contiguous range from the Anchor_Row to the clicked row to the existing Selection without deselecting previously selected rows.

**Anchor behaviour:**

5. WHEN the user clicks a row without Shift held (plain click or Ctrl+click), THE DataGrid SHALL set that row as the Anchor_Row.
6. WHEN the user Shift+clicks or Ctrl+Shift+clicks, THE DataGrid SHALL NOT change the Anchor_Row.

**Keyboard behaviour:**

7. WHEN the user presses Up/Down arrow without modifiers while a row is selected, THE DataGrid SHALL move the Selection to the adjacent row in that direction (single select), update the Anchor_Row, and scroll to keep the selected row visible.
8. WHEN the user presses Shift+Up or Shift+Down, THE DataGrid SHALL extend or contract the Selection by one row in that direction from the current focus position, without changing the Anchor_Row.
9. WHEN the user presses Ctrl+Shift+End, THE DataGrid SHALL extend the Selection from the current focus position to the last row in the list.
10. WHEN the user presses Ctrl+Shift+Home, THE DataGrid SHALL extend the Selection from the current focus position to the first row in the list.
11. WHEN the user presses Ctrl+A, THE DataGrid SHALL select all rows in the current file list.

**Interaction with Edit_Mode:**

12. WHEN any multi-selection gesture (Ctrl+click, Shift+click, Shift+arrow) is performed while a Cell is in Edit_Mode, THE InlineCellEditNotifier SHALL confirm the current edit and exit Edit_Mode before the selection change is applied.

### Requirement 5: Selection State Consistency

**User Story:** As a user, I want the selection state to remain consistent when transitioning between editing, marquee selection, and non-editing states, so that I always know which rows are active.

#### Acceptance Criteria

1. WHILE a Cell is in Edit_Mode, THE DataGrid SHALL include the edited row in the current Selection regardless of how Edit_Mode was entered.
2. WHEN Edit_Mode is exited via clicking another row without modifier keys held, THE DataGrid SHALL deselect all previously selected rows and select only the newly clicked row.
3. WHEN Edit_Mode is exited via Escape, THE DataGrid SHALL preserve the Selection as it existed at the moment Escape is pressed.
4. WHEN Edit_Mode is exited via Enter or Tab navigation to a different row, THE DataGrid SHALL replace the current Selection with only the navigation target row.
5. WHEN Edit_Mode is exited via clicking another row while Ctrl is held, THE DataGrid SHALL toggle the clicked row's selection state while preserving all other selected rows.
6. IF multiple rows are selected when Edit_Mode is entered, THEN THE DataGrid SHALL preserve the existing multi-row Selection and add the edited row to the Selection if not already included.
