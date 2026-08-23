/// Builds the display label for a fill menu item.
///
/// Returns `'Set all to {value}'` when no subset is selected (zero selected
/// or all selected). Returns `'Set selected to {value}'` when a proper
/// subset is selected.
///
/// Truncates [value] to 40 characters with ellipsis if it exceeds that length.
/// For the blank option, pass [isBlank] = true.
String buildFillMenuLabel({
  required String value,
  required int selectedCount,
  required int totalCount,
  bool isBlank = false,
}) {
  final scope = _isAllScope(selectedCount, totalCount) ? 'all' : 'selected';
  final displayValue = isBlank ? 'blank' : _truncateValue(value);
  return 'Set $scope to $displayValue';
}

bool _isAllScope(int selectedCount, int totalCount) {
  return selectedCount == 0 || selectedCount == totalCount;
}

String _truncateValue(String value) {
  if (value.length <= 40) return value;
  return '${value.substring(0, 40)}\u2026';
}
