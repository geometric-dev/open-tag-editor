# Requirements Document

## Introduction

Unsaved Changes Protection prevents users from silently losing in-memory tag edits when closing the application or loading new files. The app already tracks modified state (`AudioFile.isModified`, `hasUnsavedChangesProvider`) and has a confirmation dialog pattern (`ConfirmationDialog`), but no guard exists on the window-close or folder-load paths. This feature adds guard dialogs at both exit points and a visual dirty-state indicator in the window title bar.

## Glossary

- **Dirty_State**: The condition where one or more loaded `AudioFile` instances have `isModified == true`, meaning their in-memory tags differ from the on-disk file.
- **Guard_Dialog**: A modal dialog that intercepts a destructive action (close, load) when Dirty_State is true, offering Save, Discard, or Cancel options.
- **Window_Title**: The text displayed in the OS window title bar, managed via `window_manager.setTitle()`.
- **File_List_Provider**: The Riverpod `StateNotifierProvider` holding the list of loaded `AudioFile` instances.
- **Has_Unsaved_Changes_Provider**: An existing `Provider<bool>` that returns `true` when any file in the list is modified.
- **Modified_File_Count_Provider**: An existing `Provider<int>` counting files with `isModified == true`.

## Requirements

### Requirement 1: Guard on Window Close

**User Story:** As a user, I want to be warned before the application closes when I have unsaved tag edits, so that I don't accidentally lose my work.

#### Acceptance Criteria

1. WHEN the user attempts to close the application window AND Dirty_State is true, THE application SHALL intercept the close event and display a Guard_Dialog.
2. THE Guard_Dialog SHALL display the count of modified files (e.g., "You have unsaved changes to 3 file(s).").
3. THE Guard_Dialog SHALL offer three actions: "Save" (writes all modified tags to disk then closes), "Discard" (closes without saving), and "Cancel" (aborts the close and returns to the editor).
4. WHEN the user selects "Save", THE application SHALL execute the standard save flow (respecting the confirm-before-saving setting) and close the window only after a successful save.
5. WHEN the user selects "Save" AND the save fails for any file, THE application SHALL NOT close and SHALL display the save error feedback.
6. WHEN the user selects "Discard", THE application SHALL close the window immediately without writing any changes.
7. WHEN the user selects "Cancel", THE application SHALL abort the close and return focus to the editor.
8. WHEN Dirty_State is false, THE application SHALL close immediately without showing a Guard_Dialog.

### Requirement 2: Guard on Folder/File Load

**User Story:** As a user, I want to be warned before loading a new folder or files when I have unsaved edits, so that I can save my work before the file list changes.

#### Acceptance Criteria

1. WHEN the user initiates a folder load (Open Folder, address bar navigation, drag-and-drop folder, or recent folder selection) AND Dirty_State is true, THE application SHALL display a Guard_Dialog before proceeding.
2. WHEN the user initiates a file load (Open Files or drag-and-drop files) AND Dirty_State is true, THE application SHALL display a Guard_Dialog before proceeding.
3. THE Guard_Dialog SHALL display the count of modified files.
4. THE Guard_Dialog SHALL offer three actions: "Save" (writes all modified tags then proceeds with the load), "Discard" (proceeds with the load without saving), and "Cancel" (aborts the load operation).
5. WHEN the user selects "Save" AND the save succeeds, THE application SHALL proceed with the load operation.
6. WHEN the user selects "Save" AND the save fails, THE application SHALL abort the load and display the save error feedback.
7. WHEN the user selects "Discard", THE application SHALL clear the undo history and proceed with the load.
8. WHEN the user selects "Cancel", THE application SHALL abort the load and return to the current state.

### Requirement 3: Window Title Dirty Indicator

**User Story:** As a user, I want to see at a glance whether I have unsaved changes, so that I know when I need to save before closing.

#### Acceptance Criteria

1. WHEN Dirty_State is true, THE application SHALL prepend an asterisk and space to the window title (e.g., "* Open Tag Editor").
2. WHEN Dirty_State transitions to false (after save or discard), THE application SHALL remove the asterisk prefix from the window title.
3. THE window title update SHALL occur within the same frame as the state change (no perceptible delay).
4. THE base window title SHALL remain "Open Tag Editor" (matching the current `MaterialApp.title`).

### Requirement 4: Integration with Existing Save Flow

**User Story:** As a user, I want the guard dialog's "Save" action to behave identically to the normal save action, so that my confirm-before-saving preference is respected.

#### Acceptance Criteria

1. WHEN the Guard_Dialog "Save" action is triggered, THE application SHALL use the same save logic as the toolbar Save button (including the confirm-before-saving setting gate).
2. IF the confirm-before-saving setting is enabled AND the user cancels the confirmation dialog, THE Guard_Dialog SHALL remain open (the close/load is not yet resolved).
3. THE Guard_Dialog "Save" action SHALL save ALL modified files, not just the currently selected files.

### Requirement 5: Undo History Cleanup on Discard

**User Story:** As a user, I expect that discarding changes also clears the undo history for those changes, so that I cannot accidentally redo discarded edits after loading new files.

#### Acceptance Criteria

1. WHEN the user selects "Discard" in the Guard_Dialog for a folder/file load, THE application SHALL call `UndoRedoManager.clear()` before proceeding with the load.
2. WHEN the user selects "Discard" in the Guard_Dialog for window close, THE application SHALL NOT need to clear undo history (the process is terminating).

### Requirement 6: Guard Dialog Appearance

**User Story:** As a user, I want the guard dialog to be clear and unambiguous, so that I can make an informed decision quickly.

#### Acceptance Criteria

1. THE Guard_Dialog title SHALL be "Unsaved Changes".
2. THE Guard_Dialog body SHALL include the modified file count and a brief explanation (e.g., "You have unsaved changes to N file(s). What would you like to do?").
3. THE "Cancel" button SHALL be a text button (lowest visual weight).
4. THE "Discard" button SHALL be a text button with a destructive/warning color.
5. THE "Save" button SHALL be a filled/primary button (highest visual weight).
6. THE Guard_Dialog SHALL be dismissible via Escape key (treated as Cancel).
7. THE Guard_Dialog SHALL NOT be dismissible by clicking outside (barrier is not dismissible) to prevent accidental data loss.
