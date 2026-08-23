# Requirements Document

## Introduction

This feature introduces structured error handling and user feedback for the Open Tag Rename application. Currently, errors during batch operations (tag reading, writing, renaming) are either silently swallowed or shown as a brief snackbar with no detail. Users cannot see which specific files failed, why they failed, or retry the failed subset. This feature surfaces errors clearly with actionable detail, provides a persistent error log for the session, and enables retry of failed operations.

## Glossary

- **App**: The Open Tag Rename Flutter desktop application
- **Error_Log**: A session-scoped in-memory collection of ErrorEntry records, capped at 500 entries
- **ErrorEntry**: A structured record containing file path, operation type, error message, and timestamp
- **Error_Panel**: A bottom panel (IDE console-style) that displays the Error_Log in a scrollable list, toggled via the Status_Bar error count
- **Status_Bar**: The EnhancedStatusBar widget at the bottom of the main window showing file counts, selection info, and error indicators
- **Snackbar**: A Material Design notification bar shown at the bottom of the viewport for transient or persistent messages
- **Batch_Operation**: A tag read, tag write, or file rename operation applied to multiple files
- **Corrupt_File**: An audio file that failed tag reading during folder loading, included in the file list with an error indicator

## Requirements

### Requirement 1: Error Notification via Snackbar

**User Story:** As a user, I want to be notified when a batch operation has failures, so that I am aware errors occurred and can investigate further.

#### Acceptance Criteria

1. WHEN a Batch_Operation completes with one or more failures, THE App SHALL display a Snackbar containing a summary of the failure count and a "View Details" action button.
2. WHILE a Snackbar is displaying an error-level message, THE App SHALL keep the Snackbar visible until the user explicitly dismisses the Snackbar or activates the "View Details" button.
3. WHEN a Batch_Operation completes with zero failures, THE App SHALL display a success Snackbar that auto-hides after 3 seconds.
4. WHEN the user activates the "View Details" button on an error Snackbar, THE App SHALL open the Error_Panel.

### Requirement 2: Error Log State Management

**User Story:** As a user, I want errors to persist within my current folder session, so that I can review them at any time without losing context.

#### Acceptance Criteria

1. WHEN a Batch_Operation produces one or more failures, THE App SHALL create an ErrorEntry for each failed file containing the file path, operation type (read, write, or rename), error message, and timestamp.
2. WHEN a new ErrorEntry is created, THE App SHALL append the ErrorEntry to the Error_Log.
3. WHILE the Error_Log contains 500 entries, WHEN a new ErrorEntry is created, THE App SHALL remove the oldest ErrorEntry before appending the new ErrorEntry.
4. WHEN the user loads a new folder, THE App SHALL clear all entries from the Error_Log.
5. THE App SHALL retain Error_Log entries across multiple Batch_Operations within the same loaded folder session.

### Requirement 3: Error Details Panel

**User Story:** As a user, I want to view a detailed list of all errors in my session, so that I can identify which files failed and understand why.

#### Acceptance Criteria

1. WHEN the user activates the error count in the Status_Bar, THE App SHALL toggle the visibility of the Error_Panel.
2. THE Error_Panel SHALL display each ErrorEntry as a row containing the file path, operation type, error message, and timestamp.
3. THE Error_Panel SHALL render as a bottom panel using the existing ResizableSplitter pattern.
4. WHILE the Error_Log contains more than 50 entries, THE Error_Panel SHALL use a virtualized list to maintain smooth scrolling performance.
5. WHEN the Error_Log is empty, THE Error_Panel SHALL display a message indicating no errors are recorded.

### Requirement 4: Retry Failed Operations

**User Story:** As a user, I want to retry failed operations without re-configuring them, so that I can recover from transient errors efficiently.

#### Acceptance Criteria

1. WHEN the user activates the "Retry All Failed" button in the Error_Panel, THE App SHALL re-attempt each failed operation in the Error_Log using the same parameters as the original operation.
2. WHEN the user activates the retry action on a single ErrorEntry row, THE App SHALL re-attempt only that specific failed operation using the same parameters as the original operation.
3. WHEN a retried operation succeeds, THE App SHALL remove the corresponding ErrorEntry from the Error_Log.
4. WHEN a retried operation fails again, THE App SHALL update the corresponding ErrorEntry with the new error message and timestamp.
5. WHILE a retry operation is in progress, THE App SHALL disable the retry buttons to prevent duplicate submissions.

### Requirement 5: Corrupt File Handling in File List

**User Story:** As a user, I want to see which files failed to load their tags, so that I can identify problematic files while still being able to rename them by filename.

#### Acceptance Criteria

1. WHEN a file fails tag reading during folder loading, THE App SHALL include the file in the file list with empty tag fields and a visual error indicator icon.
2. THE App SHALL display the error indicator as a red icon in the tag indicator column for each Corrupt_File.
3. WHEN the user hovers over the error indicator icon, THE App SHALL display a tooltip containing the tag read error message.
4. THE App SHALL allow Corrupt_File entries to be selected for rename operations.
5. WHEN a Corrupt_File is included in a rename Batch_Operation, THE App SHALL use the existing filename data to perform the rename.

### Requirement 6: Status Bar Error Integration

**User Story:** As a user, I want a persistent indicator of session errors in the status bar, so that I always know whether errors have occurred without needing to check the error panel.

#### Acceptance Criteria

1. WHILE the Error_Log contains one or more entries, THE Status_Bar SHALL display a warning icon and the total error count.
2. WHEN the Error_Log becomes empty, THE Status_Bar SHALL hide the warning icon and error count.
3. WHEN the user clicks the error count in the Status_Bar, THE App SHALL toggle the Error_Panel visibility.
4. THE Status_Bar SHALL update the displayed error count immediately when entries are added to or removed from the Error_Log.
