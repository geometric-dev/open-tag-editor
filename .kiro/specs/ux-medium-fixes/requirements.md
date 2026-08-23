# Requirements: UX Medium Fixes (Issues 8–13)

## Overview

Address six medium-severity UX issues: filter bar rebuild timing, tag panel data loss on selection change, clipboard paste limitations, inappropriate cursor on read-only cells, double-click inconsistency, and lookup dialog navigation confusion.

## Requirements

### 8. Filter Bar Clear Button Rebuild

- 8.1 The filter bar clear (X) button MUST appear immediately when the user types the first character.
- 8.2 The clear button MUST disappear immediately when the text is cleared.

### 9. Tag Panel Field Commit on Focus Loss

- 9.1 When a tag field in the side panel loses focus, the current value MUST be committed (same as pressing Enter).
- 9.2 If the selection changes while a field is focused, the pending edit MUST be committed before syncing to the new selection's values.
- 9.3 Empty fields in multi-file mode MUST NOT overwrite existing values (preserve existing "empty = no change" semantics).

### 10. Clipboard Paste Feedback for Album Art

- 10.1 When Ctrl+V is pressed on the Album Art tab and the clipboard does NOT contain a valid file path to an image, the app MUST show a brief informational message (e.g., "No image found on clipboard").
- 10.2 The message MUST auto-dismiss after 3 seconds.

### 11. Read-Only Cell Cursor

- 11.1 Non-editable cells (filename, duration, bitrate, path) MUST show the default cursor (`SystemMouseCursors.basic`), not the forbidden cursor.
- 11.2 Editable cells MUST continue to show the text cursor (`SystemMouseCursors.text`).

### 12. Double-Click Consistency

- 12.1 Double-clicking an editable cell MUST enter inline edit mode (existing behaviour, unchanged).
- 12.2 Double-clicking a non-editable cell MUST open the tag panel (same as double-clicking the row background).
- 12.3 The behaviour MUST be consistent regardless of whether the row is already selected.

### 13. Lookup Dialog Back Navigation

- 13.1 Pressing "Back" from the apply panel MUST return the user to the track listing (match panel), not to search results.
- 13.2 Pressing "Back" from the match panel MUST return the user to the search results.
- 13.3 The navigation MUST be predictable — each "Back" goes exactly one step back in the wizard flow.
