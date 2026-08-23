# Requirements: UX Low Fixes (Issues 14–19)

## Overview

Address six low-severity polish issues: missing deselect shortcut, address bar focus-loss behaviour, hardcoded threshold, settings reset, preset deletion, and deprecated widget usage.

## Requirements

### 14. Keyboard Shortcut to Deselect All

- 14.1 Pressing Escape when the data grid has focus and no cell is being edited MUST clear the file selection.
- 14.2 If a cell is being edited, Escape MUST cancel the edit (existing behaviour) without clearing selection.

### 15. Address Bar Submit on Focus Loss

- 15.1 When the address bar text field loses focus (e.g., user clicks elsewhere), the typed path MUST be submitted (same as pressing Enter) if it differs from the current loaded path.
- 15.2 If the typed path is empty or unchanged, focus loss MUST simply exit edit mode without triggering a load.

### 16. Configurable File Count Threshold

- 16.1 The threshold for the "Large Directory" warning dialog MUST be configurable in Settings → General.
- 16.2 The default value MUST remain 500 files.
- 16.3 The setting MUST accept values between 50 and 10000.

### 17. Settings Reset to Defaults

- 17.1 Each settings category pane MUST include a "Reset to Defaults" button.
- 17.2 Clicking "Reset to Defaults" MUST show a confirmation dialog before resetting.
- 17.3 After reset, all settings in that category MUST revert to their factory defaults.

### 18. Delete Rename Presets

- 18.1 The preset dropdown in the Rename dialog MUST allow deleting presets.
- 18.2 Deletion MUST be accessible via a delete icon or long-press/right-click on the preset item.
- 18.3 Deletion MUST show a confirmation before removing the preset.

### 19. Replace Deprecated KeyboardListener

- 19.1 The `ImagePreviewModal` MUST use `Focus` with `onKeyEvent` instead of the deprecated `KeyboardListener` widget.
- 19.2 Behaviour MUST remain identical (Escape closes the modal).
