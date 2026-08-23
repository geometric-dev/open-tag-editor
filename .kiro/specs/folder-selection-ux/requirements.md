# Requirements Document

## Introduction

This feature improves the folder selection and navigation UX in Open Tag Editor. The current approach relies on a native file picker dialog and a small "Recent Folders" dropdown in the address bar. Users who frequently jump between music folders find this workflow heavy — opening a system dialog or scrolling through a flat recent-folders list adds friction. This feature introduces a lightweight, always-accessible folder navigation mechanism that reduces the number of clicks and context switches needed to move between folders.

## Glossary

- **Folder_Panel**: A collapsible side panel that displays folder navigation controls, including bookmarks and recent history.
- **Bookmark**: A user-pinned folder path that persists across sessions and appears in the Folder_Panel for one-click access.
- **Recent_Folders_List**: An ordered list of the most recently loaded folder paths, displayed in the Folder_Panel.
- **Address_Bar**: The existing editable path display at the top of the file list panel.
- **Breadcrumb_Bar**: A segmented path display where each path segment is clickable, allowing navigation to any ancestor directory.
- **Folder_Panel_Toggle**: A toolbar button that shows or hides the Folder_Panel.
- **Quick_Switcher**: A keyboard-activated search overlay that filters bookmarks and recent folders by typed text.

## Requirements

### Requirement 1: Folder Panel Display

**User Story:** As a user, I want a lightweight side panel showing my bookmarked and recent folders, so that I can switch folders with a single click instead of opening a file dialog.

#### Acceptance Criteria

1. WHEN the user activates the Folder_Panel_Toggle, THE Folder_Panel SHALL appear as a collapsible panel on the left side of the file list area, occupying no more than 250 pixels of width.
2. WHEN the Folder_Panel is visible, THE Folder_Panel SHALL display two sections in top-to-bottom order: a Bookmarks section followed by a Recent_Folders_List section displaying at most 10 entries.
3. WHEN the user activates the Folder_Panel_Toggle while the Folder_Panel is visible, THE Folder_Panel SHALL collapse and hide, returning the full width to the file list area.
4. THE Folder_Panel SHALL persist its visibility state (expanded or collapsed) to local storage so that upon the next application launch, the panel restores to its last-set visibility state.
5. IF no persisted visibility state exists (first application launch), THEN THE Folder_Panel SHALL default to the collapsed (hidden) state.
6. THE Folder_Panel SHALL occupy no more than 250 pixels of width when expanded.

### Requirement 2: Bookmark Management

**User Story:** As a user, I want to pin frequently used folders as bookmarks, so that I can access them instantly without remembering paths or scrolling through history.

#### Acceptance Criteria

1. WHEN the user right-clicks a folder entry in the Recent_Folders_List, THE Folder_Panel SHALL display a context menu with an "Add to Bookmarks" option.
2. WHEN the user selects "Add to Bookmarks", THE Folder_Panel SHALL append the folder path to the end of the Bookmarks section.
3. IF the user selects "Add to Bookmarks" for a folder path that already exists in the Bookmarks section, THEN THE Folder_Panel SHALL not create a duplicate entry and SHALL leave the existing bookmark unchanged.
4. WHEN the user right-clicks a Bookmark entry, THE Folder_Panel SHALL display a context menu with a "Remove Bookmark" option.
5. WHEN the user selects "Remove Bookmark", THE Folder_Panel SHALL remove the entry from the Bookmarks section.
6. THE Folder_Panel SHALL persist all Bookmarks across application sessions.
7. WHEN the user drags a Bookmark entry, THE Folder_Panel SHALL allow reordering via drag-and-drop.
8. THE Folder_Panel SHALL persist the user-defined Bookmark order across sessions.
9. THE Folder_Panel SHALL display each Bookmark entry with the folder name as the primary label and the full path in a secondary line below it.
10. THE Folder_Panel SHALL support a maximum of 50 Bookmarks.

### Requirement 3: One-Click Folder Loading

**User Story:** As a user, I want to click a folder in the panel to immediately load its contents, so that switching folders is as fast as possible.

#### Acceptance Criteria

1. WHEN the user clicks a folder entry in the Bookmarks section, THE Application SHALL replace the current file list with audio files loaded from that folder path using the current recursive-loading setting and update the loaded folder path to the selected folder.
2. WHEN the user clicks a folder entry in the Recent_Folders_List section, THE Application SHALL replace the current file list with audio files loaded from that folder path using the current recursive-loading setting and update the loaded folder path to the selected folder.
3. IF the currently loaded files have unsaved changes, THEN THE Application SHALL display the unsaved-changes confirmation dialog before loading the new folder, and SHALL abort the folder load if the user selects "Cancel".
4. IF the selected folder path does not exist on the filesystem, THEN THE Application SHALL display an inline error indicator on the folder entry and skip loading.
5. IF the selected folder path exists but the Application lacks read permission, THEN THE Application SHALL display an inline error indicator on the folder entry and skip loading.
6. IF the selected folder path exists but contains zero audio files, THEN THE Application SHALL clear the current file list and update the loaded folder path to the selected folder.
7. WHEN a folder is successfully loaded via the Folder_Panel, THE Application SHALL add the folder path to the Recent_Folders_List.

### Requirement 4: Breadcrumb Navigation

**User Story:** As a user, I want to see the current folder path as clickable segments, so that I can quickly navigate to any parent directory without retyping the path.

#### Acceptance Criteria

1. WHEN a folder is loaded, THE Breadcrumb_Bar SHALL display the folder path as a series of clickable path segments separated by a forward-slash or chevron divider character, with one segment per directory level in the path.
2. WHEN the user single-clicks a path segment in the Breadcrumb_Bar, THE Application SHALL load audio files from the directory represented by the path up to and including that segment, using the current recursive loading setting.
3. IF the user single-clicks a breadcrumb segment and the target directory does not exist or is not accessible, THEN THE Application SHALL display an error message indicating the path is unavailable and SHALL retain the current folder and file list unchanged.
4. THE Breadcrumb_Bar SHALL replace the existing text-only display in the Address_Bar while preserving the editable-path behaviour; WHEN the user double-clicks the Breadcrumb_Bar or presses a keyboard shortcut, THE Breadcrumb_Bar SHALL switch to a text input field pre-filled with the full current path and selected for overwrite.
5. WHEN the full breadcrumb path exceeds the Breadcrumb_Bar's visible width, THE Breadcrumb_Bar SHALL collapse leading segments into a single overflow button that, when clicked, displays a dropdown menu listing the hidden segments in path order, each clickable to navigate to that directory.
6. WHEN the user submits or cancels the editable text field (via Enter, Escape, or focus loss), THE Breadcrumb_Bar SHALL return to displaying clickable path segments.

### Requirement 5: Quick Switcher

**User Story:** As a user, I want a keyboard shortcut to search and jump to any bookmarked or recent folder by typing part of its name, so that I can switch folders without using the mouse.

#### Acceptance Criteria

1. WHEN the user presses Ctrl+G, THE Quick_Switcher SHALL appear as a floating overlay with a text input field and display the full combined list of Bookmarks and Recent_Folders_List entries.
2. WHILE the Quick_Switcher is visible, THE Quick_Switcher SHALL filter the combined list of Bookmarks and Recent_Folders_List entries by case-insensitive substring match against the typed text, updating results within 50 milliseconds of each keystroke.
3. IF the typed text does not match any entry in the combined list, THEN THE Quick_Switcher SHALL display a "No matching folders" message in place of the results list.
4. WHILE the Quick_Switcher is visible and at least one result is displayed, THE Quick_Switcher SHALL highlight the first matching result and allow arrow-key navigation to move the highlight between results, wrapping from last to first and first to last.
5. WHEN the user presses Enter with a result highlighted, THE Application SHALL load audio files from the selected folder path.
6. WHEN the user presses Escape or clicks outside the Quick_Switcher, THE Quick_Switcher SHALL close without loading a folder.

### Requirement 6: Sibling Folder Navigation

**User Story:** As a user, I want to quickly move to the next or previous sibling folder, so that I can process albums sequentially without navigating up and back down.

#### Acceptance Criteria

1. WHEN the user presses Alt+Right, THE Application SHALL load audio files from the next sibling folder (in case-insensitive alphabetical order) of the currently loaded folder, using the same folder-loading behavior as opening a folder via the toolbar.
2. WHEN the user presses Alt+Left, THE Application SHALL load audio files from the previous sibling folder (in case-insensitive alphabetical order) of the currently loaded folder, using the same folder-loading behavior as opening a folder via the toolbar.
3. IF the currently loaded folder is the last sibling in alphabetical order and the user presses Alt+Right, THEN THE Application SHALL remain on the current folder and display a status message indicating no next sibling exists.
4. IF the currently loaded folder is the first sibling in alphabetical order and the user presses Alt+Left, THEN THE Application SHALL remain on the current folder and display a status message indicating no previous sibling exists.
5. IF the currently loaded files have unsaved changes, THEN THE Application SHALL display the unsaved-changes confirmation dialog before navigating to the sibling folder.
6. IF no folder is currently loaded when the user presses Alt+Right or Alt+Left, THEN THE Application SHALL take no action.
7. IF the target sibling folder cannot be read due to a permission or access error, THEN THE Application SHALL remain on the current folder and display a status message indicating the sibling folder could not be accessed.
8. WHEN determining sibling folders, THE Application SHALL consider only immediate subdirectories of the parent folder, excluding hidden folders (names starting with a dot).

### Requirement 7: Recent Folders Enhancement

**User Story:** As a user, I want the recent folders list to show more context and be easier to scan, so that I can identify the right folder faster.

#### Acceptance Criteria

1. THE Recent_Folders_List SHALL display each entry with the folder name in bold on the first line and the full path on a secondary line below it, truncating the path with an ellipsis if it exceeds the available display width.
2. THE Recent_Folders_List SHALL display a maximum of 20 entries ordered by most recently loaded first, and WHEN the list exceeds 20 entries, THE Recent_Folders_List SHALL remove the oldest entry.
3. WHEN the user right-clicks a Recent_Folders_List entry, THE Folder_Panel SHALL display a context menu with a "Remove from History" option.
4. WHEN the user selects "Remove from History", THE Folder_Panel SHALL remove that entry from the Recent_Folders_List and persist the change so it remains removed after application restart.
5. IF a Recent_Folders_List entry references a folder path that no longer exists on disk, THEN THE Recent_Folders_List SHALL display that entry with a visual indicator distinguishing it from valid folders.
