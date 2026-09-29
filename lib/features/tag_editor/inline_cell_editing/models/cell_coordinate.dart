/// Identifies a single cell in the DataGrid by row index and column ID.
class CellCoordinate {
  /// Creates a [CellCoordinate] with the given [rowIndex] and [columnId].
  const CellCoordinate({required this.rowIndex, required this.columnId});

  /// Index into the filtered/sorted file list.
  final int rowIndex;

  /// Column identifier (e.g., 'title', 'artist').
  final String columnId;

  @override
  bool operator ==(Object other) =>
      other is CellCoordinate &&
      other.rowIndex == rowIndex &&
      other.columnId == columnId;

  @override
  int get hashCode => Object.hash(rowIndex, columnId);

  @override
  String toString() => 'CellCoordinate(row: $rowIndex, column: $columnId)';
}
