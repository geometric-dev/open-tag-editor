# Requirements Document

## Introduction

When audio files are loaded recursively from a root folder, the file list currently displays all files in a flat list with no visual indication of folder structure. This feature adds non-selectable folder separator rows to the data grid that group files by their containing subfolder, showing the relative path from the selected root folder. Separators provide visual context for navigating large recursive file sets without affecting selection, editing, or other file operations.

## Glossary

- **Data_Grid**: The virtualized table widget that displays loaded audio files as rows with columns for filename, tags, and audio properties.
- **Folder_Separator**: A non-interactive row inserted into the Data_Grid that displays a relative folder path and visually groups the files contained in that folder.
- **Root_Folder**: The top-level folder selected by the user for loading, as shown in the address bar.
- **Relative_Path**: The path of a subfolder expressed relative to the Root_Folder, using forward-slash delimiters between path segments (e.g. "Artist 1 / (2005) Album 1").
- **File_Row**: A standard interactive row in the Data_Grid representing a single loaded audio file.
- **Recursive_Loading**: The mode where the application scans all subfolders beneath the Root_Folder to find audio files.

## Requirements

### Requirement 1: Display Folder Separators in Recursive Mode

**User Story:** As a user browsing a recursively loaded folder, I want to see folder separator headers in the file list, so that I can visually identify which subfolder each group of files belongs to.

#### Acceptance Criteria

1. WHILE Recursive_Loading is enabled AND files are loaded from subfolders, THE Data_Grid SHALL insert a Folder_Separator row before each group of files that share the same parent directory.
2. THE Folder_Separator SHALL display the Relative_Path of the subfolder from the Root_Folder, using " / " (space-slash-space) as the segment delimiter.
3. WHEN files exist directly in the Root_Folder during Recursive_Loading, THE Data_Grid SHALL insert a Folder_Separator before those files displaying only the Root_Folder's own name (the final segment of the Root_Folder path) with no additional path segments.
4. WHEN Recursive_Loading is disabled, THE Data_Grid SHALL display no Folder_Separator rows.
5. WHILE Recursive_Loading is enabled, THE Data_Grid SHALL insert Folder_Separator rows only for directories that directly contain at least one loaded audio file, and SHALL NOT insert separators for intermediate directories that contain only subfolders.

### Requirement 2: Folder Separators Are Non-Interactive

**User Story:** As a user, I want folder separators to be purely visual grouping headers, so that they do not interfere with file selection, keyboard navigation, or editing workflows.

#### Acceptance Criteria

1. THE Folder_Separator SHALL NOT respond to mouse click, double-click, right-click, or drag interactions, and SHALL NOT display a pointer cursor on hover.
2. THE Folder_Separator SHALL NOT be included in the set of selectable items for single-click, Ctrl+click, Shift+click, or Ctrl+A selection operations.
3. WHEN the user navigates with Arrow Up, Arrow Down, Shift+Arrow Up, or Shift+Arrow Down, THE Data_Grid SHALL skip Folder_Separator rows and move focus or extend selection to the next or previous File_Row.
4. THE Folder_Separator SHALL NOT be eligible for inline cell editing or any tag modification operation.
5. WHEN the user performs a marquee (rubber-band) selection, THE Data_Grid SHALL exclude Folder_Separator rows from the resulting selection set.
6. WHEN the user navigates with Tab or Shift+Tab during inline cell editing, THE Data_Grid SHALL skip Folder_Separator rows and move the editable cell focus to the next or previous File_Row.

### Requirement 3: Folder Separator Visual Presentation

**User Story:** As a user, I want folder separators to be visually distinct from file rows, so that I can immediately distinguish grouping headers from actual files.

#### Acceptance Criteria

1. THE Folder_Separator SHALL span the full width of the Data_Grid, ignoring individual column boundaries.
2. THE Folder_Separator SHALL render with a background colour that is different from both the unselected File_Row background and the selected File_Row background.
3. THE Folder_Separator SHALL display a folder icon immediately followed by a horizontal gap of 8 logical pixels, followed by the Relative_Path text, all vertically centred within the row.
4. THE Folder_Separator SHALL render the Relative_Path text in bold font weight to visually distinguish it from the regular-weight text used in File_Rows.
5. IF the Relative_Path text exceeds the available horizontal space, THEN THE Folder_Separator SHALL truncate the text with an ellipsis at the trailing end.

### Requirement 4: Ordering of Folder Separators and Files

**User Story:** As a user, I want folder separators to appear in a logical directory order, so that the file list mirrors the folder structure on disk.

#### Acceptance Criteria

1. WHEN no user sort is applied, THE Data_Grid SHALL order Folder_Separator rows by case-insensitive alphabetical comparison of their Relative_Path, with the Root_Folder separator always appearing first regardless of alphabetical position.
2. WHEN no user sort is applied, THE Data_Grid SHALL order File_Rows within each folder group by filename using the same case-insensitive alphabetical comparison.
3. WHEN a user sort is applied to a column, THE Data_Grid SHALL sort File_Rows globally by the selected column in the user-chosen direction (ascending or descending) and SHALL NOT display Folder_Separator rows.
4. WHEN the user clears the sort (returns to default order), THE Data_Grid SHALL restore Folder_Separator rows and File_Row ordering to the same state defined in criteria 1 and 2.

### Requirement 5: Folder Separators and Filtering

**User Story:** As a user, I want folder separators to remain consistent when I filter the file list, so that visible files still show their folder context.

#### Acceptance Criteria

1. WHEN a text filter is active AND at least one file in a subfolder matches the filter, THE Data_Grid SHALL display the Folder_Separator for that subfolder.
2. WHEN a text filter is active AND no files in a subfolder match the filter, THE Data_Grid SHALL hide the Folder_Separator for that subfolder.
3. WHEN the "show selected only" filter is active, THE Data_Grid SHALL display Folder_Separators only for subfolders that contain at least one file that is both in the current Selection_State and passing the active text filter (if any).
4. WHEN all active filters are cleared, THE Data_Grid SHALL restore Folder_Separator rows for all subfolders that contain loaded files.
5. WHILE a user sort is applied to a column, THE Data_Grid SHALL NOT display Folder_Separator rows regardless of active filter state.

### Requirement 6: Folder Separator Row Height and Scrolling

**User Story:** As a user scrolling through a large file list, I want folder separators to integrate smoothly with the virtualized scroll, so that performance remains consistent.

#### Acceptance Criteria

1. THE Folder_Separator row SHALL occupy the same fixed height as a File_Row (the value used for the Data_Grid itemExtent) to maintain consistent virtualized scrolling.
2. THE Data_Grid SHALL include Folder_Separator rows in the total item count used for scroll extent calculation, such that total scroll extent equals total item count multiplied by the fixed row height.
3. WHEN the user scrolls, THE Data_Grid SHALL render Folder_Separator rows using the same fixed-extent virtualization as File_Rows, building only the rows visible within the viewport plus any framework-provided cache extent.
4. WHEN Folder_Separator rows are added or removed due to sort or filter changes, THE Data_Grid SHALL preserve the scroll offset so that the previously visible content region remains in view without abrupt jumps.
