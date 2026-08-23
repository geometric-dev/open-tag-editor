# Requirements Document

## Introduction

This PRD captures a comprehensive set of improvements to the Open Tag Editor's data grid, identified through deep architectural analysis. The improvements span three categories: rendering performance (reducing widget allocations and unnecessary rebuilds), usability (adding expected desktop-app interactions), and smarter tag tooling (proactive detection and quick-fix resolution of tag issues). Each requirement is assigned a priority from P1 (critical, high impact-to-effort) to P5 (nice-to-have, low urgency).

## Glossary

- **Data_Grid**: The main table widget displaying audio file metadata in rows and columns, using `ListView.builder` with fixed item extent for virtualized rendering.
- **Editable_Cell**: A cell that supports inline editing, smart fill, and validation indicators.
- **Smart_Fill_Menu**: The existing dropdown that offers fill options from unique column values.
- **Tag_Consistency_Issue**: A detected inconsistency across files in a column (e.g., near-duplicate values, mixed case, trailing whitespace).
- **Quick_Fix**: An actionable one-click resolution for a detected validation issue or consistency problem.
- **Column_Values_Cache**: A memoized provider that caches unique values per column, invalidated on file list changes.
- **Batch_Transform**: A column-wide operation that applies a text transformation (case change, trim, find/replace) to all or selected files.
- **Auto_Number**: An operation that assigns sequential track/disc numbers based on current sort order or filename parsing.
- **Fill_Handle**: A draggable affordance at the corner of a cell that fills adjacent cells with a value or sequence.

---

## Performance

### Requirement 1: Reduce Per-Cell Widget Depth (P3)

**User Story:** As a user, I want the grid to remain smooth when scrolling through 500+ files, so that the app feels native-fast regardless of library size.

#### Acceptance Criteria

1. EACH `EditableCell` SHALL reduce its widget subtree depth by combining the `MouseRegion`, `GestureDetector`, and outer `Container` into a single composite widget where possible.
2. THE `ListView.builder` SHALL be configured with `addAutomaticKeepAlives: false` since rows are cheap to rebuild with fixed item extent.
3. WHEN scrolling through 1000 rows, THE frame budget SHALL NOT exceed 16ms on a mid-range desktop (measured via Flutter DevTools timeline).

### Requirement 2: Consolidate Cell-Level Provider Subscriptions (P2)

**User Story:** As a user, I want editing one cell to not cause unrelated cells to rebuild, so that typing feels instant even with many visible rows.

#### Acceptance Criteria

1. `EditableCell` SHALL NOT independently watch `inlineCellEditProvider`. Instead, the parent `_DataRow` SHALL pass `isEditing` and `isFocused` booleans as constructor parameters.
2. THE total number of Riverpod subscriptions to `inlineCellEditProvider` SHALL equal the number of visible rows (not rows × columns).
3. WHEN entering edit mode on a cell, ONLY the affected row SHALL rebuild — no other rows SHALL be marked dirty.

### Requirement 3: Cache Column Values for Smart Fill (P2)

**User Story:** As a user, I want the smart fill menu to open instantly, so that I don't experience a delay when clicking the fill arrow on large file sets.

#### Acceptance Criteria

1. A `columnValuesProvider.family(columnId)` SHALL memoize the unique values for each column, recomputing only when `fileListProvider` changes.
2. WHEN the Smart_Fill_Menu opens, IT SHALL read from the cached provider rather than iterating all files synchronously.
3. FOR a file list of 2000 files, THE Smart_Fill_Menu SHALL open within 50ms of the fill arrow click.

### Requirement 4: Debounce Filter Input (P3)

**User Story:** As a user, I want to type quickly in the filter bar without the grid stuttering, so that filtering feels responsive.

#### Acceptance Criteria

1. THE filter bar SHALL debounce input by 150ms before updating `fileFilterProvider`.
2. WHILE the user is typing, THE Data_Grid SHALL NOT rebuild on every keystroke.
3. WHEN the user clears the filter (click X or select-all + delete), THE filter SHALL apply immediately without debounce.

### Requirement 5: Limit Auto-Fit Measurement (P4)

**User Story:** As a user, I want double-click auto-fit on column headers to respond quickly even with thousands of files loaded.

#### Acceptance Criteria

1. THE auto-fit measurement SHALL sample at most 200 files (first 100 + last 100) rather than measuring all files.
2. THE auto-fit result SHALL still produce a visually correct width for typical datasets.
3. FOR a file list of 5000 files, THE auto-fit operation SHALL complete within 100ms.

---

## Usability

### Requirement 6: Copy/Paste Support (P1)

**User Story:** As a user, I want to copy and paste cell values using standard keyboard shortcuts, so that I can transfer data between the grid and external applications.

#### Acceptance Criteria

1. WHEN a cell is focused (not editing) and the user presses Ctrl+C, THE grid SHALL copy that cell's text value to the system clipboard.
2. WHEN multiple rows are selected and the user presses Ctrl+C, THE grid SHALL copy the focused column's values for all selected rows as newline-separated text.
3. WHEN a cell is focused and the user presses Ctrl+V, THE grid SHALL paste the clipboard text into that cell's column for all selected rows (or just the focused row if only one is selected).
4. WHEN the clipboard contains multiple lines and multiple rows are selected, THE grid SHALL paste line-by-line into consecutive selected rows (one line per row).
5. WHEN pasting, THE operation SHALL be registered as a single undoable command.
6. WHEN a cell is in edit mode, Ctrl+C and Ctrl+V SHALL behave as standard text field copy/paste (not grid-level).

### Requirement 7: Batch "Set Column Value" from Header (P1)

**User Story:** As a user, I want to set a column's value for all selected files from the column header, so that I can batch-edit without hunting for a specific cell.

#### Acceptance Criteria

1. THE column header right-click context menu SHALL include a "Set value..." option for editable columns.
2. WHEN the user selects "Set value...", A dialog SHALL appear with a text field pre-populated with the most common value in that column among selected files (or all files if none selected).
3. WHEN the user confirms the dialog, THE value SHALL be applied to all selected files (or all files if none selected) as a single undoable command.
4. THE dialog SHALL show a count of how many files will be affected (e.g., "Apply to 12 files").
5. THE dialog SHALL include the `ValidationIndicator` showing any issues with the entered value.

### Requirement 8: Auto-Numbering (P1)

**User Story:** As a user, I want to automatically number tracks based on their current order, so that I don't have to manually type sequential numbers.

#### Acceptance Criteria

1. THE column header right-click menu for `trackNumber` and `discNumber` columns SHALL include an "Auto-number..." option.
2. WHEN selected, A dialog SHALL offer numbering modes: "By current order" (1, 2, 3...), "From filename" (extract leading digits), and "Custom start" (user-specified start number).
3. THE "By current order" mode SHALL number files sequentially based on their current display order in the grid (respecting sort and filter).
4. THE "From filename" mode SHALL extract the first numeric sequence from each filename (e.g., "03 - Song.mp3" → "3").
5. THE auto-number operation SHALL apply to selected files only (or all files if none selected) and register as a single undoable command.
6. THE dialog SHALL show a preview of the first 5 assignments before the user confirms.

### Requirement 9: Undo Feedback (P2)

**User Story:** As a user, I want visual confirmation when I undo or redo an action, so that I know what was reversed.

#### Acceptance Criteria

1. WHEN the user performs an undo (Ctrl+Z), A brief snackbar/toast SHALL appear showing the command description (e.g., "Undid: Set artist to 'Radiohead' (5 files)").
2. WHEN the user performs a redo (Ctrl+Y), A brief snackbar/toast SHALL appear showing the command description (e.g., "Redid: Set artist to 'Radiohead' (5 files)").
3. THE snackbar SHALL auto-dismiss after 3 seconds and SHALL NOT block interaction.
4. THE snackbar SHALL appear at the bottom of the grid area, not overlapping the status bar.

### Requirement 10: Per-Column Filtering (P3)

**User Story:** As a user, I want to filter by a specific column's value, so that I can quickly find files with empty or specific tag values.

#### Acceptance Criteria

1. THE column header right-click menu SHALL include a "Filter..." submenu with options: "Show empty only", "Show non-empty only", and "Filter by value...".
2. "Show empty only" SHALL filter the grid to show only files where that column's value is empty/blank.
3. "Show non-empty only" SHALL filter the grid to show only files where that column has a non-empty value.
4. "Filter by value..." SHALL open a small popup with a text field that filters files where that column contains the entered text (case-insensitive substring match).
5. WHEN a column filter is active, THE column header SHALL display a filter icon indicator.
6. Column filters SHALL be combinable with the existing global text filter.
7. A "Clear all filters" action SHALL be available in the toolbar or filter bar.

### Requirement 11: Multi-Cell Paste from Spreadsheet (P3)

**User Story:** As a user, I want to paste a block of tab-separated data from a spreadsheet into multiple columns and rows, so that I can bulk-import tag data from external sources.

#### Acceptance Criteria

1. WHEN the clipboard contains tab-separated values (TSV) and the user presses Ctrl+V with a cell focused, THE grid SHALL paste values into consecutive columns starting from the focused column.
2. WHEN the clipboard contains multiple lines of TSV data, THE grid SHALL paste into consecutive rows starting from the focused row.
3. THE paste SHALL skip read-only columns (filename, bitrate, duration) and advance to the next editable column.
4. THE entire paste operation SHALL be registered as a single undoable command.
5. IF the paste data exceeds the available rows or columns, THE grid SHALL paste only what fits and ignore the overflow.

### Requirement 12: Drag-Fill Handle (P4)

**User Story:** As a user, I want to drag a cell's value down to fill adjacent cells, so that I can quickly repeat or sequence values like in a spreadsheet.

#### Acceptance Criteria

1. WHEN a cell is focused, A small square handle SHALL appear at the bottom-right corner of the cell.
2. WHEN the user drags the handle downward, THE grid SHALL fill the dragged-over cells with the source cell's value.
3. FOR numeric columns (trackNumber, discNumber, bpm), THE fill SHALL auto-increment by 1 for each subsequent row.
4. THE drag-fill operation SHALL register as a single undoable command.
5. THE drag-fill handle SHALL only appear on editable columns.

### Requirement 13: Modified Row Gutter Indicator (P4)

**User Story:** As a user, I want to see at a glance which rows have unsaved changes, so that I can identify what needs saving without scanning every cell.

#### Acceptance Criteria

1. THE tag indicator column (first column) SHALL display a distinct "modified" icon or colour when any tag in that row has been changed from its original value.
2. THE modified indicator SHALL be visually distinct from the "has tags" / "no tags" indicators.
3. WHEN a row's changes are saved or undone, THE modified indicator SHALL disappear immediately.
4. THE status bar SHALL continue to show the total count of modified files.

---

## Smart Tag Tooling

### Requirement 14: Tag Consistency Checker (P1)

**User Story:** As a user, I want the app to detect inconsistencies in my tags (near-duplicates, whitespace issues, mixed case), so that I can fix them before saving.

#### Acceptance Criteria

1. A `tagConsistencyProvider` SHALL analyse all loaded files and produce a list of `TagConsistencyIssue` objects grouped by column.
2. THE checker SHALL detect: trailing/leading whitespace, near-duplicate values (Levenshtein distance ≤ 2 for values > 4 chars), and mixed-case variants of the same logical value.
3. WHEN consistency issues are detected for a column, THE column header SHALL display a small warning badge with the issue count.
4. WHEN the user clicks the warning badge, A popup or panel SHALL list the detected issues with "Fix" actions.
5. THE consistency check SHALL run asynchronously after file loading completes and after batch edits, without blocking the UI.
6. EACH fix action SHALL be registered as an undoable command.

### Requirement 15: Quick-Fix Actions on Validation Issues (P2)

**User Story:** As a user, I want one-click fixes for validation problems detected in my tag values, so that I can resolve issues without manually retyping.

#### Acceptance Criteria

1. WHEN a cell has a validation issue (from `TagFieldValidator`), THE cell SHALL display a clickable indicator (lightbulb or wrench icon) in addition to the existing warning/error icon.
2. WHEN the user clicks the quick-fix indicator, A popup menu SHALL offer context-appropriate fixes:
   - Truncation warning → "Truncate to N characters"
   - Non-Latin-1 characters → "Transliterate to ASCII"
   - Non-numeric in numeric field → "Extract number" (e.g., "Track 03" → "3")
   - Exceeds max length → "Truncate to 10,000 characters"
3. WHEN the user selects a fix, THE fix SHALL be applied as an undoable command.
4. THE quick-fix menu SHALL only appear for cells with actionable issues (not all warnings need fixes).

### Requirement 16: Batch Transform Operations (P2)

**User Story:** As a user, I want to apply text transformations to an entire column (case conversion, trim, find/replace), so that I can clean up tags in bulk.

#### Acceptance Criteria

1. THE column header right-click menu SHALL include a "Transform..." submenu for editable columns.
2. THE submenu SHALL offer: "Title Case", "UPPERCASE", "lowercase", "Trim whitespace", "Find & Replace...", and "Strip leading zeros" (for numeric columns).
3. "Title Case" SHALL capitalize the first letter of each word (space/hyphen-delimited).
4. "Trim whitespace" SHALL remove leading and trailing whitespace from all target cells.
5. "Find & Replace..." SHALL open a dialog with find/replace text fields and a "Use regex" checkbox.
6. ALL transforms SHALL apply to selected files (or all if none selected) and register as a single undoable command.
7. THE dialog (for Find & Replace) SHALL show a preview count of matches before applying.

### Requirement 17: Tag Completeness Indicator (P3)

**User Story:** As a user, I want to see which files are missing important tags, so that I can prioritise which files need attention.

#### Acceptance Criteria

1. THE tag indicator column SHALL optionally show a completeness state: "complete" (all core fields filled), "partial" (some core fields empty), "empty" (no tags at all).
2. Core fields for completeness SHALL be configurable in settings, defaulting to: title, artist, album, trackNumber, year.
3. THE column header for the tag indicator SHALL show a summary tooltip: "X of Y files have complete tags".
4. A toolbar filter option SHALL allow showing only "incomplete" files (files missing any core field).

### Requirement 18: Filename-to-Tag Parser (P2)

**User Story:** As a user, I want to extract tag values from filenames using a pattern, so that I can populate tags for files that have meaningful filenames but empty tags.

#### Acceptance Criteria

1. A toolbar action "Tags from Filename..." SHALL open a dialog with a pattern editor.
2. THE pattern editor SHALL support placeholders: `{trackNumber}`, `{title}`, `{artist}`, `{album}`, `{year}`, and literal text/separators.
3. THE dialog SHALL show a live preview of extracted values for the first 5 files.
4. WHEN the user confirms, THE extracted values SHALL be applied to all selected files (or all if none selected) as a single undoable command.
5. THE parser SHALL handle common patterns: `{trackNumber} - {title}`, `{artist} - {title}`, `{trackNumber}. {title}`, and custom user-defined patterns.
6. IF a placeholder cannot be matched for a file (pattern doesn't fit the filename), THAT file SHALL be skipped with no change.

### Requirement 19: Smart Suggestions During Editing (P4)

**User Story:** As a user, I want autocomplete suggestions while typing in a cell, so that I can quickly select existing values without typing the full text.

#### Acceptance Criteria

1. WHEN the user is typing in an editable cell, AN autocomplete dropdown SHALL appear below the cell showing matching values from the same column (case-insensitive prefix match).
2. THE suggestions SHALL be sourced from the Column_Values_Cache (all unique values in that column).
3. THE user SHALL be able to select a suggestion with arrow keys + Enter, or by clicking.
4. THE autocomplete SHALL dismiss when the user presses Escape, clicks outside, or when no matches remain.
5. THE autocomplete SHALL NOT appear if the column has fewer than 2 unique values.
6. THE autocomplete dropdown SHALL show at most 8 suggestions at a time, scrollable if more match.

### Requirement 20: Consistency Fix — Normalize Near-Duplicates (P3)

**User Story:** As a user, I want to merge near-duplicate values into a single canonical value, so that my tags are consistent across all files.

#### Acceptance Criteria

1. WHEN the Tag_Consistency_Checker detects near-duplicate values (e.g., "Radiohead" vs "Radiohed"), THE fix popup SHALL offer "Normalize all to '{most common value}'" as a one-click action.
2. THE normalization SHALL replace all variant values with the most frequently occurring variant.
3. IF two variants have equal frequency, THE normalization SHALL prefer the longer value (assumed to be more complete).
4. THE normalization SHALL apply to all files containing any variant and register as a single undoable command.
5. THE user SHALL be able to choose which variant to normalize to (not just the most common) via a selection in the fix popup.

---

## Priority Summary

| Priority | Requirements | Theme |
|----------|-------------|-------|
| P1 | 6, 7, 8, 14 | Core usability gaps and proactive tag quality |
| P2 | 2, 3, 9, 15, 16, 18 | Performance foundations and smart fixes |
| P3 | 1, 4, 10, 11, 17, 20 | Polish and advanced filtering |
| P4 | 5, 12, 13, 19 | Nice-to-have refinements |
| P5 | (none currently) | Future considerations |
