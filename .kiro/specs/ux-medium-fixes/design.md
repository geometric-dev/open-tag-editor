# Design: UX Medium Fixes (Issues 8–13)

## Overview

Six targeted fixes for medium-severity UX issues. Each is a small, focused change to existing widgets or providers.

## Architecture Decisions

### Fix 8: Filter Bar Rebuild

The `_FilterBarState` widget doesn't call `setState` when the controller text changes — it only updates the provider. The suffix icon visibility check (`_filterController.text.isNotEmpty`) doesn't trigger a rebuild.

**Solution:** Add a listener to `_filterController` in `initState` that calls `setState(() {})`. This ensures the clear button appears/disappears in sync with typing.

**Files modified:** `file_list_panel.dart`

### Fix 9: Tag Panel Commit on Focus Loss

Currently `_buildField()` only commits on `onSubmitted` (Enter) and `onEditingComplete`. If the user clicks a different file, `didUpdateWidget` fires and `_syncControllers()` overwrites the text — losing the pending edit.

**Solution:**
1. Add a `FocusNode` per field.
2. In the focus node's listener, when focus is lost, call `_onFieldChanged(field, controller.text)` — but only if the value actually differs from the current model value (to avoid no-op commands).
3. In `_syncControllers()`, skip overwriting a controller whose focus node currently has focus (the commit-on-focus-loss will handle it).

**Files modified:** `tag_edit_panel.dart` (`_TagFieldsTabState`)

### Fix 10: Clipboard Paste Feedback

`_handleClipboardPaste()` currently returns silently when the clipboard doesn't contain a valid image path.

**Solution:** Add a `_showError('No image found on clipboard')` call at the end of the method when no image was applied. The existing `_showError` uses a SnackBar which auto-dismisses (default 4s, close enough to 3s — or set explicit duration).

**Files modified:** `tag_edit_panel.dart` (`_AlbumArtTabState._handleClipboardPaste`)

### Fix 11: Read-Only Cell Cursor

In `EditableCell`, the `MouseRegion` uses `SystemMouseCursors.forbidden` for non-editable columns.

**Solution:** Change to `SystemMouseCursors.basic` for non-editable columns. Keep `SystemMouseCursors.text` for editable ones.

**Files modified:** `editable_cell.dart`

### Fix 12: Double-Click Consistency

In `DataGrid._DataRow`, `onDoubleTap` is set to `null` when `isEditRow` is true (to avoid conflict with cell editing). But the real issue is that double-clicking a non-editable cell should open the tag panel, while double-clicking an editable cell should enter edit mode.

**Solution:** The `EditableCell` already handles double-tap for editable cells via its own `GestureDetector.onDoubleTap`. The row's `InkWell.onDoubleTap` fires for non-editable cells (since `EditableCell` doesn't set `onDoubleTap` when `!editable`). The current guard `if (editState.isEditing) return;` on the row is fine. The issue is that `onDoubleTap` on the row is set to `null` when `isEditRow` is true — this prevents opening the tag panel when clicking non-editable cells on a row that has a focused cell.

**Fix:** Only suppress `onDoubleTap` when the row is actively *editing* (not just focused). Change the condition from `isEditRow ? null : onDoubleTap` to check `editState.isEditing && editState.editingCell?.rowIndex == rowIndex`.

**Files modified:** `data_grid.dart` (`_DataRow`)

### Fix 13: Lookup Dialog Back Navigation

The current state-machine approach in `LookupDialog._buildContent()` checks state fields in priority order. The "Back" button on the apply panel calls `updateMatching([])` which clears matches, but `trackListing` remains populated — so the user lands on the match panel.

**Solution:** The apply panel's "Back" should clear matches but preserve trackListing (landing on match panel is actually correct — the user goes Apply → Match → Results). The real issue is that from the *match panel*, "Back" calls `deselectResult()` which should clear `trackListing`. Verify this is working correctly. If the flow is Apply → Match → Results, that's a 3-step wizard and each Back goes one step — which is correct. The reported issue may be a misunderstanding of the intended flow. However, to make it clearer, add breadcrumb text showing the current step.

Actually, re-reading the code: the apply panel's `onBack` calls `updateMatching([])` which clears `matches`. Then `_buildContent` checks `matches.isNotEmpty` (false), then `trackListing.isNotEmpty` (true) → shows match panel. This IS correct — Back from Apply goes to Match. The flow is: Search → Results → Match → Apply. Each Back goes one step back. No code change needed for navigation logic.

**Revised solution:** The navigation is actually correct. The confusion was in the review. To improve clarity, add a step indicator or breadcrumb in the dialog header showing "Step 2 of 4: Track Listing" etc. This makes the wizard flow obvious.

**Files modified:** `lookup_dialog.dart` (add step indicator in header)
