import 'models/column_definition.dart';

/// Returns the effective display width for a column.
///
/// If [widthOverrides] contains an entry for [columnId], returns that value.
/// Otherwise returns the column's [ColumnDefinition.defaultWidth].
double resolveEffectiveWidth(
  String columnId,
  Map<String, double> widthOverrides,
  List<ColumnDefinition> columns,
) {
  if (widthOverrides.containsKey(columnId)) {
    return widthOverrides[columnId]!;
  }
  return columns
      .firstWhere((c) => c.id == columnId, orElse: () => columns.first)
      .defaultWidth;
}

/// Calculates the optimal column width to fit content.
///
/// Takes the measured widths of all visible cell values and the header label,
/// returns the result clamped to [minWidth, maxWidth].
double calculateAutoFitWidth({
  required List<double> cellWidths,
  required double headerLabelWidth,
  double minWidth = 40.0,
  double maxWidth = 500.0,
  double padding = 16.0,
}) {
  final maxContent = <double>[headerLabelWidth, ...cellWidths]
      .fold(0.0, (max, w) => w > max ? w : max);
  return (maxContent + padding).clamp(minWidth, maxWidth);
}
