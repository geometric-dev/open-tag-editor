# Requirements Document

## Introduction

Table UX & Performance improves the data grid in Open Tag Editor to feel native-fast and visually polished. The current implementation lacks hover feedback on column headers, has subtle sort indicators that are easy to miss, performs redundant per-row computations on every frame, and misses common desktop-table affordances like zebra striping and header tooltips. This spec addresses visual polish, interaction feedback, and rendering performance in a single cohesive pass.

## Glossary

- **Data_Grid**: The main table widget that displays audio file metadata in rows and columns, supporting horizontal scrolling and virtualized rendering via `ListView.builder` with fixed item extent.
- **Column_Header**: The top row of the Data_Grid displaying column labels and providing interaction targets for resize, sort, and context menu actions.
- **Sort_Indicator**: The icon displayed in a Column_Header cell when that column is the active sort key, showing sort direction (ascending/descending).
- **Effective_Width_List**: A pre-computed list of resolved column widths (override or default) calculated once per build cycle and shared across all rows.
- **Zebra_Striping**: Alternating subtle background tint on even/odd rows to improve visual scanability.
- **RepaintBoundary**: A Flutter widget that isolates its subtree into a separate compositing layer, preventing unnecessary repaints of sibling widgets.

## Requirements

### Requirement 1: Column Header Hover State

**User Story:** As a user, I want column headers to visually respond when I hover over them, so that I can tell they are interactive (sortable/resizable).

#### Acceptance Criteria

1. WHEN the pointer enters a sortable Column_Header cell, THE cell SHALL display a subtle background highlight using `colorScheme.onSurface` at 0.05 opacity.
2. WHEN the pointer leaves a Column_Header cell, THE highlight SHALL be removed immediately.
3. THE Tag_Indicator column header SHALL NOT display a hover highlight (it is not sortable).
4. THE hover highlight SHALL NOT interfere with the resize handle cursor or drag behaviour.

### Requirement 2: Improved Sort Indicators

**User Story:** As a user, I want sort indicators to be clearly visible and distinguishable from the column label, so that I can immediately see which column is sorted and in which direction.

#### Acceptance Criteria

1. WHEN a column is the active sort key, THE Sort_Indicator icon SHALL be rendered at 14 logical pixels using `colorScheme.primary` colour.
2. WHEN a column is the active sort key, THE Column_Header cell SHALL display a subtle background tint using `colorScheme.primary` at 0.08 opacity to distinguish it from unsorted columns.
3. WHEN the sort direction is ascending, THE Sort_Indicator SHALL display an upward arrow icon.
4. WHEN the sort direction is descending, THE Sort_Indicator SHALL display a downward arrow icon.
5. WHEN a column is not the active sort key, THE Column_Header cell SHALL NOT display any sort icon or tint.

### Requirement 3: Column Header Tooltips

**User Story:** As a user, I want to see the full column name in a tooltip when the header text is truncated, so that I can identify narrow columns.

#### Acceptance Criteria

1. EACH sortable Column_Header cell SHALL wrap its label in a Tooltip widget displaying the full column label text.
2. THE Tooltip SHALL appear after the platform-default hover delay.
3. THE Tag_Indicator column SHALL NOT display a tooltip (it has no label).

### Requirement 4: Zebra Striping

**User Story:** As a user, I want alternating row backgrounds so that I can visually track across wide rows without losing my place.

#### Acceptance Criteria

1. THE Data_Grid SHALL apply a subtle background tint to even-indexed rows using `colorScheme.onSurface` at 0.03 opacity.
2. Odd-indexed rows SHALL have a transparent background (no tint).
3. WHEN a row is selected, THE selection highlight SHALL take precedence over the zebra stripe.
4. THE zebra stripe SHALL be applied based on the row's visual index in the current sorted/filtered list, not the file's original load order.

### Requirement 5: Pre-computed Effective Widths

**User Story:** As a user, I want the table to scroll smoothly without dropped frames, so that resizing and scrolling feel native.

#### Acceptance Criteria

1. THE _ScrollableDataGrid SHALL compute the Effective_Width_List once per build cycle (when `visibleColumns` or `widthOverrides` change) and pass it to child widgets.
2. Individual _DataRow widgets SHALL NOT call `resolveEffectiveWidth` — they SHALL read from the pre-computed Effective_Width_List.
3. THE ColumnHeaders widget SHALL receive the same Effective_Width_List rather than computing widths independently.
4. THE total grid width SHALL be derived from summing the Effective_Width_List.

### Requirement 6: RepaintBoundary on Column Headers

**User Story:** As a user, I want the column headers to not repaint during vertical scrolling, so that scroll performance is maximised.

#### Acceptance Criteria

1. THE ColumnHeaders widget SHALL be wrapped in a RepaintBoundary to isolate it from the vertically-scrolling list body.
2. THE RepaintBoundary SHALL NOT prevent the header from repainting when column widths, sort state, or visibility change.

### Requirement 7: Selective Rebuild for Inline Edit State

**User Story:** As a user, I want editing one cell to not cause all other rows to rebuild, so that entering/exiting edit mode feels instant.

#### Acceptance Criteria

1. EACH _DataRow SHALL use a Riverpod `select` on the inline edit provider to watch only whether its own row index is the actively-edited row.
2. WHEN a cell enters or exits edit mode, ONLY the affected row (and the previously-edited row, if different) SHALL rebuild.
3. THE Data_Grid's overall scroll performance with 500+ rows SHALL NOT degrade when a cell is in edit mode.
