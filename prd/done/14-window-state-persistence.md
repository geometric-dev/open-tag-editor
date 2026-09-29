# PRD 14: Window State Persistence (P4)

## Problem Statement

The app doesn't remember its window size, position, or internal layout state between sessions. Users must re-open the tag panel and re-arrange their workspace every time they launch the app.

## Goals

- Persist window geometry and internal layout state across sessions.
- Restore the user's preferred workspace layout on startup.

## Functional Requirements

### Window Geometry
- Save window size (width, height) and position (x, y) on close.
- Restore on next launch. If the saved position is off-screen (monitor disconnected), fall back to centered on primary display.

### Tag Panel State
- Persist whether the tag panel is open or closed.
- Persist the tag panel width (requires making it resizable first — see splitter below).

### Resizable Splitter
- Replace the fixed 380px tag panel width with a draggable splitter between the file list and tag panel.
- Minimum panel width: 280px. Maximum: 50% of window width.
- Splitter position persists across sessions.

### Last Loaded Folder
- Optionally (setting: "Reopen last folder on startup"), reload the most recent folder on app launch.
- Default: off (to avoid unexpected long loads).

## Non-Functional Requirements

- State save must not delay app close (async write to preferences).
- Restore must complete before the first frame is painted (no visible layout jump).

## Dependencies

- Requires `window_manager` or similar package for window geometry control on desktop.

## Out of Scope

- Multiple window support.
- Workspace profiles (save/restore named layouts).
