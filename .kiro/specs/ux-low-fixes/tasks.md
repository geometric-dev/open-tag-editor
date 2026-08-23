# Implementation Plan: UX Low Fixes (Issues 14–19)

## Overview

Six low-severity polish fixes. Most are single-file, single-method changes. Fixes 16 and 17 touch settings infrastructure but remain straightforward.

## Tasks

- [x] 1. Fix 14 — Escape key to deselect all
  - [x] 1.1 Add Escape key handler in DataGrid
    - In `lib/features/tag_editor/presentation/widgets/data_grid/data_grid.dart` (`_handleKeyEvent`):
      - Add a case for `LogicalKeyboardKey.escape` when `!editState.isEditing`:
        ```dart
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          selNotifier.clear();
          return KeyEventResult.handled;
        }
        ```
      - Place it before the F2/printable-character handlers
      - When editing, Escape is already handled by InlineTextField (cancels edit), so this won't conflict
    - _Requirements: 14.1, 14.2_

- [x] 2. Fix 15 — Address bar submit on focus loss
  - [x] 2.1 Change onTapOutside from cancel to submit
    - In `lib/features/tag_editor/presentation/widgets/address_bar.dart` (`_AddressBarState`):
      - Change `onTapOutside: (_) => _cancelEditing()` to `onTapOutside: (_) => _submitOrCancel()`
      - Add method `_submitOrCancel()`:
        ```dart
        void _submitOrCancel() {
          final path = _controller.text.trim();
          final currentPath = ref.read(loadedFolderPathProvider) ?? '';
          setState(() => _isEditing = false);
          if (path.isNotEmpty && path != currentPath) {
            widget.onFolderSelected?.call(path);
          }
        }
        ```
    - _Requirements: 15.1, 15.2_

- [x] 3. Fix 16 — Configurable file count threshold
  - [x] 3.1 Add fileCountThreshold to GeneralSettings model
    - In the GeneralSettings model (find via `generalSettingsProvider`):
      - Add `final int fileCountThreshold;` with default `500`
      - Update `copyWith`, constructor, and serialization
    - _Requirements: 16.1, 16.2, 16.3_

  - [x] 3.2 Add setter in GeneralSettingsNotifier
    - Add `setFileCountThreshold(int value)` that clamps to 50–10000 range and persists
    - _Requirements: 16.3_

  - [x] 3.3 Add UI control in Settings → General pane
    - In `lib/features/settings/presentation/pages/settings_page.dart` (`_GeneralPane`):
      - Add a `_TextFieldRow` (or number input) with label "Large folder warning threshold" and subtitle "Show warning when scanning more than this many files"
      - Bind to `generalSettingsProvider.fileCountThreshold`
    - _Requirements: 16.1_

  - [x] 3.4 Use configurable threshold in FolderLoadingService
    - In `lib/features/tag_editor/data/providers/folder_loading_provider.dart`:
      - Replace hardcoded `500` with `_ref.read(generalSettingsProvider).fileCountThreshold`
      - Also replace the `limit: 500` in `countAudioFiles` with the same value
    - _Requirements: 16.1, 16.2_

- [x] 4. Fix 17 — Settings reset to defaults
  - [x] 4.1 Add resetToDefaults methods to settings notifiers
    - In each settings notifier (GeneralSettingsNotifier, TagWritingSettingsNotifier, RenamingSettingsNotifier, LookupSettingsNotifier):
      - Add `void resetToDefaults()` that sets state to the factory default and persists
    - _Requirements: 17.3_

  - [x] 4.2 Add Reset to Defaults button in each settings pane
    - In `lib/features/settings/presentation/pages/settings_page.dart`:
      - In `_SettingsPane`, add an optional `VoidCallback? onReset` parameter
      - When provided, render a `TextButton` with label "Reset to Defaults" at the bottom of the pane
      - On tap, show a confirmation dialog: "Reset all settings in this category to defaults?"
      - On confirm, call `onReset()`
      - Wire each pane to its notifier's `resetToDefaults()` method
    - _Requirements: 17.1, 17.2, 17.3_

- [x] 5. Fix 18 — Delete rename presets
  - [x] 5.1 Add delete method to PresetNotifier
    - In `lib/features/renamer/data/preset_notifier.dart`:
      - Add `void delete(int index)` that removes the preset at the given index and persists
      - Guard: no-op if index is out of range
    - _Requirements: 18.1_

  - [x] 5.2 Add delete button in Rename dialog preset row
    - In `lib/features/renamer/presentation/widgets/rename_dialog.dart`:
      - Add an `IconButton` with `Icons.delete_outline` next to the preset dropdown
      - Disable when no preset is selected or presets list is empty
      - On tap, show confirmation dialog: "Delete preset 'name'?"
      - On confirm, call `ref.read(presetProvider.notifier).delete(selectedIndex)`
    - _Requirements: 18.1, 18.2, 18.3_

- [x] 6. Fix 19 — Replace deprecated KeyboardListener
  - [x] 6.1 Replace KeyboardListener with Focus in ImagePreviewModal
    - In `lib/features/album_art/presentation/widgets/image_preview_modal.dart`:
      - Replace:
        ```dart
        KeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          autofocus: true,
          onKeyEvent: (event) { ... },
          child: ...
        )
        ```
      - With:
        ```dart
        Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: ...
        )
        ```
      - Remove the manually created `FocusNode()..requestFocus()`
    - _Requirements: 19.1, 19.2_

## Notes

- All fixes are independent and can be implemented in parallel (except 3.1→3.2→3.3→3.4 which are sequential within Fix 16).
- Fix 17 requires knowing the default values for each settings category — these are already defined as constructor defaults in the model classes.
- Fix 18 needs a `selectedIndex` state variable in the rename dialog to track which preset is active for deletion.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "3.1", "4.1", "5.1", "6.1"] },
    { "id": 1, "tasks": ["3.2", "4.2", "5.2"] },
    { "id": 2, "tasks": ["3.3"] },
    { "id": 3, "tasks": ["3.4"] }
  ]
}
```
