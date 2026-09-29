# UX/UI Review Findings

## Summary

The app has a solid foundation with PRD 00 (TagLib FFI), PRD 01 (Folder Loading & File Display), and PRD 04 (Online Metadata Lookup) fully implemented. PRD 02 (File Renaming) and PRD 03 (Tags from Filename) are now fully implemented. Several UX gaps identified in this review have also been addressed. Below is the updated status.

---

## Status of PRD 02: File Renaming via Mask — ✅ DONE

Fully reimplemented with a token-based mask engine. All core features are complete:
- ✅ Full-path masks with folder creation
- ✅ Mask Editor dialog with variable insertion
- ✅ Saved mask presets (user-defined + built-in)
- ✅ Conflict handling UI (skip/overwrite/auto-increment)
- ✅ Case transformation options (lowercase, UPPERCASE, Capitalize First, sentence case, replace underscores)
- ✅ Undo support via UndoRedoManager
- ✅ Path length validation (FilenameSanitizer)
- ✅ Dry-run validation
- ✅ Conflict highlighting in preview

Only optional tests remain unwritten (marked `*` in spec).

---

## Status of PRD 03: Tags from Filename — ✅ DONE

Fully implemented with MaskExtractor, PathScopeResolver, value transformation pipeline, WriteTagsCommand (with undo), ExtractorStateNotifier, and the ExtractorDialog UI with preview panel.

Only optional tests remain unwritten (marked `*` in spec).

---

## UX/UI Issues Identified (New PRDs)

### P1 — Critical User Impact

#### PRD 06: Album Art Management (P1) — ✅ DONE

Fully implemented:
- ✅ Add button writes album art via FFI (writeAlbumArt with complex property attributes)
- ✅ Remove button with confirmation for multi-file
- ✅ Batch album art operations (apply/remove across multiple selected files)
- ✅ Drag-and-drop of images onto the art panel (desktop_drop)
- ✅ Paste from clipboard support (Ctrl+V)
- ✅ Undo/redo support (AlbumArtCommand)
- ✅ Image preview modal with zoom/pan
- ✅ Batch progress overlay
- ✅ Mixed art detection (shared/mixed/none states)
- ✅ Size warning for images > 5 MB

Only optional tests remain unwritten (marked `*` in spec).

---

#### PRD 07: Unsaved Changes Protection (P1) — ⚠️ PARTIALLY DONE

- ✅ "Confirm before saving" setting is now wired and functional (via Settings Completeness spec)
- ❌ No "are you sure?" prompt when closing the app with unsaved modifications
- ❌ No "are you sure?" prompt when loading a new folder with unsaved modifications
- ❌ No visual indicator on the window title showing unsaved state (e.g., `* Open Tag Editor`)

The confirmation dialog gates the *save* action, but there's no protection against *losing* unsaved edits on close/folder-switch.

---

### P2 — Significant User Impact

#### PRD 08: Column Resize (P2) — ✅ DONE

Fully implemented:
- ✅ Drag-to-resize on column header borders
- ✅ Double-click to auto-fit column width
- ✅ Column widths persist across sessions
- ✅ Minimum width constraint (40px)
- ✅ Context menu with "Reset Column Widths"
- ✅ Tag indicator column excluded from resize

Only optional tests remain unwritten (marked `*` in spec).

---

#### PRD 09: Inline Cell Editing (P2) — ✅ DONE

Fully implemented:
- ✅ Double-click a cell to enter edit mode
- ✅ Tab/Shift+Tab to navigate between editable cells
- ✅ Enter to confirm (+ navigate down), Escape to cancel
- ✅ Multi-select + inline edit applies to all selected rows (batch with confirmation dialog)
- ✅ Changes register with undo system
- ✅ F2 to start editing, printable character to start with that character
- ✅ Read-only columns protected (filename, bitrate, duration, relativePath, tagIndicator)
- ✅ Modified cell indicator (corner triangle)
- ✅ Row selection guard (must select row before editing)
- ✅ Marquee (rubber-band) drag selection
- ✅ Full Ctrl/Shift/Ctrl+Shift multi-selection with keyboard support

Only optional tests remain unwritten (marked `*` in spec).

---

#### PRD 10: Keyboard Navigation (P2) — ✅ DONE (via Cell Edit Row Selection Guard spec)

Implemented as part of the inline editing and selection guard work:
- ✅ Arrow keys to move selection up/down
- ✅ Shift+Arrow to extend selection
- ✅ Ctrl+Shift+Home/End to extend to start/end
- ✅ Ctrl+A to select all
- ✅ F2 to start inline editing

---

### P3 — Moderate User Impact

#### PRD 11: Settings Persistence & Completeness (P3) — ✅ DONE

Fully implemented:
- ✅ "Confirm before saving" — wired to GeneralSettingsNotifier
- ✅ "Default ID3v2 version" — wired to TagWritingSettingsNotifier
- ✅ "Write ID3v1 tags" — wired to TagWritingSettingsNotifier
- ✅ "Default encoding" — wired to TagWritingSettingsNotifier (with v2.3+UTF-8 fallback)
- ✅ "Default rename pattern" — wired to RenamingSettingsNotifier
- ✅ "Preview before renaming" — wired to RenamingSettingsNotifier
- ✅ TagWriteOptions integrated into TagLibWriterService
- ✅ Confirmation dialog gates save action

Only optional tests remain unwritten (marked `*` in spec).

---

#### PRD 12: Error Handling & User Feedback (P3) — ❌ NOT STARTED

- No toast/snackbar system for transient messages (only the status bar, which is easy to miss)
- No error log or history panel for reviewing past failures
- Tag write failures show a snackbar but don't tell the user *which* files failed or *why*
- No "retry failed" action after batch operations
- Loading errors (corrupt files) are silently swallowed into empty-tag entries with no user notification

---

#### PRD 13: Empty State & Onboarding (P3) — ❌ NOT STARTED

- The empty state ("Drop files or folders here or use the toolbar to open") is minimal
- No first-run guidance or feature discovery
- No indication of supported formats
- No link to settings for configuring fpcalc/Discogs tokens on first use
- The tag edit panel shows "Select one or more files to edit tags" but doesn't guide new users to load files first

---

### P4 — Nice to Have

#### PRD 14: Window State Persistence (P4) — ✅ DONE

Fully implemented:
- ✅ Window size and position persist across sessions
- ✅ Tag editor panel open/closed state persists
- ✅ Panel width is adjustable via resizable splitter and persisted
- ✅ Splitter between file list and tag panel (ResizableSplitter widget)
- ✅ Last folder reopening (with setting toggle)
- ✅ Off-screen/display-bounds clamping on restore

Only optional tests remain unwritten (marked `*` in spec).

---

#### PRD 15: Accessibility & Theming (P4) — ❌ NOT STARTED

- No high-contrast theme option
- Font size is hardcoded (11-13px throughout) with no user scaling
- Toolbar buttons rely solely on icons with tooltips — no text label option
- Focus indicators are default Material (may not be visible enough in dense grid)
- Screen reader semantics not explicitly set on custom widgets (data grid rows, tag indicator)

---

#### PRD 16: Drag-and-Drop Enhancements (P4) — ❌ NOT STARTED

- Column reorder via drag is defined in the spec but the `ColumnHeaders` widget uses `GestureDetector` without actual drag-and-drop implementation (only click-to-sort and right-click menu)
- No drag-and-drop reorder for track matching in the lookup dialog (spec says "manual reordering via drag-and-drop" but implementation uses a simple list)
- No drag of files between folders (out of scope but worth noting)

---

## Recommendations (Updated)

### Remaining work worth tackling next

1. **PRD 07: Unsaved Changes Protection (remaining)** — The "confirm before saving" piece is done, but the app still doesn't warn on close/folder-switch with dirty state. This is the last P1 gap and relatively small scope: a dirty-state tracker + two guard dialogs + optional window title indicator.

2. **PRD 12: Error Handling & User Feedback** — Now that all the core editing features are in place (inline editing, album art, renaming, extraction), users will hit errors more often. A proper toast/notification system and per-file error reporting would significantly improve the experience.

3. **PRD 13: Empty State & Onboarding** — Low effort, high polish. A better empty state with format info and settings links would help first-time users.

4. **PRD 15: Accessibility & Theming** — Important for broader adoption but can be incremental.

5. **PRD 16: Drag-and-Drop Enhancements** — Nice-to-have polish, lowest priority.
