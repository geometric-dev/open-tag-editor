# Design: UX Review Fixes (Issues 1–7)

## Overview

Seven targeted fixes to eliminate UX dead-ends and illogical pathways. Each fix is small and self-contained, touching 1–3 files. No new models or services are needed — these are wiring, guard, and minor widget changes.

## Architecture Decisions

### Fix 1: Tags from Filename Toolbar Button

Add a toolbar button in `EditorToolbar` that opens the `ExtractorDialog`. Place it after the existing "Rename Files" button since they're related workflows (both use mask patterns). Disable when `fileListProvider` is empty.

**Files modified:** `toolbar.dart` (add import + button)

### Fix 2: Album Art Button Behaviour

Replace the TODO with logic that:
1. Opens the tag panel if closed (`tagPanelOpenProvider = true`)
2. Switches to the Album Art tab

Since `TagEditPanel` manages its own tab state internally via `_PanelTab _activeTab`, we need to expose a way to set the active tab from outside. Add a `tagPanelActiveTabProvider` StateProvider that `TagEditPanel` watches. The toolbar button sets it to `albumArt`.

**Files modified:** `toolbar.dart`, `tag_edit_panel.dart`, new provider in `editor_state_provider.dart`

### Fix 3: Dismissable Snackbars

Replace `Duration(days: 365)` with `Duration(seconds: 30)` and add `showCloseIcon: true` to all error snackbars. Use `ScaffoldMessenger.of(context).clearSnackBars()` before showing a new error snackbar to prevent stacking.

**Files modified:** `toolbar.dart`, `unsaved_changes_guard.dart`, `rename_dialog.dart`, `notification_service.dart`

### Fix 4: Rename Dialog Guard

Add a `fileListProvider` watch in the toolbar to disable the Rename button when empty. The `renamerStateProvider` already handles the empty-files case gracefully (shows "No files loaded" in preview), so no dialog changes needed.

**Files modified:** `toolbar.dart`

### Fix 5: Online Lookup Guard

Add a `selectedFilesProvider` watch in the toolbar to disable the Lookup button when selection is empty. Update tooltip to explain why.

**Files modified:** `toolbar.dart`

### Fix 6: Show-Selected-Only Safety

1. Add a visible `Chip` widget in `_FilterBar` when the toggle is active, with an X button to clear it.
2. In `filteredSortedFileListProvider`, after applying the show-selected-only filter, if the result is empty and the filter is active, auto-deactivate it. This prevents the "trap" scenario.

**Files modified:** `file_list_panel.dart`, `filtered_sorted_file_list_provider.dart`

### Fix 7: Remove Files from List

1. Add a Delete key handler in `DataGrid._handleKeyEvent` that calls `fileListProvider.notifier.removeFiles()` for selected paths.
2. Add a "Remove Selected from List" item in the column header context menu.
3. Before removal, check if any selected files are modified and show a confirmation dialog if so.

**Files modified:** `data_grid.dart`, `column_headers.dart`, `keyboard_shortcuts.dart`

## Component Interactions

```
Toolbar
  ├── [Tags from Filename] → showDialog(ExtractorDialog)
  ├── [Album Art] → tagPanelOpenProvider=true + tagPanelActiveTabProvider=albumArt
  ├── [Rename] → disabled when fileList.isEmpty
  └── [Online Lookup] → disabled when selectedFiles.isEmpty

FilterBar
  └── Show-Selected-Only chip → visible when active, X clears it

DataGrid
  └── Delete key → removeFiles(selectedPaths) with dirty-check guard

ColumnHeaders context menu
  └── "Remove Selected from List" → same removeFiles logic
```

## No New Models or Services

All fixes use existing providers and state. The only new state is `tagPanelActiveTabProvider` (a simple `StateProvider<int>` or enum).
