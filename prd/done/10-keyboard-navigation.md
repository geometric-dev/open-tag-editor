# PRD 10: Keyboard Navigation (P2)

## Status: shipped

Delivered: row navigation (arrows, Shift-extend, PageUp/PageDown, Home/End,
Ctrl+Shift+Home/End), Ctrl+A, F2 and printable-character inline edit, the
cell focus indicator, scroll-follow, and the app-level action map.

Added after the initial review:

- **Ctrl+Arrow moves focus without changing the selection.** Plain arrows
  collapse the selection to the focused row, so there was previously no way
  to reach a row in order to act on it *outside* the current selection. The
  anchor is deliberately left in place so a later Shift+click still extends
  from where the user expects.
- **Ctrl+Space** toggles the focused row in or out of the selection.
- **F5** re-reads tags from disk. Unlike a folder reload this preserves the
  selection, the undo history and the loaded-folder state, and it *skips*
  files with unsaved edits — a refresh that silently discarded unsaved work
  would be worse than no refresh at all.

Deliberate deviation: the PRD asks for Delete to clear the focused cell's tag
field. Delete instead removes the selected files from the list, behind a
confirmation. Clearing a field is destructive to data, is undoable, and now
has explicit first-class actions from PRD 18 (Clear Fields…, Clear All
Tags…); binding it to an unmodified Delete key with no undo affordance at the
key handler is a footgun. "Remove from list" is also a distinct intent that
Delete serves well.

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
