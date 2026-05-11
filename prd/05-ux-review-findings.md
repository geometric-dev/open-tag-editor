# UX/UI Review Findings

## Summary

The app has a solid foundation with PRD 00 (TagLib FFI), PRD 01 (Folder Loading & File Display), and PRD 04 (Online Metadata Lookup) fully implemented. PRD 02 (File Renaming) has a partial implementation, and PRD 03 (Tags from Filename) is not started. Beyond those, this review identifies several UX gaps that would meaningfully improve the user experience.

---

## Status of PRD 02: File Renaming via Mask

The current implementation covers basic rename-by-pattern with a preset selector, custom pattern input, live preview, and batch execution. However, the following PRD 02 requirements are **not yet implemented**:

### Missing from PRD 02

1. **Full-path masks with folder creation** — The `RenameService` supports subdirectory creation from patterns, but the UI (`RenameDialog`) doesn't expose this clearly or let users build full-path masks (e.g., `D:\Music\%artist\%year - %album\%track - %title`).
2. **Mask Editor helper dialog** — No visual mask builder exists.
3. **Saved mask presets (user-defined)** — Only built-in presets exist; users cannot save/name/recall custom masks.
4. **Conflict handling UI** — The service throws `RenameConflictException` but the dialog doesn't offer skip/overwrite/auto-increment options to the user.
5. **Case transformation options** — No UI for replace-underscores, lowercase, UPPERCASE, Capitalize First Letter, sentence case.
6. **Undo support** — Rename operations are not registered with the `UndoRedoManager`.
7. **Path length validation** — No check for OS path length limits.
8. **Warning when target is outside loaded folder** — Not implemented.
9. **Dry-run validation** — No pre-execution validation pass.
10. **Conflict highlighting in preview** — Duplicate target filenames are not flagged in the preview list.

---

## Status of PRD 03: Tags from Filename

**Not implemented.** No UI, service, or model exists for parsing filenames/paths into tag fields. This is a completely new feature to build.

---

## UX/UI Issues Identified (New PRDs)

### P1 — Critical User Impact

#### PRD 06: Album Art Management (P1)

The Album Art tab in the Tag Edit Panel has placeholder TODOs for core functionality:
- "Add" button opens a file picker but doesn't write the art to the file (`// TODO: Write album art to file via service`)
- "Remove" button is wired but does nothing (`// TODO: Remove album art`)
- No batch album art operations (apply same art to multiple selected files)
- No drag-and-drop of images onto the art panel
- No paste from clipboard support

This is P1 because album art management is a core workflow for any tag editor and the UI suggests it works but doesn't.

---

#### PRD 07: Unsaved Changes Protection (P1)

- No "are you sure?" prompt when closing the app with unsaved modifications
- No "are you sure?" prompt when loading a new folder with unsaved modifications
- The "Confirm before saving" setting in Settings is a TODO (`// TODO: Implement setting`)
- No visual indicator on the window title showing unsaved state (e.g., `* Open Tag Editor`)

This is P1 because users can silently lose work.

---

### P2 — Significant User Impact

#### PRD 08: Column Resize (P2)

Columns use fixed `defaultWidth` values and cannot be resized by the user. For a data-heavy grid with 17 possible columns, this is a significant usability gap:
- Long values (paths, titles) get truncated with no way to see them
- Short columns (Track #, Disc #) waste space
- No drag-to-resize on column header borders
- Column widths should persist across sessions

---

#### PRD 09: Inline Cell Editing (P2)

Currently, editing tags requires the side panel. Users of tag editors (Mp3tag, Tag&Rename) expect to double-click a cell in the grid and edit inline:
- Double-click a cell to enter edit mode
- Tab to move to next cell
- Enter to confirm, Escape to cancel
- Multi-select + inline edit applies to all selected rows (batch)
- Changes register with undo system

---

#### PRD 10: Keyboard Navigation (P2)

The data grid lacks keyboard navigation:
- Arrow keys to move selection up/down
- Home/End to jump to first/last file
- Page Up/Page Down for scrolling
- Enter to open tag panel for selected file
- Delete to clear selected tag fields
- F2 to start inline editing (if PRD 09 is implemented)

---

### P3 — Moderate User Impact

#### PRD 11: Settings Persistence & Completeness (P3)

Several settings are stubbed with TODOs:
- "Confirm before saving" — not implemented
- "Default ID3v2 version" — not implemented
- "Write ID3v1 tags" — not implemented
- "Default encoding" — not implemented
- "Default rename pattern" — not implemented
- "Preview before renaming" — not implemented

The settings page needs a pass to wire all controls to actual persisted preferences.

---

#### PRD 12: Error Handling & User Feedback (P3)

- No toast/snackbar system for transient messages (only the status bar, which is easy to miss)
- No error log or history panel for reviewing past failures
- Tag write failures show a snackbar but don't tell the user *which* files failed or *why*
- No "retry failed" action after batch operations
- Loading errors (corrupt files) are silently swallowed into empty-tag entries with no user notification

---

#### PRD 13: Empty State & Onboarding (P3)

- The empty state ("Drop files or folders here or use the toolbar to open") is minimal
- No first-run guidance or feature discovery
- No indication of supported formats
- No link to settings for configuring fpcalc/Discogs tokens on first use
- The tag edit panel shows "Select one or more files to edit tags" but doesn't guide new users to load files first

---

### P4 — Nice to Have

#### PRD 14: Window State Persistence (P4)

- Tag editor panel open/closed state doesn't persist across sessions
- Panel width (380px fixed) is not adjustable or persisted
- Window size and position don't persist
- Splitter between file list and tag panel would be more flexible than fixed width

---

#### PRD 15: Accessibility & Theming (P4)

- No high-contrast theme option
- Font size is hardcoded (11-13px throughout) with no user scaling
- Toolbar buttons rely solely on icons with tooltips — no text label option
- Focus indicators are default Material (may not be visible enough in dense grid)
- Screen reader semantics not explicitly set on custom widgets (data grid rows, tag indicator)

---

#### PRD 16: Drag-and-Drop Enhancements (P4)

- Column reorder via drag is defined in the spec but the `ColumnHeaders` widget uses `GestureDetector` without actual drag-and-drop implementation (only click-to-sort and right-click menu)
- No drag-and-drop reorder for track matching in the lookup dialog (spec says "manual reordering via drag-and-drop" but implementation uses a simple list)
- No drag of files between folders (out of scope but worth noting)

---

## Recommendations

1. **Immediate focus**: PRD 06 (Album Art) and PRD 07 (Unsaved Changes Protection) — these are broken promises in the current UI.
2. **Complete PRD 02 and 03** as planned — the rename feature is half-done and tags-from-filename is a key differentiator.
3. **Next tier**: PRD 08 (Column Resize) and PRD 09 (Inline Editing) would bring the grid up to parity with established tag editors.
4. **Polish pass**: PRDs 11-16 can be addressed incrementally as the app matures.
