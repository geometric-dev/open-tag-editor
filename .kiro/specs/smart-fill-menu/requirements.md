# Requirements Document

## Introduction

Smart Fill Menu adds a context-aware dropdown to editable cells in the Data Grid that offers intelligent fill options based on the unique values present in that column across all loaded files. When hovering over an editable cell, a small dropdown arrow appears to the right of the cell text. Clicking the arrow opens a menu listing all distinct values from that column, allowing the user to apply any value to all rows or only to the current selection. This builds on the existing inline cell editing infrastructure and provides a faster alternative to manual batch editing when standardising tag values across files.

## Glossary

- **Data_Grid**: The main table widget that displays audio file metadata in rows and columns, supporting selection, inline editing, and horizontal scrolling.
- **Editable_Cell**: A cell in the Data_Grid that supports inline editing of tag values (excludes read-only columns such as filename, bitrate, duration).
- **Smart_Fill_Menu**: The dropdown menu displayed when the user clicks the fill arrow on an Editable_Cell, presenting context-aware fill options.
- **Fill_Arrow**: The small dropdown arrow icon that appears on the right side of an Editable_Cell when the pointer hovers over it.
- **Column_Values**: The set of unique, non-empty tag values present in a given column across all loaded files in the Data_Grid.
- **Selection**: The set of currently selected file rows in the Data_Grid, managed by the SelectionNotifier.
- **Fill_Action**: The operation of setting a tag field to a specific value for either all files or only the selected files.
- **Inline_Cell_Edit_Notifier**: The existing Riverpod state notifier that manages inline cell editing lifecycle and applies tag edits via TagEditCommand.
- **TagEditCommand**: The existing undo-able command that applies a tag value change to one or more files.

## Requirements

### Requirement 1: Display Fill Arrow on Hover

**User Story:** As a user, I want to see a dropdown arrow when I hover over an editable cell, so that I can discover and access the smart fill options.

#### Acceptance Criteria

1. WHEN the pointer hovers over an Editable_Cell, THE Data_Grid SHALL display a Fill_Arrow icon on the right side of that cell.
2. WHEN the pointer leaves an Editable_Cell, THE Data_Grid SHALL hide the Fill_Arrow icon.
3. THE Fill_Arrow SHALL be right-aligned within the cell padding, SHALL NOT overlap the cell text content area, and SHALL have a minimum hit target of 24×24 dp.
4. WHILE an Editable_Cell is in active edit mode (text field shown), THE Data_Grid SHALL NOT display the Fill_Arrow for that cell.
5. THE Fill_Arrow SHALL only appear on columns where inline editing is supported (editable columns).
6. WHEN the user clicks the Fill_Arrow, THE Data_Grid SHALL NOT trigger inline edit mode on that cell.

### Requirement 2: Open Smart Fill Menu

**User Story:** As a user, I want to click the fill arrow to open a menu of fill options, so that I can quickly apply a value across rows.

#### Acceptance Criteria

1. WHEN the user clicks the Fill_Arrow, THE Smart_Fill_Menu SHALL open as a popup menu anchored to the cell.
2. WHILE the Smart_Fill_Menu is open, THE Smart_Fill_Menu SHALL list each unique non-empty value from Column_Values for that column as a menu item.
3. WHILE the Smart_Fill_Menu is open, THE Smart_Fill_Menu SHALL display a final option to set the field to blank (empty string).
4. THE Smart_Fill_Menu SHALL order the value options in the order they first appear in the file list, followed by the blank option at the end.
5. IF Column_Values for the column is empty (all cells are blank), THEN THE Smart_Fill_Menu SHALL display only the blank option.
6. IF Column_Values contains more than 20 unique values, THEN THE Smart_Fill_Menu SHALL present the options in a scrollable list with a maximum visible height of 10 items.

### Requirement 3: Menu Label Wording Based on Selection State

**User Story:** As a user, I want the menu labels to reflect whether I'm applying to all files or just my selection, so that I understand the scope of the action before I click.

#### Acceptance Criteria

1. WHEN no files are selected or all files are selected, THE Smart_Fill_Menu SHALL label each option as "Set all to {value}", where {value} is the literal tag value string.
2. WHEN a subset of files is selected (more than zero but fewer than all), THE Smart_Fill_Menu SHALL label each option as "Set selected to {value}", where {value} is the literal tag value string.
3. WHEN no files are selected or all files are selected, THE Smart_Fill_Menu SHALL label the blank option as "Set all to blank".
4. WHEN a subset of files is selected, THE Smart_Fill_Menu SHALL label the blank option as "Set selected to blank".
5. THE Smart_Fill_Menu SHALL determine the selection state at the moment the menu opens and SHALL NOT update labels if the selection changes while the menu is visible.
6. IF {value} exceeds 40 characters, THEN THE Smart_Fill_Menu SHALL truncate the displayed value to 40 characters followed by an ellipsis character ("…") in the label.

### Requirement 4: Apply Fill Action

**User Story:** As a user, I want to click a menu option to apply that value to the appropriate files, so that I can batch-edit tag values efficiently.

#### Acceptance Criteria

1. WHEN the user selects a value option from the Smart_Fill_Menu and no subset is selected (zero files selected or all files selected), THE Fill_Action SHALL apply the chosen value to that column for all loaded files.
2. WHEN the user selects a value option from the Smart_Fill_Menu and a subset of files is selected (more than zero but fewer than all), THE Fill_Action SHALL apply the chosen value to that column for only the selected files.
3. WHEN the user selects the blank option from the Smart_Fill_Menu, THE Fill_Action SHALL set the column value to an empty string for the target files determined by the same scope rules as criteria 1 and 2.
4. WHEN the Fill_Action is applied and at least one target file has a different value than the chosen value, THE Fill_Action SHALL create a single TagEditCommand containing all affected files and register it with the UndoRedoManager.
5. IF all target files already have the chosen value (no change required), THEN THE Fill_Action SHALL NOT create or register a TagEditCommand.
6. WHEN the Fill_Action completes, THE Data_Grid SHALL reflect the updated values in all affected cells before processing the next user interaction.
7. WHEN the user selects any option from the Smart_Fill_Menu, THE Smart_Fill_Menu SHALL close after the Fill_Action is initiated.

### Requirement 5: Value Sourcing

**User Story:** As a user, I want the menu to show all unique values from the entire column regardless of my selection, so that I can pick any existing value to standardise across files.

#### Acceptance Criteria

1. THE Smart_Fill_Menu SHALL source its value options from all loaded files in the Data_Grid, not only from selected files.
2. THE Smart_Fill_Menu SHALL exclude empty/blank values from the list of value options, where blank is defined as an empty string or a string containing only whitespace characters (blank is handled as a separate final option).
3. THE Smart_Fill_Menu SHALL deduplicate values using case-sensitive string comparison so that each unique value appears exactly once (e.g., "Rock" and "rock" are treated as distinct values).
4. WHEN multiple files share the same value for a column (by case-sensitive comparison), THE Smart_Fill_Menu SHALL display that value only once.
5. IF the column contains more than 50 unique non-empty values, THEN THE Smart_Fill_Menu SHALL present the list in a scrollable region so that all values remain accessible.

### Requirement 6: Interaction with Existing Features

**User Story:** As a user, I want the smart fill menu to work alongside inline editing and undo/redo without conflicts, so that my workflow remains consistent.

#### Acceptance Criteria

1. WHEN a Fill_Action is applied, THE Inline_Cell_Edit_Notifier SHALL NOT enter edit mode on any cell.
2. IF a cell is in active edit mode when the user clicks a Fill_Arrow, THEN THE Inline_Cell_Edit_Notifier SHALL cancel the active edit and discard unsaved changes before the Smart_Fill_Menu opens.
3. WHEN the user presses Ctrl+Z after a Fill_Action has been applied, THE undo/redo system SHALL reverse the entire Fill_Action in a single step, restoring all affected cells to their previous values.
4. WHEN the user presses Ctrl+Y after undoing a Fill_Action, THE undo/redo system SHALL re-apply the Fill_Action in a single step.
5. WHEN the Smart_Fill_Menu is open and the user clicks outside the menu, THE Smart_Fill_Menu SHALL close without applying any action.
6. WHEN the Smart_Fill_Menu is open and the user presses Escape, THE Smart_Fill_Menu SHALL close without applying any action.

### Requirement 7: Single Row Context

**User Story:** As a user, I want the smart fill menu to work correctly when only one row is selected or when I'm hovering over a single row, so that I can still access all column values for quick assignment.

#### Acceptance Criteria

1. WHEN only a single row is selected, THE Smart_Fill_Menu SHALL source options from all loaded files in that column.
2. WHEN only a single row is selected and the user picks a value, THE Fill_Action SHALL apply the value only to that single selected row.
3. WHEN only a single row is selected and more than one file is loaded, THE Smart_Fill_Menu SHALL label options as "Set selected to {value}" and the blank option as "Set selected to blank".
4. WHEN only one file is loaded and that file's row is selected, THE Smart_Fill_Menu SHALL label options as "Set all to {value}" and the blank option as "Set all to blank".
5. WHEN no rows are selected and the user clicks a Fill_Arrow on any row, THE Smart_Fill_Menu SHALL treat the action as applying to all loaded files and label options as "Set all to {value}".
