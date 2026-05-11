import '../models/cell_coordinate.dart';
import 'column_editability.dart';

/// Returns the next editable column coordinate after [current].
///
/// Skips read-only columns. Wraps to the first editable column of the
/// next row when at the end of the current row.
/// Returns null if there are no editable columns or no next row.
CellCoordinate? nextEditableColumn(
  CellCoordinate current,
  List<String> visibleColumnIds,
  int totalRows,
) {
  final editableIds =
      visibleColumnIds.where(isColumnEditable).toList();
  if (editableIds.isEmpty) return null;

  final currentIndex = editableIds.indexOf(current.columnId);
  if (currentIndex >= 0 && currentIndex < editableIds.length - 1) {
    // Next column in same row
    return CellCoordinate(
      rowIndex: current.rowIndex,
      columnId: editableIds[currentIndex + 1],
    );
  }
  // Wrap to next row
  if (current.rowIndex < totalRows - 1) {
    return CellCoordinate(
      rowIndex: current.rowIndex + 1,
      columnId: editableIds.first,
    );
  }
  return null; // At last cell of last row
}

/// Returns the previous editable column coordinate before [current].
///
/// Skips read-only columns. Wraps to the last editable column of the
/// previous row when at the start of the current row.
/// Returns null if there are no editable columns or no previous row.
CellCoordinate? previousEditableColumn(
  CellCoordinate current,
  List<String> visibleColumnIds,
  int totalRows,
) {
  final editableIds =
      visibleColumnIds.where(isColumnEditable).toList();
  if (editableIds.isEmpty) return null;

  final currentIndex = editableIds.indexOf(current.columnId);
  if (currentIndex > 0) {
    // Previous column in same row
    return CellCoordinate(
      rowIndex: current.rowIndex,
      columnId: editableIds[currentIndex - 1],
    );
  }
  // Wrap to previous row
  if (current.rowIndex > 0) {
    return CellCoordinate(
      rowIndex: current.rowIndex - 1,
      columnId: editableIds.last,
    );
  }
  return null; // At first cell of first row
}
