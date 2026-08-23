# Implementation Plan: Unsaved Changes Protection

## Overview

Implement window-close and folder/file-load guards that prevent silent data loss, plus a window title dirty indicator. The approach starts with the shared dialog and guard utility, then wires the window close handler, integrates the guard into all load paths, and adds the reactive title updater. Each step builds incrementally with no orphaned code.

## Tasks

- [x] 1. Create UnsavedChangesDialog and UnsavedChangesGuard
  - [x] 1.1 Create UnsavedChangesAction enum and UnsavedChangesDialog widget
    - Create `lib/shared/widgets/unsaved_changes_dialog.dart`
    - Define `UnsavedChangesAction` enum: `save`, `discard`, `cancel`
    - Implement `UnsavedChangesDialog` as a `StatelessWidget` with `modifiedFileCount` parameter
    - Implement static `show(BuildContext, int)` method returning `Future<UnsavedChangesAction?>`
    - Use `showDialog` with `barrierDismissible: false`
    - Dialog title: "Unsaved Changes"
    - Dialog body: "You have unsaved changes to N file(s). What would you like to do?"
    - Cancel button: `TextButton` (lowest weight)
    - Discard button: `TextButton` with destructive/warning color (`colorScheme.error`)
    - Save button: `FilledButton` (highest weight)
    - Escape key dismisses as `null` (treated as cancel by caller)
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

  - [x] 1.2 Create UnsavedChangesGuard utility class
    - Create `lib/shared/widgets/unsaved_changes_guard.dart`
    - Implement static `check({required BuildContext context, required WidgetRef ref, bool clearUndoOnDiscard = false})` returning `Future<bool>`
    - If `hasUnsavedChangesProvider` is false, return `true` immediately
    - Otherwise show `UnsavedChangesDialog` with `modifiedFileCountProvider` value
    - On `save`: execute save flow via existing save logic (get modified files, call `SaveActionHelper.shouldProceed`, write tags, update file list); return `true` on success, `false` on failure or cancel
    - On `discard`: if `clearUndoOnDiscard`, call `ref.read(undoRedoProvider.notifier).clear()`; return `true`
    - On `cancel` or `null`: return `false`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 4.1, 4.2, 4.3, 5.1, 5.2_

- [x] 2. Implement window close guard
  - [x] 2.1 Enable preventClose and override onWindowClose in _OpenTagEditorAppState
    - In `lib/app.dart` `initState()`, add `windowManager.setPreventClose(true)` after `windowManager.addListener(this)`
    - Override `onWindowClose()`:
      - Read `hasUnsavedChangesProvider`; if false, call `windowManager.destroy()` and return
      - If not mounted, call `windowManager.destroy()` and return
      - Call `UnsavedChangesGuard.check(context: context, ref: ref, clearUndoOnDiscard: false)`
      - If returns `true`, save window geometry (existing pattern) then call `windowManager.destroy()`
      - If returns `false`, do nothing (window stays open)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

- [x] 3. Implement window title dirty indicator
  - [x] 3.1 Add reactive window title listener in _OpenTagEditorAppState
    - In `lib/app.dart` `initState()`, add a `ref.listenManual(hasUnsavedChangesProvider, ...)` listener
    - On change: call `windowManager.setTitle(next ? '* Open Tag Editor' : 'Open Tag Editor')`
    - Also set the initial title in `initState` based on current state (will be clean at startup, but future-proofs)
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 4. Checkpoint - Verify window close guard and title indicator work
  - Build the app (`flutter build windows`) and verify no compile errors.
  - Manual verification: edit a tag, observe title changes to "* Open Tag Editor", attempt to close, verify dialog appears.

- [x] 5. Integrate guard into all load paths
  - [x] 5.1 Guard the Open Folder action in toolbar
    - In `lib/features/tag_editor/presentation/widgets/toolbar.dart` `_openFolder` method
    - At the start, call `UnsavedChangesGuard.check(context: context, ref: ref, clearUndoOnDiscard: true)`
    - If returns `false`, return early (abort the folder open)
    - _Requirements: 2.1, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 5.1_

  - [x] 5.2 Guard the Open Files action in toolbar
    - In `lib/features/tag_editor/presentation/widgets/toolbar.dart` `_openFiles` method
    - At the start, call `UnsavedChangesGuard.check(context: context, ref: ref, clearUndoOnDiscard: true)`
    - If returns `false`, return early
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 5.1_

  - [x] 5.3 Guard the drag-and-drop load path
    - In `FolderLoadingService.loadFromDrop` or at the call site in the drop target widget
    - Call `UnsavedChangesGuard.check` before proceeding with the load
    - If returns `false`, return early
    - _Requirements: 2.1, 2.2, 5.1_

  - [x] 5.4 Guard the address bar navigation
    - In the address bar's folder submission handler
    - Call `UnsavedChangesGuard.check` before calling `loadFolder`
    - If returns `false`, return early
    - _Requirements: 2.1, 5.1_

  - [x] 5.5 Guard the recent folders selection
    - In the recent folders menu item handler
    - Call `UnsavedChangesGuard.check` before calling `loadFolder`
    - If returns `false`, return early
    - _Requirements: 2.1, 5.1_

- [x] 6. Checkpoint - Verify all load guards work
  - Build the app and verify no compile errors.
  - Manual verification: edit a tag, attempt Open Folder, verify dialog appears and Cancel aborts.

- [ ] 7. Write tests
  - [ ]* 7.1 Write unit tests for UnsavedChangesGuard logic
    - Test: guard returns true immediately when no dirty state
    - Test: guard shows dialog when dirty state exists
    - Test: save action triggers save flow and returns true on success
    - Test: save action returns false on failure
    - Test: discard action clears undo when clearUndoOnDiscard is true
    - Test: discard action does not clear undo when clearUndoOnDiscard is false
    - Test: cancel action returns false without side effects
    - _Requirements: 1.1, 1.4, 1.5, 1.6, 1.7, 1.8, 2.7, 5.1, 5.2_

  - [ ]* 7.2 Write widget tests for UnsavedChangesDialog
    - Test: dialog displays correct modified file count
    - Test: Save button returns UnsavedChangesAction.save
    - Test: Discard button returns UnsavedChangesAction.discard
    - Test: Cancel button returns UnsavedChangesAction.cancel
    - Test: dialog is not dismissible by tapping outside
    - Test: Escape key dismisses dialog (returns null)
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

  - [ ]* 7.3 Write property tests for correctness invariants
    - **Property 1: Guard shown iff dirty** — for any file list state, guard shows dialog iff any file has isModified == true
    - **Property 2: Cancel is always safe** — after cancel, file list state and undo state are unchanged
    - **Property 5: Title reflects dirty state** — for any sequence of file modifications and saves, title prefix matches hasUnsavedChanges
    - _Requirements: 1.1, 1.7, 1.8, 3.1, 3.2_

- [x] 8. Final checkpoint - Ensure all tests pass and build succeeds
  - Run `flutter analyze` and `flutter build windows`.
  - Fix any issues before marking complete.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- The `windowManager.setPreventClose(true)` call is critical — without it, `onWindowClose` is never called on Windows
- The save flow in the guard reuses the existing toolbar save logic pattern (get modified files → optional confirmation → write batch → update state)
- The guard is placed BEFORE the file picker dialog in Open Folder/Files — this means the user sees the unsaved changes warning before the OS file picker opens, which is the expected UX
- `FolderLoadingService.loadFromDrop` may need a `BuildContext` parameter added if it doesn't already have one for showing the dialog
- The title listener uses `ref.listenManual` which is already the pattern used for `tagPanelOpenProvider` in the same file

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["2.1", "3.1"] },
    { "id": 3, "tasks": ["5.1", "5.2", "5.3", "5.4", "5.5"] },
    { "id": 4, "tasks": ["7.1", "7.2", "7.3"] }
  ]
}
```
