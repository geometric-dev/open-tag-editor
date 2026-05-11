# PRD 08: Column Resize (P2)

## Problem Statement

The data grid uses fixed column widths that cannot be adjusted by the user. Long values (file paths, titles, comments) are truncated with no way to reveal them, while short-value columns (Track #, Disc #) waste horizontal space. Users of desktop data grids expect drag-to-resize column borders.

## Goals

- Allow users to resize columns by dragging the header border.
- Persist custom column widths across sessions.
- Provide a "fit to content" option.

## Functional Requirements

### Drag to Resize
- A draggable handle appears on the right edge of each column header.
- Dragging the handle resizes the column in real-time.
- Minimum column width: 40px. No maximum (constrained by available scroll width).
- The Tag Indicator column has a fixed width and cannot be resized.

### Double-Click to Auto-Fit
- Double-clicking a column header border auto-sizes that column to fit the widest visible cell content (up to a reasonable max of 500px).

### Reset Column Widths
- Right-click context menu on column headers includes "Reset Column Widths" to restore defaults.

### Persistence
- Custom column widths are saved to `shared_preferences` as part of the column configuration.
- On app restart, columns restore to their last user-set widths.

## Non-Functional Requirements

- Resize must be smooth (no jank) even with 500+ rows loaded.
- Cursor should change to a resize cursor when hovering the drag handle.

## Dependencies

- PRD 01 (Folder Loading & File Display) — extends the existing `ColumnConfig` model and `DataGrid` widget.

## Out of Scope

- Column width synchronization across multiple instances.
- Proportional resize (where resizing one column adjusts neighbors).
