# Requirements: UX Review Fixes (Issues 1–7)

## Overview

Address seven UX/UI issues identified during code review: an unreachable feature, a non-functional button, permanent snackbars, missing guards on dialogs, a filter trap, and missing file removal capability.

## Requirements

### 1. Tags from Filename Feature Accessibility

- 1.1 The "Tags from Filename" (Extractor) dialog MUST be launchable from the main toolbar.
- 1.2 The toolbar button MUST use a distinct icon and tooltip ("Tags from Filename").
- 1.3 The button MUST be disabled when no files are loaded (fileListProvider is empty).

### 2. Album Art Toolbar Button

- 2.1 The existing "Album Art" toolbar button MUST perform a useful action: open the tag edit panel and switch to the Album Art tab.
- 2.2 If the tag panel is already open, clicking the button MUST switch to the Album Art tab without closing/reopening the panel.
- 2.3 The button MUST be disabled when no files are selected.

### 3. Dismissable Error Snackbars

- 3.1 Error snackbars (those with "View Details" action) MUST include a close/dismiss button (SnackBarAction or showCloseIcon).
- 3.2 Error snackbars MUST auto-dismiss after 30 seconds if the user takes no action.
- 3.3 Only one error snackbar may be visible at a time — new errors replace the previous snackbar.

### 4. Rename Dialog File Guard

- 4.1 The "Rename Files" toolbar button MUST be disabled when no files are loaded.
- 4.2 If somehow opened with no files, the dialog MUST show an informative empty state and disable the Rename action button.

### 5. Online Lookup Selection Guard

- 5.1 The "Online Lookup" toolbar button MUST be disabled when no files are selected.
- 5.2 The tooltip MUST indicate why it's disabled (e.g., "Select files to look up metadata").

### 6. Show-Selected-Only Filter Safety

- 6.1 When "Show Selected Only" is active, a visible indicator/chip MUST appear above or in the filter bar making the active filter obvious.
- 6.2 The indicator MUST include a one-click way to clear the filter (e.g., a close/X button on the chip).
- 6.3 When the filter is active and the selection changes such that zero files would be visible, the filter MUST auto-deactivate and show a brief status message explaining why.

### 7. Remove Files from List

- 7.1 Users MUST be able to remove selected files from the loaded list without deleting them from disk.
- 7.2 The action MUST be accessible via a keyboard shortcut (Delete key).
- 7.3 The action MUST be accessible via the column header context menu ("Remove Selected from List").
- 7.4 If removed files had unsaved changes, the user MUST be warned before removal.
- 7.5 The status bar file count MUST update immediately after removal.
