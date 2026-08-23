# Requirements Document

## Introduction

Window State Persistence enables Open Tag Editor to remember its window geometry (size and position), internal layout state (tag panel visibility and width), and optionally the last loaded folder across application sessions. Currently, users must re-arrange their workspace every time they launch the app. This feature eliminates that friction by saving layout state on close and restoring it on startup, including a new resizable splitter between the file list and tag panel.

## Glossary

- **Window_State_Service**: The service responsible for reading and writing window geometry and layout state to persistent storage via shared_preferences.
- **Window_Manager**: The platform integration layer (window_manager package) that provides programmatic control over desktop window size, position, and display information.
- **Tag_Panel**: The collapsible side panel on the right side of the main layout that displays the tag editor form.
- **Splitter**: A draggable divider widget between the File_List_Panel and the Tag_Panel that allows the user to resize the Tag_Panel width.
- **File_List_Panel**: The left-side panel containing the data grid of loaded audio files.
- **Window_Geometry**: The combination of window width, height, x-position, and y-position that defines the window's size and location on screen.
- **Primary_Display**: The operating system's designated primary monitor, used as the fallback display target.
- **General_Settings**: The application preferences model that stores user-configurable options including the reopen-last-folder toggle.

## Requirements

### Requirement 1: Persist Window Geometry on Close

**User Story:** As a user, I want the app to remember its window size and position when I close it, so that it reopens exactly where I left it.

#### Acceptance Criteria

1. WHEN the application window is closed, THE Window_State_Service SHALL save the current Window_Geometry (width, height, x, y) to shared_preferences.
2. THE Window_State_Service SHALL write the Window_Geometry asynchronously so that the save operation does not delay application shutdown.
3. THE Window_State_Service SHALL store width and height as integer logical pixel values.
4. THE Window_State_Service SHALL store x and y as integer logical pixel values representing the top-left corner of the window.

### Requirement 2: Restore Window Geometry on Startup

**User Story:** As a user, I want the app to restore its previous window size and position on launch, so that my workspace is immediately familiar.

#### Acceptance Criteria

1. WHEN the application starts and persisted Window_Geometry exists, THE Window_Manager SHALL apply the saved size and position before the first frame is painted.
2. WHEN the application starts and no persisted Window_Geometry exists, THE Window_Manager SHALL use a default size of 1280x800 logical pixels centered on the Primary_Display.
3. WHEN the persisted window position places the window entirely off-screen (no connected display contains the saved coordinates), THE Window_Manager SHALL center the window on the Primary_Display using the persisted size.
4. WHEN the persisted window size exceeds the available display dimensions, THE Window_Manager SHALL clamp the size to fit within the Primary_Display bounds.

### Requirement 3: Resizable Tag Panel via Splitter

**User Story:** As a user, I want to drag a splitter between the file list and tag panel to resize the tag panel width, so that I can allocate screen space according to my needs.

#### Acceptance Criteria

1. WHEN the Tag_Panel is open, THE Splitter SHALL be displayed as a draggable vertical divider between the File_List_Panel and the Tag_Panel.
2. WHEN the user drags the Splitter horizontally, THE Tag_Panel SHALL resize in real-time to match the drag position.
3. THE Splitter SHALL enforce a minimum Tag_Panel width of 280 logical pixels.
4. THE Splitter SHALL enforce a maximum Tag_Panel width of 50 percent of the current window width.
5. WHEN the user hovers the pointer over the Splitter, THE Splitter SHALL change the cursor to a horizontal resize cursor (col-resize).
6. THE Splitter hit-target SHALL be at least 8 logical pixels wide to ensure reliable pointer acquisition.
7. WHEN the window is resized such that the Tag_Panel width exceeds 50 percent of the new window width, THE Splitter SHALL clamp the Tag_Panel width to 50 percent of the new window width.

### Requirement 4: Persist Tag Panel State

**User Story:** As a user, I want the app to remember whether the tag panel was open or closed and its width, so that my layout preference is preserved between sessions.

#### Acceptance Criteria

1. WHEN the Tag_Panel open/closed state changes, THE Window_State_Service SHALL persist the new state to shared_preferences.
2. WHEN the user finishes dragging the Splitter, THE Window_State_Service SHALL persist the Tag_Panel width to shared_preferences.
3. WHEN the application starts and a persisted Tag_Panel state exists, THE Tag_Panel SHALL restore its open/closed state and width before the first frame is painted.
4. WHEN the application starts and no persisted Tag_Panel state exists, THE Tag_Panel SHALL default to closed with a width of 380 logical pixels.
5. WHEN the persisted Tag_Panel width is less than 280 logical pixels, THE Window_State_Service SHALL clamp the restored width to 280 logical pixels.
6. WHEN the persisted Tag_Panel width exceeds 50 percent of the current window width, THE Window_State_Service SHALL clamp the restored width to 50 percent of the current window width.

### Requirement 5: Persist and Restore Last Loaded Folder

**User Story:** As a user, I want the option to have the app automatically reopen the last folder I was working with, so that I can resume my session without manually navigating to it.

#### Acceptance Criteria

1. WHEN a folder is successfully loaded, THE Window_State_Service SHALL persist the folder path to shared_preferences.
2. WHERE the "Reopen last folder on startup" setting is enabled, THE application SHALL reload the most recently persisted folder path on startup.
3. WHERE the "Reopen last folder on startup" setting is disabled, THE application SHALL start with no folder loaded.
4. THE General_Settings SHALL include a "Reopen last folder on startup" option that defaults to disabled.
5. IF the persisted folder path no longer exists on disk when the application starts, THEN THE application SHALL start with no folder loaded and clear the persisted path.

### Requirement 6: State Restoration Timing

**User Story:** As a user, I want the restored layout to appear immediately without visible jumps or flicker, so that the startup experience feels polished.

#### Acceptance Criteria

1. THE application SHALL complete all layout state restoration (Window_Geometry, Tag_Panel state, Splitter position) before the first frame is painted.
2. THE application SHALL not display a default-sized window that then resizes to the persisted geometry (no visible layout jump).
3. WHEN state restoration fails due to corrupted or unreadable persisted data, THE application SHALL fall back to default values silently without displaying an error to the user.
