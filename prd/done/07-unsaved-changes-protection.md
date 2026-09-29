# PRD 07: Unsaved Changes Protection (P1)

## Status: shipped

Delivered:

- Close guard, folder-load guard at every entry point, and the `*` window
  title indicator, all driven by `hasUnsavedChangesProvider`.
- A modified-cell indicator per grid cell plus the status-bar count.
- **Confirm before saving tags** (`GeneralSettings.confirmBeforeSave`).
  `UnsavedChangesGuard._executeSave` already documented this dialog but it
  was never implemented; it now exists, and all four save entry points
  (toolbar, Ctrl+S, tag panel, unsaved-changes guard) route through one
  `SaveConfirmation.confirmIfNeeded` so the setting cannot be bypassed by
  taking a different route to the same write. It defaults to off, because
  prompting on every save would be noise rather than safety.

Deliberate deviation: the PRD asks for separate "Save & Continue" / "Discard
& Continue" wording when loading a folder. A single dialog with
Cancel / Discard / Save is used for both cases, since the decision the user
is making is identical and a second wording would only invite mistakes.

## Problem Statement

Users can lose tag edits silently by closing the app, loading a new folder, or navigating away while modifications are pending. The "Confirm before saving" setting exists in the UI but is not implemented. There is no visual cue in the window title indicating unsaved state.

## Goals

- Prevent accidental data loss from unsaved tag modifications.
- Provide clear visual indicators of dirty state.
- Implement the existing "confirm before saving" setting stub.

## Functional Requirements

### Close Protection
- When the user attempts to close the application window with unsaved modifications, show a confirmation dialog: "You have unsaved changes to X file(s). Save before closing?" with Save / Discard / Cancel options.
- Cancel aborts the close.
- Discard closes without saving.
- Save writes all modified files, then closes.

### Folder Load Protection
- When the user loads a new folder (via picker, recent folders, drag-and-drop, or address bar) while modifications exist, show a confirmation dialog: "Loading a new folder will discard unsaved changes to X file(s). Continue?" with Save & Continue / Discard & Continue / Cancel options.

### Window Title Indicator
- When any file has `isModified == true`, prepend the window title with a bullet or asterisk: `● Open Tag Editor` or `* Open Tag Editor`.
- When no files are modified, show the normal title.

### Confirm Before Saving Setting
- Wire the existing "Confirm before saving" toggle in Settings.
- When enabled, the Save action (toolbar button, Ctrl+S) shows a confirmation dialog listing the files that will be written before proceeding.
- When disabled, save executes immediately (current behavior).

### Modified File Indicator in Grid
- Files with `isModified == true` should show a subtle visual indicator in the data grid row (e.g., a dot or italic filename) in addition to the existing status bar count.

## Non-Functional Requirements

- Dialogs must not block for more than one user action (no nested confirmations).
- The window title update must be immediate (no perceptible delay after editing).

## Dependencies

- None beyond existing infrastructure.

## Out of Scope

- Auto-save functionality.
- Per-field dirty tracking (we track at the file level).
