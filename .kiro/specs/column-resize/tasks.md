# Implementation Plan: Column Resize

## Overview

Implement drag-to-resize column headers for the Data Grid. The approach starts with extending the `ColumnConfig` model with a `widthOverrides` map, then implements pure-function width resolution and auto-fit calculation, extends the `ColumnConfigNotifier` with resize/reset methods, adds the `ResizeHandle` widget to column headers, wires persistence, and adds the context menu reset option. Each step builds incrementally, with pure-function logic validated by property-based tests before integrating into the widget layer.

## Tasks

- [x] 1. Extend ColumnConfig model with width overrides
  - [x] 1.1 Add widthOverrides field to ColumnConfig
    - Add `final Map<String, double> widthOverrides` field with default empty map to `ColumnConfig`
    - Update `copyWith` to include `widthOverrides` parameter
    - Update any `==` / `hashCode` / `toString` if the model uses them
    - _Requirements: 4.1, 4.4_
    - _Subagent: delegate_

  - [x] 1.2 Update persistence serialization to include widths
    - Add `widths` key to the persisted JSON structure in shared_preferences
    - Update the save method to serialize `widthOverrides` as `Map<String, double>`
    - Update the load method to deserialize the `widths` key, filtering out unknown column IDs and invalid values (< 40.0)
    - Handle backward compatibility: if `widths` key is absent, default to empty map
    - _Requirements: 4.1, 4.2, 4.3_
    - _Subagent: main thread (cross-file wiring)_ — must read existing persistence code to integrate correctly

- [x] 2. Implement pure-function width resolution and auto-fit
  - [x] 2.1 Implement resolveEffectiveWidth function
    - Create `lib/features/tag_editor/data/column_width_resolver.dart`
    - Implement `resolveEffectiveWidth(String columnId, Map<String, double> widthOverrides, List<ColumnDefinition> columns)` that returns the override value if present, otherwise the column's `defaultWidth`
    - _Requirements: 4.4_
    - _Subagent: delegate_

  - [x] 2.2 Implement calculateAutoFitWidth function
    - In the same file, implement `calculateAutoFitWidth({required List<double> cellWidths, required double headerLabelWidth, double minWidth = 40.0, double maxWidth = 500.0, double padding = 16.0})` that returns `clamp(max(allWidths) + padding, minWidth, maxWidth)`
    - _Requirements: 2.1, 2.2, 2.3, 2.4_
    - _Subagent: delegate_

  - [ ]* 2.3 Write property test: Resize width calculation (Property 1)
    - **Property 1: Resize width calculation**
    - **Validates: Requirements 1.3, 1.4, 1.5**
    - Create `test/features/tag_editor/data/column_resize_properties_test.dart`
    - For any starting width and drag delta, verify result equals `max(startWidth + delta, 40.0)`
    - _Subagent: delegate_

  - [ ]* 2.4 Write property test: Auto-fit width calculation (Property 3)
    - **Property 3: Auto-fit width calculation**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4**
    - In the same test file, for any list of cell widths and header label width, verify result equals `clamp(max(allWidths) + padding, 40.0, 500.0)`
    - _Subagent: delegate_

  - [ ]* 2.5 Write property test: Effective width resolution (Property 6)
    - **Property 6: Effective width resolution**
    - **Validates: Requirements 4.4**
    - For any column ID and overrides map, verify: if override exists return override value, otherwise return defaultWidth
    - _Subagent: delegate_

  - [ ]* 2.6 Write unit tests for resolveEffectiveWidth and calculateAutoFitWidth
    - Test resolveEffectiveWidth: column with override, column without override, unknown column ID fallback
    - Test calculateAutoFitWidth: empty cell list, single cell wider than max, all cells narrower than min, header wider than all cells
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 4.4_
    - _Subagent: delegate_

- [x] 3. Extend ColumnConfigNotifier with resize methods
  - [x] 3.1 Add setColumnWidth, persistWidths, and resetColumnWidths methods
    - Add `static const double minColumnWidth = 40.0` and `static const double maxAutoFitWidth = 500.0`
    - Implement `setColumnWidth(String columnId, double width)` — reject tagIndicator, clamp to minColumnWidth, update overrides map in state
    - Implement `persistWidths()` — call existing persist method to save current state
    - Implement `resetColumnWidths()` — clear widthOverrides map and persist
    - Add `_isNonResizable(String columnId)` helper returning true for tagIndicator
    - _Requirements: 1.4, 1.5, 1.6, 1.7, 3.2, 3.3_
    - _Subagent: main thread (cross-file wiring)_ — extends existing notifier, must read current state management patterns

  - [ ]* 3.2 Write property test: Reset restores defaults (Property 4)
    - **Property 4: Reset restores defaults**
    - **Validates: Requirements 3.2**
    - In `test/features/tag_editor/data/column_resize_properties_test.dart`
    - For any set of width overrides, after resetColumnWidths, verify widthOverrides is empty and resolveEffectiveWidth returns defaultWidth for all columns
    - _Subagent: delegate_

  - [ ]* 3.3 Write property test: Width persistence round-trip (Property 2)
    - **Property 2: Width persistence round-trip**
    - **Validates: Requirements 1.6, 2.5, 4.1, 4.2**
    - For any valid overrides map (values ≥ 40, valid column IDs), verify persist then load produces equivalent map
    - _Subagent: delegate_

  - [ ]* 3.4 Write property test: Unknown column IDs ignored on load (Property 5)
    - **Property 5: Unknown column IDs ignored on load**
    - **Validates: Requirements 4.3**
    - For any persisted map with mix of valid and invalid column IDs, verify load produces map with only valid IDs
    - _Subagent: delegate_

  - [ ]* 3.5 Write unit tests for ColumnConfigNotifier resize methods
    - Test setColumnWidth rejects tagIndicator, clamps at 40px, stores override
    - Test resetColumnWidths clears overrides map
    - Test persistence loading filters unknown IDs, discards invalid widths, handles missing widths key
    - _Requirements: 1.4, 1.6, 1.7, 3.2, 4.1, 4.2, 4.3_
    - _Subagent: delegate_

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement ResizeHandle widget
  - [x] 5.1 Create ResizeHandle widget
    - Create `lib/features/tag_editor/presentation/widgets/resize_handle.dart`
    - Implement as a `StatelessWidget` with `MouseRegion` (cursor: `SystemMouseCursors.resizeColumn`) wrapping a `GestureDetector`
    - Handle `onHorizontalDragStart` (capture starting width), `onHorizontalDragUpdate` (compute new width = startWidth + totalDelta, call onDragUpdate), `onHorizontalDragEnd` (call onDragEnd)
    - Handle `onDoubleTap` (call onDoubleTap callback)
    - Use `hitTargetWidth` of 8 logical pixels for the hit area
    - Position on the right edge of the column header cell
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 5.2_
    - _Subagent: delegate_

  - [x] 5.2 Integrate ResizeHandle into column headers
    - Modify the column header widget to render a `ResizeHandle` on the right edge of each resizable column
    - Skip rendering for tagIndicator column
    - Wire `onDragUpdate` to call `ColumnConfigNotifier.setColumnWidth`
    - Wire `onDragEnd` to call `ColumnConfigNotifier.persistWidths`
    - Wire `onDoubleTap` to trigger auto-fit calculation
    - _Requirements: 1.1, 1.3, 1.6, 1.7, 2.1_
    - _Subagent: main thread (cross-file wiring)_ — must read existing header widget structure and integrate

  - [x] 5.3 Implement auto-fit on double-click
    - On double-tap, measure visible cell content widths using `TextPainter` for the target column
    - Measure header label width using `TextPainter`
    - Call `calculateAutoFitWidth` with measured widths
    - Apply result via `ColumnConfigNotifier.setColumnWidth` and persist
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
    - _Subagent: main thread (complex logic)_ — requires TextPainter measurement and understanding of grid data flow

  - [x] 5.4 Wire resolveEffectiveWidth into Data Grid layout
    - Update the Data Grid and Data Row widgets to use `resolveEffectiveWidth` for column width instead of reading `defaultWidth` directly
    - Ensure columns rebuild when `widthOverrides` changes in the provider
    - _Requirements: 4.4, 5.1_
    - _Subagent: main thread (cross-file wiring)_ — must update multiple widget files that consume column widths

- [x] 6. Add context menu with Reset Column Widths option
  - [x] 6.1 Add "Reset Column Widths" to column header context menu
    - Add a right-click context menu to column headers (or extend existing context menu)
    - Include "Reset Column Widths" menu item
    - On selection, call `ColumnConfigNotifier.resetColumnWidths()`
    - Verify grid immediately reflects default widths
    - _Requirements: 3.1, 3.2, 3.3_
    - _Subagent: main thread (cross-file wiring)_ — must read existing context menu patterns and extend them

- [x] 7. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Widget tests
  - [ ]* 8.1 Write widget tests for ResizeHandle and column resize interaction
    - Test ResizeHandle renders on resizable columns, absent on tagIndicator
    - Test cursor changes to `SystemMouseCursors.resizeColumn` on hover
    - Test drag gesture updates column width
    - Test double-tap triggers auto-fit
    - Test context menu displays "Reset Column Widths" and triggers reset
    - Test hit-target is at least 8 logical pixels wide
    - _Requirements: 1.1, 1.2, 1.3, 1.7, 2.1, 3.1, 5.2_
    - _Subagent: main thread (complex logic)_ — widget tests require understanding of the full widget tree and provider setup

- [x] 9. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate the 6 universal correctness properties defined in the design
- Unit tests validate specific examples and edge cases
- Pure-function components (task 2) have no widget dependencies and are fully testable in isolation
- The feature extends existing `ColumnConfig` and `ColumnConfigNotifier` — no new providers needed
- Persistence format is backward-compatible: existing JSON without `widths` key loads cleanly

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "2.1", "2.2"] },
    { "id": 2, "tasks": ["2.3", "2.4", "2.5", "2.6", "3.1"] },
    { "id": 3, "tasks": ["3.2", "3.3", "3.4", "3.5"] },
    { "id": 4, "tasks": ["5.1", "5.4"] },
    { "id": 5, "tasks": ["5.2", "5.3", "6.1"] },
    { "id": 6, "tasks": ["8.1"] }
  ]
}
```
