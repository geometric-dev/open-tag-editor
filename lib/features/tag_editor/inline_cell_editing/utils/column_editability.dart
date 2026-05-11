/// Set of column IDs that are read-only and cannot be edited inline.
const readOnlyColumnIds = <String>{
  'tagIndicator',
  'filename',
  'bitrate',
  'duration',
  'relativePath',
};

/// Returns whether the given column supports inline editing.
///
/// Columns in [readOnlyColumnIds] are read-only and return false.
/// All other columns (tag fields) are editable.
bool isColumnEditable(String columnId) {
  return !readOnlyColumnIds.contains(columnId);
}
