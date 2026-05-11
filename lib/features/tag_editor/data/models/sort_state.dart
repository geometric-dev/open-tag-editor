/// Represents the current sort configuration for the file list.
class SortState {
  /// Creates a [SortState]. Both fields null means unsorted (original load order).
  const SortState({this.columnId, this.direction});

  /// The column being sorted, or null for original load order.
  final String? columnId;

  /// Sort direction, or null for unsorted.
  final SortDirection? direction;

  /// Whether the list is currently sorted.
  bool get isSorted => columnId != null && direction != null;
}

/// Sort direction for a column.
enum SortDirection {
  /// A→Z, 0→9, earliest→latest.
  ascending,

  /// Z→A, 9→0, latest→earliest.
  descending,
}
