/// Persisted configuration for column visibility, ordering, and widths.
class ColumnConfig {
  /// Creates a [ColumnConfig] with the given visible and ordered column IDs.
  const ColumnConfig({
    required this.visibleColumnIds,
    required this.columnOrder,
    this.widthOverrides = const {},
  });

  /// Ordered list of currently visible column IDs.
  final List<String> visibleColumnIds;

  /// Full ordered list of all column IDs (visible + hidden).
  /// Used to restore hidden columns to their original position.
  final List<String> columnOrder;

  /// User-set width overrides. Key: column ID, Value: width in logical pixels.
  /// Columns absent from this map use their [ColumnDefinition.defaultWidth].
  final Map<String, double> widthOverrides;

  /// Creates a copy with updated fields.
  ColumnConfig copyWith({
    List<String>? visibleColumnIds,
    List<String>? columnOrder,
    Map<String, double>? widthOverrides,
  }) {
    return ColumnConfig(
      visibleColumnIds: visibleColumnIds ?? this.visibleColumnIds,
      columnOrder: columnOrder ?? this.columnOrder,
      widthOverrides: widthOverrides ?? this.widthOverrides,
    );
  }
}
