# Requirements Document

## Introduction

Column Resize enables users of Open Tag Editor to adjust data grid column widths by dragging header borders. The feature addresses the problem of fixed column widths that truncate long values (file paths, titles, comments) while wasting space on short-value columns (Track #, Disc #). Custom widths persist across sessions, and a double-click auto-fit option sizes columns to their content.

## Glossary

- **Data_Grid**: The main table widget that displays audio file metadata in rows and columns, supporting horizontal scrolling and virtualized rendering.
- **Column_Header**: The top row of the Data_Grid displaying column labels and providing interaction targets for resize, sort, and context menu actions.
- **Resize_Handle**: A draggable hit-target region on the right edge of each Column_Header cell that initiates column width adjustment when dragged.
- **Column_Config_Provider**: The Riverpod state notifier responsible for managing column visibility, ordering, and persisted width overrides via shared_preferences.
- **Tag_Indicator_Column**: The fixed-width icon column at position 0 that displays tag format indicators and cannot be resized or reordered.
- **Auto_Fit**: The action triggered by double-clicking a Resize_Handle that calculates and applies the optimal column width based on visible cell content.
- **Default_Width**: The initial width defined in a ColumnDefinition, used when no user override exists.

## Requirements

### Requirement 1: Drag-to-Resize Column Widths

**User Story:** As a user, I want to drag the right edge of a column header to resize that column, so that I can reveal truncated content or compact columns with short values.

#### Acceptance Criteria

1. THE Data_Grid SHALL display a Resize_Handle on the right edge of each resizable Column_Header cell.
2. WHEN the user hovers the pointer over a Resize_Handle, THE Data_Grid SHALL change the cursor to a horizontal resize cursor (col-resize).
3. WHEN the user drags a Resize_Handle horizontally, THE Data_Grid SHALL update the column width in real-time to match the drag position.
4. WHEN the user drags a Resize_Handle, THE Data_Grid SHALL enforce a minimum column width of 40 logical pixels.
5. WHEN the user drags a Resize_Handle, THE Data_Grid SHALL allow the column to grow without an upper bound, constrained only by available horizontal scroll width.
6. WHEN the user releases a Resize_Handle after dragging, THE Column_Config_Provider SHALL persist the new column width to shared_preferences.
7. THE Tag_Indicator_Column SHALL NOT display a Resize_Handle and SHALL NOT be resizable.

### Requirement 2: Double-Click to Auto-Fit Column Width

**User Story:** As a user, I want to double-click a column header border to auto-size that column to its content, so that I can quickly fit a column to its widest visible value without manual dragging.

#### Acceptance Criteria

1. WHEN the user double-clicks a Resize_Handle, THE Data_Grid SHALL calculate the width required to display the widest visible cell content in that column.
2. WHEN the Auto_Fit width is calculated, THE Data_Grid SHALL include the Column_Header label width in the calculation.
3. WHEN the Auto_Fit width exceeds 500 logical pixels, THE Data_Grid SHALL cap the applied width at 500 logical pixels.
4. WHEN the Auto_Fit width is less than 40 logical pixels, THE Data_Grid SHALL apply the minimum width of 40 logical pixels.
5. WHEN Auto_Fit completes, THE Column_Config_Provider SHALL persist the resulting width to shared_preferences.

### Requirement 3: Reset Column Widths to Defaults

**User Story:** As a user, I want to reset all columns to their default widths, so that I can undo all manual resizing in one action.

#### Acceptance Criteria

1. WHEN the user right-clicks on a Column_Header, THE Data_Grid SHALL display a context menu that includes a "Reset Column Widths" option.
2. WHEN the user selects "Reset Column Widths" from the context menu, THE Column_Config_Provider SHALL clear all persisted width overrides and restore every column to its Default_Width.
3. WHEN column widths are reset, THE Data_Grid SHALL immediately reflect the default widths without requiring an application restart.

### Requirement 4: Persist Column Widths Across Sessions

**User Story:** As a user, I want my custom column widths to be remembered when I restart the application, so that I do not have to resize columns every session.

#### Acceptance Criteria

1. THE Column_Config_Provider SHALL persist column width overrides as a map of column ID to width value in shared_preferences.
2. WHEN the application starts, THE Column_Config_Provider SHALL load persisted column widths and apply them to the Data_Grid.
3. WHEN a persisted column width references a column ID that no longer exists in the column definitions, THE Column_Config_Provider SHALL ignore that entry.
4. WHEN no persisted width exists for a column, THE Data_Grid SHALL use the Default_Width from the ColumnDefinition.

### Requirement 5: Resize Performance

**User Story:** As a user, I want column resizing to feel smooth and responsive, so that the interaction does not disrupt my workflow.

#### Acceptance Criteria

1. WHILE the user drags a Resize_Handle, THE Data_Grid SHALL render width updates at the display refresh rate without dropped frames when 500 or more rows are loaded.
2. THE Resize_Handle hit-target SHALL be at least 8 logical pixels wide to ensure reliable pointer acquisition on desktop platforms.

