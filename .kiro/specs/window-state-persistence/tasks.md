# Implementation Plan: Window State Persistence

## Overview

Incremental implementation of window geometry persistence, resizable tag panel splitter, and last-folder reopening. The plan starts with the data model and service layer, then integrates into the startup flow, adds the splitter widget, extends settings, and wires everything together with persistence triggers.

## Tasks

- [x] 1. Create WindowState model and WindowStateService
  - [x] 1.1 Create the WindowState data model
    - Create `lib/features/settings/data/models/window_state.dart`
    - Define immutable `WindowState` class with fields: `windowWidth`, `windowHeight`, `windowX`, `windowY`, `isTagPanelOpen`, `tagPanelWidth`, `lastFolderPath`
    - Implement `WindowState.defaults()` factory (1280×800, centered, panel closed, 380px width, null path)
    - Implement `copyWith` method
    - Implement `operator ==` and `hashCode`
    - _Requirements: 1.3, 1.4, 2.2, 4.4_

  - [x] 1.2 Create the WindowStateService for shared_preferences persistence
    - Create `lib/features/settings/data/services/window_state_service.dart`
    - Implement `static Future<WindowState?> load()` — reads all `window_state_*` keys, returns null on missing/corrupt data
    - Implement `static Future<void> save(WindowState state)` — writes all fields to shared_preferences
    - Implement `static Future<void> clear()` — removes all `window_state_*` keys
    - Handle corrupted/wrong-type values gracefully (return null, no exceptions)
    - Clamp `tagPanelWidth` to [280, ∞) on load (upper bound applied at runtime with window width)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 4.1, 4.2, 4.5, 6.3_

  - [ ]* 1.3 Write unit tests for WindowState model and WindowStateService
    - Test default values, copyWith, equality
    - Test save/load round-trip with mocked SharedPreferences
    - Test corrupted data handling (null keys, wrong types, out-of-range values)
    - Test missing keys return null
    - _Requirements: 1.3, 1.4, 6.3_

- [x] 2. Create WindowStateNotifier and provider
  - [x] 2.1 Implement WindowStateNotifier as a Riverpod StateNotifier
    - Create `lib/features/settings/data/notifiers/window_state_notifier.dart`
    - Extend `StateNotifier<WindowState>` with initial state from constructor
    - Implement `updateGeometry(int width, int height, int x, int y)`
    - Implement `setTagPanelOpen(bool open)` — calls `WindowStateService.save` on change
    - Implement `setTagPanelWidth(double width)` — calls `WindowStateService.save` on change
    - Implement `setLastFolderPath(String? path)` — calls `WindowStateService.save` on change
    - _Requirements: 1.1, 4.1, 4.2, 5.1_

  - [x] 2.2 Register the windowStateProvider
    - Add `windowStateProvider` to `lib/features/settings/data/providers/settings_providers.dart`
    - Define as `StateNotifierProvider<WindowStateNotifier, WindowState>`
    - _Requirements: 4.3_

- [x] 3. Implement startup flow with window_manager
  - [x] 3.1 Add window_manager dependency and update main.dart startup
    - Add `window_manager` package to `pubspec.yaml`
    - Rewrite `main()` in `lib/main.dart` to: `ensureInitialized` → `windowManager.ensureInitialized()` → `WindowStateService.load()` → apply geometry via `windowManager.setSize`/`setPosition` → `windowManager.hide()` initially → `runApp` with `ProviderScope` override for `windowStateProvider` → `windowManager.show()`
    - Clamp restored size to primary display bounds (Property 3)
    - Validate restored position against connected displays; center if off-screen (Property 2)
    - Fall back to defaults if load returns null or window_manager init fails
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 6.1, 6.2, 6.3_

  - [ ]* 3.2 Write unit tests for geometry clamping and off-screen detection logic
    - Test size clamping to display bounds (width > display, height > display, both)
    - Test off-screen detection with various display configurations
    - Test fallback to centered on primary display
    - _Requirements: 2.3, 2.4_

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement ResizableSplitter widget
  - [x] 5.1 Create the ResizableSplitter stateful widget
    - Create `lib/shared/widgets/resizable_splitter.dart`
    - Accept `leftChild`, `rightChild`, `rightWidth`, `minRightWidth`, `maxRightWidthFraction`, `onWidthChanged`, `onDragEnd`
    - Render a draggable vertical divider (GestureDetector) between left and right children
    - Enforce min/max constraints during drag (clamp to [minRightWidth, parentWidth * maxRightWidthFraction])
    - Change cursor to `SystemMouseCursors.resizeColumn` on hover
    - Ensure hit target is ≥ 8 logical pixels wide
    - Call `onWidthChanged` during drag for real-time resize
    - Call `onDragEnd` when drag completes (for persistence trigger)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [ ]* 5.2 Write widget tests for ResizableSplitter
    - Test drag gesture updates width
    - Test cursor changes on hover
    - Test hit target is ≥ 8px wide
    - Test min/max constraints enforced during drag
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 6. Integrate splitter into HomePage layout
  - [x] 6.1 Replace fixed-width tag panel with ResizableSplitter in HomePage
    - Modify `lib/features/tag_editor/presentation/pages/home_page.dart`
    - When tag panel is open, wrap FileListPanel and tag panel content in `ResizableSplitter`
    - Read `tagPanelWidth` from `windowStateProvider`
    - Wire `onWidthChanged` to update `windowStateProvider` notifier's `setTagPanelWidth`
    - Wire `onDragEnd` to trigger persistence via the notifier
    - Use `minRightWidth: 280` and `maxRightWidthFraction: 0.5`
    - When window resizes and tag panel width > 50% of new width, clamp it (LayoutBuilder)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.7, 4.2_

  - [x] 6.2 Wire tag panel open/close to WindowStateNotifier
    - When `tagPanelOpenProvider` changes, call `windowStateNotifier.setTagPanelOpen()`
    - Restore tag panel open/closed state from `windowStateProvider` on startup (replace current `tagPanelOpenProvider` usage or integrate)
    - _Requirements: 4.1, 4.3_

- [x] 7. Persist window geometry on close
  - [x] 7.1 Add window close listener to save geometry
    - Implement `WindowListener` (from window_manager) in the app or a dedicated widget
    - On `onWindowClose`, read current window size/position via `windowManager.getSize()`/`getPosition()` and call `windowStateNotifier.updateGeometry()`
    - Ensure save completes before window closes (use `windowManager.setPreventClose(true)` pattern if needed, then `destroy()`)
    - _Requirements: 1.1, 1.2_

- [x] 8. Extend GeneralSettings with reopenLastFolder
  - [x] 8.1 Add reopenLastFolder field to GeneralSettings model and notifier
    - Add `reopenLastFolder` field (default: `false`) to `GeneralSettings` in `lib/features/settings/data/models/general_settings.dart`
    - Update `copyWith` method
    - Add persistence key `settings_v1_general_reopen_last_folder` to `GeneralSettingsNotifier`
    - Add `setReopenLastFolder(bool value)` method to notifier
    - Update `loadFromPrefs` and `_persist` to include the new field
    - _Requirements: 5.4_

  - [x] 8.2 Add UI toggle for reopenLastFolder in settings page
    - Add a switch/checkbox for "Reopen last folder on startup" in the General settings section of the settings page
    - Wire to `generalSettingsProvider.notifier.setReopenLastFolder()`
    - _Requirements: 5.4_

- [x] 9. Implement last folder persistence and reload
  - [x] 9.1 Persist last loaded folder path and reload on startup
    - When a folder is successfully loaded, call `windowStateNotifier.setLastFolderPath(path)`
    - On startup (in `app.dart` or a startup widget), if `reopenLastFolder` is enabled and `lastFolderPath` is non-null:
      - Check if the folder exists on disk
      - If exists, trigger folder loading
      - If not exists, clear the persisted path
    - If `reopenLastFolder` is disabled, do not load any folder
    - _Requirements: 5.1, 5.2, 5.3, 5.5_

- [x] 10. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Property-based tests for correctness properties
  - [ ]* 11.1 Write property test: Window state serialization round-trip
    - **Property 1: Window state serialization round-trip**
    - Generate random valid `WindowState` instances (random ints for geometry, random bool, random double for width, random optional string for path)
    - Save via `WindowStateService.save()`, load via `WindowStateService.load()`, assert equality
    - Minimum 100 iterations
    - **Validates: Requirements 1.3, 1.4**

  - [ ]* 11.2 Write property test: Off-screen position falls back to centered
    - **Property 2: Off-screen position falls back to centered**
    - Generate random positions and display bounds where no display contains the window rectangle
    - Assert restored position is centered on primary display
    - Minimum 100 iterations
    - **Validates: Requirements 2.3**

  - [ ]* 11.3 Write property test: Window size clamped to display bounds
    - **Property 3: Window size clamped to display bounds**
    - Generate random sizes exceeding display bounds
    - Assert clamped result has width ≤ display width and height ≤ display height
    - Minimum 100 iterations
    - **Validates: Requirements 2.4**

  - [ ]* 11.4 Write property test: Tag panel width minimum invariant
    - **Property 4: Tag panel width minimum invariant**
    - Generate random width values including negatives and very small numbers
    - Assert effective tag panel width ≥ 280 logical pixels
    - Minimum 100 iterations
    - **Validates: Requirements 3.3, 4.5**

  - [ ]* 11.5 Write property test: Tag panel width maximum invariant
    - **Property 5: Tag panel width maximum invariant**
    - Generate random width values and window widths
    - Assert effective tag panel width ≤ 50% of current window width
    - Minimum 100 iterations
    - **Validates: Requirements 3.4, 3.7, 4.6**

  - [ ]* 11.6 Write property test: Corrupted persisted data produces valid defaults
    - **Property 6: Corrupted persisted data produces valid defaults**
    - Generate random invalid preference maps (null values, wrong types, out-of-range numbers, invalid strings)
    - Assert `WindowStateService.load()` returns either a valid `WindowState` or null, and does not throw
    - Minimum 100 iterations
    - **Validates: Requirements 6.3**

- [x] 12. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The `window_manager` package is required as a new dependency for programmatic window control
- All persistence uses the `window_state_` key prefix to avoid collisions with existing `settings_v1_*` keys
- The startup flow change (hiding window until geometry is applied) is critical for requirement 6.1/6.2

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "8.1"] },
    { "id": 2, "tasks": ["1.3", "2.1", "5.1", "8.2"] },
    { "id": 3, "tasks": ["2.2", "5.2"] },
    { "id": 4, "tasks": ["3.1"] },
    { "id": 5, "tasks": ["3.2", "6.1"] },
    { "id": 6, "tasks": ["6.2", "7.1"] },
    { "id": 7, "tasks": ["9.1"] },
    { "id": 8, "tasks": ["11.1", "11.2", "11.3", "11.4", "11.5", "11.6"] }
  ]
}
```
