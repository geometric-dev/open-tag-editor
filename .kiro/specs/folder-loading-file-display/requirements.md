# Requirements Document

## Introduction

This feature completes the file list panel per PRD 01 (Folder Loading & File Display). The existing implementation provides a basic 3-column file list with filter, drag-and-drop, and folder picker. This spec covers the remaining gaps: full column set with sorting/show-hide/reorder, tag indicator icon, desktop-style multi-select, address bar, recent folders, recursive loading toggle with threshold guard, enhanced status bar, and a "show selected only" filter toggle.

## Glossary

- **File_List_Panel**: The left-side panel widget displaying loaded audio files in a tabular grid with column headers.
- **Column_Header**: A clickable header cell in the file list table that displays the column name and sort indicator.
- **Tag_Indicator**: A small icon in the first column of each file row showing whether the file has embedded metadata tags.
- **Address_Bar**: A read-only text display above the file list showing the currently loaded folder path.
- **Recent_Folders_Menu**: A dropdown or popup menu providing quick access to previously loaded folder paths.
- **Recursive_Toggle**: A UI control that enables or disables recursive subfolder scanning when loading a folder.
- **Threshold_Guard**: A confirmation dialog shown when recursive loading detects more files than the configured threshold.
- **Status_Bar**: The bottom bar of the application window displaying aggregate information about loaded and selected files.
- **Selection_State**: The set of currently selected file paths, managed via Riverpod state provider.
- **Column_Configuration**: The persisted user preferences for column visibility and ordering.
- **Audio_File**: The data model representing a loaded audio file with its metadata tags, audio properties, and file info.

## Requirements

### Requirement 1: Tag Indicator Icon Column

**User Story:** As a user, I want to see at a glance which files have embedded tags and which do not, so that I can identify untagged files quickly.

#### Acceptance Criteria

1. THE File_List_Panel SHALL display a Tag_Indicator column as the first column in the file grid.
2. WHEN an Audio_File has one or more non-empty tag values, THE Tag_Indicator SHALL display a filled icon.
3. WHEN an Audio_File has no tag values, THE Tag_Indicator SHALL display a grey unfilled icon.
4. WHEN the user hovers over the Tag_Indicator, THE File_List_Panel SHALL display a tooltip showing the detected tag format name (e.g., "ID3v2.3", "Vorbis Comment", "APE").
5. IF the tag format cannot be determined, THEN THE Tag_Indicator tooltip SHALL display "Unknown format".

### Requirement 2: Full Column Set

**User Story:** As a user, I want to see all relevant metadata columns for my audio files, so that I can review and compare tag data across files.

#### Acceptance Criteria

1. THE File_List_Panel SHALL support displaying the following columns: Tag Indicator, Filename, Title, Artist, Album, Year, Genre, Track Number, Disc Number, Bitrate, Duration, Album Artist, Comment, BPM, Composer, Conductor, Relative File Path.
2. THE File_List_Panel SHALL display Duration values formatted as "mm:ss" for durations under one hour and "h:mm:ss" for durations of one hour or more.
3. THE File_List_Panel SHALL display Bitrate values with a "kbps" suffix.
4. THE File_List_Panel SHALL display the Relative File Path column as the file path relative to the loaded root folder.
5. WHEN a tag field has no value for a given Audio_File, THE File_List_Panel SHALL display an empty cell for that column.

### Requirement 3: Column Sorting

**User Story:** As a user, I want to sort the file list by any column, so that I can organize files by artist, album, track number, or other criteria.

#### Acceptance Criteria

1. WHEN the user clicks a Column_Header, THE File_List_Panel SHALL sort the file list by that column in ascending order.
2. WHEN the user clicks the same Column_Header a second time, THE File_List_Panel SHALL reverse the sort to descending order.
3. WHEN the user clicks the same Column_Header a third time, THE File_List_Panel SHALL remove sorting and return to the original load order.
4. THE File_List_Panel SHALL display a visual sort direction indicator (arrow) on the active sort column header.
5. WHEN sorting by Track Number or Disc Number, THE File_List_Panel SHALL sort numerically rather than lexicographically.
6. WHEN sorting by Duration or Bitrate, THE File_List_Panel SHALL sort numerically.

### Requirement 4: Column Show/Hide

**User Story:** As a user, I want to choose which columns are visible, so that I can focus on the metadata fields relevant to my workflow.

#### Acceptance Criteria

1. THE File_List_Panel SHALL provide a context menu or column chooser allowing the user to toggle visibility of each column.
2. WHEN the user hides a column, THE File_List_Panel SHALL remove that column from the display immediately.
3. WHEN the user shows a previously hidden column, THE File_List_Panel SHALL restore that column to its configured position.
4. THE File_List_Panel SHALL persist column visibility preferences across application sessions.
5. THE File_List_Panel SHALL always display the Tag Indicator and Filename columns (they cannot be hidden).

### Requirement 5: Column Reorder

**User Story:** As a user, I want to drag columns to rearrange their order, so that I can customize the layout to my preference.

#### Acceptance Criteria

1. WHEN the user drags a Column_Header to a new position, THE File_List_Panel SHALL reorder the columns accordingly.
2. THE File_List_Panel SHALL persist column order preferences across application sessions.
3. THE File_List_Panel SHALL prevent the Tag Indicator column from being moved from the first position.

### Requirement 6: Desktop-Style Multi-Select

**User Story:** As a user, I want to select multiple files using standard desktop keyboard modifiers, so that I can perform batch operations on a subset of files.

#### Acceptance Criteria

1. WHEN the user clicks a file row without modifier keys, THE Selection_State SHALL contain only that file.
2. WHEN the user Ctrl+clicks a file row, THE Selection_State SHALL toggle that file's selection without affecting other selections.
3. WHEN the user Shift+clicks a file row, THE Selection_State SHALL select all files between the last-clicked file and the Shift+clicked file (inclusive).
4. WHEN the user presses Ctrl+A, THE Selection_State SHALL contain all currently visible files.
5. THE File_List_Panel SHALL visually highlight all selected rows with a distinct background color.

### Requirement 7: Enhanced Status Bar

**User Story:** As a user, I want to see aggregate statistics about my loaded files and current selection, so that I can understand the scope of my library at a glance.

#### Acceptance Criteria

1. THE Status_Bar SHALL display the total number of loaded files.
2. THE Status_Bar SHALL display the number of currently selected files.
3. THE Status_Bar SHALL display the total duration of all loaded files formatted as "Xh Ym".
4. THE Status_Bar SHALL display the total duration of selected files formatted as "Xh Ym".
5. THE Status_Bar SHALL display the total file size of all loaded files formatted in human-readable units (KB, MB, GB).
6. THE Status_Bar SHALL display the count of modified files.

### Requirement 8: Address Bar

**User Story:** As a user, I want to see the path of the currently loaded folder, so that I know which directory I am working with.

#### Acceptance Criteria

1. THE Address_Bar SHALL display the full path of the most recently loaded folder.
2. WHEN no folder has been loaded, THE Address_Bar SHALL display placeholder text indicating no folder is loaded.
3. WHEN files are loaded via drag-and-drop of a folder, THE Address_Bar SHALL update to show that folder's path.
4. WHEN files are loaded via drag-and-drop of individual files, THE Address_Bar SHALL display the common parent directory of the dropped files.

### Requirement 9: Recent Folders

**User Story:** As a user, I want quick access to folders I have previously loaded, so that I can switch between projects without navigating the file system each time.

#### Acceptance Criteria

1. WHEN a folder is loaded successfully, THE Recent_Folders_Menu SHALL add that folder path to the recent list.
2. THE Recent_Folders_Menu SHALL store up to 10 recent folder paths.
3. WHEN the recent list exceeds 10 entries, THE Recent_Folders_Menu SHALL remove the oldest entry.
4. WHEN the user selects a path from the Recent_Folders_Menu, THE File_List_Panel SHALL load files from that folder.
5. THE Recent_Folders_Menu SHALL persist recent folder paths across application sessions.
6. THE Recent_Folders_Menu SHALL be accessible from the Address_Bar area or toolbar.

### Requirement 10: Recursive Loading Toggle and Threshold Guard

**User Story:** As a user, I want to control whether subfolders are scanned and be warned before loading very large directories, so that I do not accidentally freeze the application.

#### Acceptance Criteria

1. THE Recursive_Toggle SHALL be accessible from the toolbar or address bar area.
2. WHEN the Recursive_Toggle is enabled, THE File_List_Panel SHALL load audio files from all subfolders of the selected folder.
3. WHEN the Recursive_Toggle is disabled, THE File_List_Panel SHALL load audio files only from the top-level of the selected folder.
4. WHEN recursive loading detects more than 500 audio files, THE Threshold_Guard SHALL display a confirmation dialog showing the detected file count.
5. WHEN the user confirms the Threshold_Guard dialog, THE File_List_Panel SHALL proceed to load all detected files.
6. WHEN the user declines the Threshold_Guard dialog, THE File_List_Panel SHALL load only the top-level folder files.
7. THE Recursive_Toggle state SHALL persist across application sessions.

### Requirement 11: Show Selected Files Only Toggle

**User Story:** As a user, I want to filter the file list to show only my current selection, so that I can focus on a subset of files for batch editing.

#### Acceptance Criteria

1. THE File_List_Panel SHALL provide a toggle control to show only selected files.
2. WHEN the "show selected only" toggle is active, THE File_List_Panel SHALL display only files that are in the current Selection_State.
3. WHEN the "show selected only" toggle is deactivated, THE File_List_Panel SHALL display all files (subject to the text filter).
4. WHEN the "show selected only" toggle is active and the Selection_State changes, THE File_List_Panel SHALL update the displayed list to reflect the new selection.

### Requirement 12: Virtualized Scrolling Performance

**User Story:** As a user, I want the file list to remain responsive when hundreds of files are loaded, so that I can scroll and interact without lag.

#### Acceptance Criteria

1. THE File_List_Panel SHALL use virtualized scrolling (rendering only visible rows) for the file list.
2. WHEN 500 files are loaded, THE File_List_Panel SHALL complete initial display within 3 seconds on a modern desktop machine.
3. WHILE scrolling through the file list, THE File_List_Panel SHALL maintain a frame rate suitable for smooth interaction.
4. THE File_List_Panel SHALL use fixed row heights to enable efficient scroll position calculation.
