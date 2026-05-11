# PRD 10: Keyboard Navigation (P2)

## Problem Statement

The data grid supports Ctrl+A (select all) and modifier-click for selection, but lacks keyboard-driven row navigation. Users working through large file lists need arrow keys, page navigation, and keyboard-triggered actions to maintain flow without reaching for the mouse.

## Goals

- Provide full keyboard navigation within the data grid.
- Support keyboard-driven selection (Shift+Arrow for range select).
- Enable keyboard shortcuts for common actions on the current selection.

## Functional Requirements

### Row Navigation
- Up/Down arrow keys move the focused row (and selection) up/down by one.
- Home jumps to the first row; End jumps to the last row.
- Page Up/Page Down scroll by one visible page and move focus accordingly.
- The focused row is always scrolled into view.

### Keyboard Selection
- Shift+Up/Down extends the selection range from the anchor.
- Shift+Home/End extends selection to the first/last row.
- Shift+Page Up/Down extends selection by one page.
- Ctrl+Up/Down moves focus without changing selection (allows non-contiguous selection setup).
- Ctrl+Space toggles selection of the focused row (like Ctrl+Click).

### Action Shortcuts
- Enter opens the tag edit panel for the focused file (or toggles it).
- Delete clears all tag fields for selected files (with confirmation if >1 file).
- F2 enters inline edit mode on the focused cell (if PRD 09 is implemented).
- F5 refreshes/reloads tags from disk for selected files.

### Focus Indicator
- The focused row has a distinct visual indicator (e.g., a subtle border or different highlight shade) separate from the selection highlight.
- Focus is visible even when the row is not selected (Ctrl+Arrow scenario).

## Non-Functional Requirements

- Key repeat rate should feel native (no custom debouncing that makes navigation sluggish).
- Scrolling to keep focus visible must not cause layout jumps.

## Dependencies

- PRD 01 (Folder Loading & File Display) — extends the `DataGrid` widget and `SelectionNotifier`.

## Out of Scope

- Vim-style keybindings or custom key mapping.
- Keyboard navigation within the tag edit panel (standard Flutter focus traversal handles this).
