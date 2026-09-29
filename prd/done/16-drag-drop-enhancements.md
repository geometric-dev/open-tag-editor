# PRD 16: Drag-and-Drop Enhancements (P4)

## Status: mostly shipped

Already delivered before this review: file/folder drop onto the window with an
unsaved-changes guard and drag feedback, image drop onto the album-art panel
with validation, and menu-based column reordering.

Added here:

- **Drag-to-reorder column headers.** Long-press a header to pick it up; an
  insertion line shows the gap it will land in rather than snapping to
  whichever header is hovered, and the drop converts that gap into a
  post-removal index before calling the notifier.
- The fixed columns (the tag indicator and the filename) are not draggable at
  all, rather than being draggable and silently rejected on drop. Nothing may
  be dropped before the first column.

Not delivered, and why:

- **Drag-reorder of lookup match rows.** The panel uses a popup menu to
  reassign a track, which is a clearer affordance for a list of matches than
  dragging, and the list is short.
- **Manual file-list reordering in the unsorted state.** The list always has
  an explicit sort, and a manual order field that silently does nothing while
  a sort is active would be worse than not having one.
- **Invalid-drop "not allowed" affordance and drop animations.** The drop
  zones that matter (the window and the album-art panel) already have
  feedback; the header reorder is constrained, not invalid-dropping.

## Problem Statement

Several features specify drag-and-drop interactions that are not fully implemented: column reorder uses only a context menu (no actual drag), track-to-file matching in the lookup dialog lacks drag reorder, and there's no drag-based file reorder for manual sorting.

## Goals

- Implement drag-and-drop column reorder in the data grid headers.
- Implement drag-and-drop track reorder in the lookup match panel.
- Polish drag interactions with proper visual feedback.

## Functional Requirements

### Column Header Drag Reorder
- Users can drag a column header to a new position.
- A visual insertion indicator shows where the column will land.
- The Tag Indicator column cannot be dragged or displaced from position 0.
- Column order persists via the existing `ColumnConfigNotifier`.

### Lookup Track Reorder
- In the match panel, users can drag file-to-track pairings to manually adjust the mapping.
- Drag handle on each row for clear affordance.
- Updated mapping is reflected in the apply preview.

### Drag Visual Feedback
- Dragged items show a semi-transparent ghost of the dragged element.
- Valid drop targets highlight; invalid targets show a "not allowed" indicator.
- Smooth animation when items reorder.

### File List Drag (Manual Sort)
- When no sort column is active (unsorted state), users can drag rows to manually reorder files.
- Manual order is used for track number assignment or rename ordering.
- This is disabled when a sort column is active (sorted state overrides manual order).

## Non-Functional Requirements

- Drag interactions must feel responsive (<16ms frame time during drag).
- Drop animations complete within 200ms.

## Dependencies

- PRD 01 (Folder Loading & File Display) — extends column headers and data grid.
- PRD 04 (Online Metadata Lookup) — extends the match panel.

## Out of Scope

- Drag files to external applications (e.g., drag to file explorer).
- Drag between multiple app windows.
