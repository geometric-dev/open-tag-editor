# PRD 09: Inline Cell Editing (P2)

## Problem Statement

Editing tags currently requires the side panel, which is a two-step workflow (select file → edit in panel). Power users of tag editors (Mp3tag, Tag&Rename, MusicBee) expect to click directly into a grid cell and edit in place, especially for quick corrections across many files.

## Goals

- Enable direct inline editing of tag values in the data grid.
- Support batch inline editing (edit one cell, apply to all selected rows).
- Integrate with the existing undo/redo system.

## Functional Requirements

### Enter Edit Mode
- Double-click a cell to enter inline edit mode (text field appears in the cell).
- F2 key enters edit mode on the focused cell.
- Typing any character on a focused cell enters edit mode with that character.

### Navigation While Editing
- Tab moves to the next editable cell in the row.
- Shift+Tab moves to the previous editable cell.
- Enter confirms the edit and moves down one row (same column).
- Escape cancels the edit and restores the original value.
- Clicking outside the cell confirms the edit.

### Batch Editing
- When multiple rows are selected and the user edits a cell, a prompt asks: "Apply to all X selected files?" with Yes / No / Cancel.
- Alternatively, a modifier (e.g., Ctrl+Enter) applies the edit to all selected rows without prompting.

### Non-Editable Cells
- Tag Indicator, Filename, Bitrate, Duration, and Relative Path columns are read-only (not editable inline).
- Read-only cells show a "not editable" cursor or tooltip on double-click.

### Undo Integration
- Each inline edit (or batch edit) registers as a single command with `UndoRedoManager`.
- Undo restores the previous value(s) for all affected files.

### Visual Feedback
- The active edit cell has a visible border/highlight distinguishing it from selection highlight.
- Modified cells show a subtle indicator (e.g., colored corner triangle) until saved.

## Non-Functional Requirements

- Entering and exiting edit mode must feel instant (<50ms).
- Tab navigation between cells must be smooth with no visible flicker.

## Dependencies

- PRD 01 (Folder Loading & File Display) — extends the `DataGrid` widget.
- PRD 08 (Column Resize) — inline editing works better with properly sized columns.

## Out of Scope

- Dropdown/autocomplete for genre or other constrained fields (future enhancement).
- Multi-line editing (comment field could benefit but is out of scope here).
