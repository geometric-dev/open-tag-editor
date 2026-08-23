# Implementation Plan: Smart Fill Menu

## Overview

Implement a context-aware smart fill dropdown for editable cells in the DataGrid. The approach starts with pure-function core components (`collectColumnValues`, `buildFillMenuLabel`, `buildFillMenuItems`, `determineTargetPaths`), validates each with property-based tests, then integrates into the existing `EditableCell` widget with fill arrow UI and menu display logic. Each step builds incrementally on the previous, reusing the existing `buildTagEditCommand` and `UndoRedoManager` infrastructure.

## Tasks

- [x] 1. Implement pure-function core logic
  - [x] 1.1 Create `collectColumnValues` function
    - Create `lib/features/smart_fill_menu/data/collect_column_values.dart`
    - Implement `collectColumnValues({required List<AudioFile> files, required String columnId})` that returns unique non-empty values in first-appearance order
    - Use case-sensitive deduplication, exclude empty/whitespace-only strings, preserve insertion order via `LinkedHashSet` or manual tracking
    - _Requirements: 2.2, 2.4, 5.1, 5.2, 5.3, 5.4_
    - _Subagent: delegate_

  - [x] 1.2 Create `buildFillMenuLabel` function
    - Create `lib/features/smart_fill_menu/data/build_fill_menu_label.dart`
    - Implement `buildFillMenuLabel({required String value, required int selectedCount, required int totalCount, bool isBlank = false})` that returns the correct label string
    - Use "Set all to {value}" when selectedCount == 0 or selectedCount == totalCount; use "Set selected to {value}" otherwise
    - Truncate value to 40 characters with "…" (U+2026) if it exceeds 40 characters
    - For blank option, display "blank" as the value portion
    - Include private helpers `_isAllScope` and `_truncateValue`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_
    - _Subagent: delegate_

  - [x] 1.3 Create `determineTargetPaths` function
    - Create `lib/features/smart_fill_menu/data/determine_target_paths.dart`
    - Implement `determineTargetPaths({required Set<String> selectedPaths, required List<AudioFile> allFiles})` that returns all file paths when selection is empty or full, otherwise returns only selected paths
    - _Requirements: 4.1, 4.2, 7.2_
    - _Subagent: delegate_

  - [x] 1.4 Create `buildFillMenuItems` function
    - Create `lib/features/smart_fill_menu/data/build_fill_menu_items.dart`
    - Implement `buildFillMenuItems({required List<String> values, required int selectedCount, required int totalCount})` that builds `List<PopupMenuEntry<String>>` with labeled items for each value plus a blank option at the end
    - Import and use `buildFillMenuLabel` for label generation
    - _Requirements: 2.2, 2.3, 2.4, 2.5_
    - _Subagent: delegate_

- [x] 2. Write property-based tests for pure functions
  - [x] 2.1 Write property test for `collectColumnValues` (Property 1)
    - **Property 1: collectColumnValues returns unique non-empty values in first-appearance order**
    - **Validates: Requirements 2.2, 2.4, 5.2, 5.3, 5.4**
    - Create `test/features/smart_fill_menu/collect_column_values_test.dart`
    - Generate random lists of AudioFile with varying tag maps (empty, whitespace, duplicates, case variants)
    - Assert: (a) every element is non-empty/non-whitespace, (b) no duplicates (case-sensitive), (c) order matches first appearance, (d) no valid value is missing
    - _Subagent: delegate_

  - [x] 2.2 Write property test for `buildFillMenuLabel` scope determination (Property 2)
    - **Property 2: buildFillMenuLabel scope determination**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 7.3, 7.4, 7.5**
    - Create `test/features/smart_fill_menu/build_fill_menu_label_test.dart`
    - Generate random strings + random (selectedCount, totalCount) pairs respecting 0 ≤ selected ≤ total, total ≥ 1
    - Assert: label contains "all" iff selectedCount == 0 or selectedCount == totalCount; contains "selected" otherwise; blank option ends with "blank"
    - _Subagent: delegate_

  - [x] 2.3 Write property test for `buildFillMenuLabel` truncation (Property 3)
    - **Property 3: buildFillMenuLabel truncation**
    - **Validates: Requirements 3.6**
    - In `test/features/smart_fill_menu/build_fill_menu_label_test.dart`
    - Generate random strings of length 0–200 characters
    - Assert: if length > 40, displayed value is first 40 chars + "…"; if length ≤ 40, displayed value is the original string
    - _Subagent: delegate_

  - [x] 2.4 Write property test for `buildFillMenuItems` blank-last invariant (Property 4)
    - **Property 4: buildFillMenuItems blank-last invariant**
    - **Validates: Requirements 2.3, 2.5**
    - Create `test/features/smart_fill_menu/build_fill_menu_items_test.dart`
    - Generate random value lists of length 0–60
    - Assert: last entry is blank option (value = empty string), preceding entries correspond one-to-one with input values in same order
    - _Subagent: delegate_

  - [x] 2.5 Write property test for `determineTargetPaths` scope correctness (Property 5)
    - **Property 5: determineTargetPaths scope correctness**
    - **Validates: Requirements 4.1, 4.2, 7.2**
    - Create `test/features/smart_fill_menu/determine_target_paths_test.dart`
    - Generate random file lists + random subsets of their paths (including empty and full)
    - Assert: returns all paths if selection is empty or full; returns only selected paths otherwise
    - _Subagent: delegate_

  - [x] 2.6 Write property test for fill action no-op (Property 6)
    - **Property 6: Fill action is no-op when no values differ**
    - **Validates: Requirements 4.4, 4.5**
    - Create `test/features/smart_fill_menu/fill_action_command_test.dart`
    - Generate random file lists with tags set to either the chosen value or different values
    - Assert: no command created when all targets already have the chosen value; exactly one command created when at least one differs
    - _Subagent: delegate_

- [x] 3. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Integrate fill arrow into EditableCell widget
  - [x] 4.1 Add fill arrow hover state and icon to `EditableCell`
    - Modify `lib/features/data_grid/presentation/widgets/editable_cell.dart`
    - Add a conditionally-visible fill arrow icon button (right-aligned, 24×24 dp hit target) that appears on hover
    - Hide the arrow when the cell is in active edit mode or the column is read-only
    - Ensure clicking the fill arrow does NOT trigger inline edit mode
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_
    - _Subagent: main thread (architectural)_

  - [x] 4.2 Implement `_openSmartFillMenu` method in EditableCell state
    - In the same file, implement the menu-opening logic:
    - Cancel any active inline edit via `InlineCellEditNotifier.cancelEdit()`
    - Capture selection snapshot and file list at menu-open time
    - Call `collectColumnValues`, `buildFillMenuItems`, and `showMenu<String>()`
    - Anchor menu to the fill arrow's render box position
    - Apply `BoxConstraints(maxHeight: 280)` when values exceed 20 items
    - On value selection: call `determineTargetPaths`, `buildTagEditCommand`, execute via `UndoRedoManager`
    - On dismiss (null): no action
    - _Requirements: 2.1, 2.6, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 5.5, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_
    - _Subagent: main thread (cross-file wiring)_

- [x] 5. Write widget and integration tests
  - [x] 5.1 Write widget tests for fill arrow visibility and interaction
    - Create `test/features/smart_fill_menu/smart_fill_menu_widget_test.dart`
    - Test: fill arrow appears on hover, hides on leave, hidden during edit mode, hidden on read-only columns, click does not trigger edit mode, menu opens on click
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_
    - _Subagent: delegate_

  - [x] 5.2 Write integration tests for fill action and undo/redo
    - In `test/features/smart_fill_menu/smart_fill_menu_widget_test.dart`
    - Test: fill action creates TagEditCommand, Ctrl+Z undoes entire fill in one step, Ctrl+Y redoes, active edit cancelled before menu opens, grid cells update after fill
    - _Requirements: 4.4, 6.1, 6.2, 6.3, 6.4_
    - _Subagent: delegate_

- [x] 6. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate the 6 universal correctness properties defined in the design
- Unit tests validate specific examples and edge cases
- Pure-function core components (task 1) have no widget dependencies and are fully testable in isolation
- The existing `buildTagEditCommand`, `UndoRedoManager`, and `InlineCellEditNotifier` are reused without modification
- Test files are organised under `test/features/smart_fill_menu/`

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["1.4", "2.1", "2.2", "2.3", "2.5"] },
    { "id": 2, "tasks": ["2.4", "2.6"] },
    { "id": 3, "tasks": ["4.1"] },
    { "id": 4, "tasks": ["4.2"] },
    { "id": 5, "tasks": ["5.1", "5.2"] }
  ]
}
```
