# Implementation Plan: Table UX & Performance

## Overview

Implement visual polish and performance optimisations for the data grid in a single pass. The approach starts with the performance foundation (pre-computed widths, RepaintBoundary, selective rebuild) since these change the widget interfaces, then layers the visual improvements (hover, sort indicators, tooltips, zebra striping) on top of the updated structure.

## Tasks

- [x] 1. Pre-compute effective widths and pass down
  - [x] 1.1 Refactor _ScrollableDataGrid to compute effectiveWidths list
    - In `_ScrollableDataGridState.build()`, compute `final effectiveWidths = _computeEffectiveWidths()` once per build
    - Derive `totalWidth` from `effectiveWidths.fold(0.0, (sum, w) => sum + w)`
    - Removed the old `_totalWidth` getter that recomputed on every access
    - Pass `effectiveWidths` to `ColumnHeaders` as a new required parameter
    - Pass `effectiveWidths` to each `_DataRow` replacing the `widthOverrides` parameter
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
    - _Subagent: main thread (cross-file wiring)_

  - [x] 1.2 Update ColumnHeaders to accept effectiveWidths
    - Added `required List<double> effectiveWidths` parameter to `ColumnHeaders`
    - Removed internal `resolveEffectiveWidth` calls — uses `effectiveWidths[i]` by index
    - Removed unused `column_width_resolver.dart` import
    - _Requirements: 5.3_
    - _Subagent: main thread (cross-file wiring)_

  - [x] 1.3 Update _DataRow to accept effectiveWidths
    - Replaced `widthOverrides` parameter with `required List<double> effectiveWidths`
    - Removed all `resolveEffectiveWidth` calls inside `_DataRow.build()`
    - Uses `effectiveWidths[i]` when rendering each cell
    - _Requirements: 5.2_
    - _Subagent: main thread (cross-file wiring)_

- [x] 2. Add RepaintBoundary on ColumnHeaders
  - [x] 2.1 Wrap ColumnHeaders in RepaintBoundary
    - In `_ScrollableDataGridState.build()`, wrapped the `ColumnHeaders(...)` widget in a `RepaintBoundary`
    - Isolates the header from the vertically-scrolling ListView repaints
    - _Requirements: 6.1, 6.2_

- [x] 3. Selective rebuild for inline edit state
  - [x] 3.1 Change _DataRow to use select on inlineCellEditProvider
    - Replaced `final editState = ref.watch(inlineCellEditProvider)` with `final isEditRow = ref.watch(inlineCellEditProvider.select((s) => s.editingCell?.rowIndex == rowIndex || s.focusedCell?.rowIndex == rowIndex))`
    - Updated the `onDoubleTap` guard to use `isEditRow` instead of `editState.isEditing`
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 4. Checkpoint — verify build compiles
  - ✅ `flutter analyze` — zero issues
  - ✅ `flutter test` — 177 tests pass
  - ✅ `flutter build windows` — successful

- [x] 5. Column header hover state
  - [x] 5.1 Convert _ColumnHeaderCell from StatelessWidget to StatefulWidget
    - Changed to `StatefulWidget` with `_ColumnHeaderCellState`
    - Added `bool _isHovered = false` field
    - Wrapped content in `MouseRegion` with `onEnter`/`onExit` toggling `_isHovered`
    - Only enabled for sortable columns (not tagIndicator)
    - Applied hover background: `colorScheme.onSurface.withValues(alpha: 0.05)`
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 6. Improved sort indicators
  - [x] 6.1 Update sort indicator styling
    - Changed sort icon size from 12 to 14 logical pixels
    - Changed sort icon colour to `colorScheme.primary`
    - Applied sorted-column background tint `colorScheme.primary.withValues(alpha: 0.08)`
    - Sorted-column tint takes precedence over hover tint
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 7. Column header tooltips
  - [x] 7.1 Add Tooltip to column header labels
    - Wrapped column label `Text` in `Tooltip(message: column.label)` for sortable columns
    - Skipped tagIndicator (no label)
    - Uses default tooltip delay
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 8. Zebra striping on data rows
  - [x] 8.1 Add alternating row background
    - Selection: `colorScheme.primaryContainer.withValues(alpha: 0.5)` (precedence)
    - Even rows: `colorScheme.onSurface.withValues(alpha: 0.03)`
    - Odd rows: transparent (null)
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 9. Final checkpoint — full validation
  - ✅ `flutter analyze` — zero errors
  - ✅ `flutter test` — 177 tests pass
  - ✅ `flutter build windows` — successful build

## Notes

- Tasks 1.1, 1.2, and 1.3 were done together in one pass (same file, interface changes).
- Tasks 5.1, 6.1, and 7.1 were combined into the `_ColumnHeaderCell` StatefulWidget conversion.
- No new files created — all changes to existing `data_grid.dart` and `column_headers.dart`.
- No new providers or models introduced.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["2.1", "3.1"] },
    { "id": 2, "tasks": ["4"] },
    { "id": 3, "tasks": ["5.1", "6.1", "7.1", "8.1"] },
    { "id": 4, "tasks": ["9"] }
  ]
}
```
