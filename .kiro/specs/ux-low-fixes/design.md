# Design: UX Low Fixes (Issues 14–19)

## Overview

Six low-severity polish fixes. Most are single-file changes. Fix 16 and 17 touch settings infrastructure.

## Architecture Decisions

### Fix 14: Escape to Deselect

Add an Escape key handler in `DataGrid._handleKeyEvent`. When not editing, Escape clears the selection via `selectionProvider.notifier.clear()`. When editing, Escape already cancels the edit (handled by `InlineTextField`), so no conflict.

**Files modified:** `data_grid.dart`

### Fix 15: Address Bar Submit on Focus Loss

In `AddressBar._AddressBarState`, the `_cancelEditing()` method is called on `onTapOutside`. Change this to `_submitPath()` — which already handles the empty/unchanged case gracefully (it checks `path.isNotEmpty` before calling `onFolderSelected`). Add an additional check: only submit if the path differs from the current `loadedFolderPathProvider`.

**Files modified:** `address_bar.dart`

### Fix 16: Configurable Threshold

Add a `fileCountThreshold` field to the existing `GeneralSettings` model. Expose it in the General settings pane with a number input. Use it in `FolderLoadingService` instead of the hardcoded `500`.

**Files modified:** `general_settings.dart` (model), `settings_providers.dart` (notifier), `settings_page.dart` (UI), `folder_loading_provider.dart` (consumption)

### Fix 17: Reset to Defaults

Add a "Reset to Defaults" `TextButton` at the bottom of each `_SettingsPane`. On tap, show a confirmation dialog. On confirm, call a `resetToDefaults()` method on the corresponding settings notifier. Each notifier already knows its defaults (they're the initial state).

**Files modified:** `settings_page.dart` (add button + dialog), settings notifiers (add `resetToDefaults()` methods)

### Fix 18: Delete Presets

The `PresetNotifier` likely has or needs a `delete(int index)` method. In the Rename dialog's preset dropdown, add a trailing delete icon on each `DropdownMenuItem`. On tap, show a confirmation and call `presetProvider.notifier.delete(index)`.

Since `DropdownMenuItem` doesn't easily support trailing actions, switch to a `PopupMenuButton` or add a separate "Delete" icon button next to the dropdown. Simplest approach: add a delete `IconButton` next to the dropdown that deletes the currently selected preset.

**Files modified:** `rename_dialog.dart`, `preset_notifier.dart` (add `delete` if missing)

### Fix 19: Replace KeyboardListener

Replace `KeyboardListener` with `Focus` + `onKeyEvent` in `ImagePreviewModal`. The `Focus` widget with `autofocus: true` and `onKeyEvent` callback provides identical functionality without deprecation warnings.

**Files modified:** `image_preview_modal.dart`
