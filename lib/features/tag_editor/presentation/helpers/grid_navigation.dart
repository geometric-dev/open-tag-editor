import '../../data/models/grid_item.dart';

/// Returns the index of the next [FileGridItem] after [currentIndex],
/// or null if there is no file row after the current position.
///
/// Searches forward from [currentIndex] + 1 through the list. Returns
/// null if [currentIndex] is out of bounds (>= items.length - 1 or < 0).
int? nextFileRowIndex(List<GridItem> items, int currentIndex) {
  if (currentIndex < 0 || currentIndex >= items.length - 1) return null;

  for (var i = currentIndex + 1; i < items.length; i++) {
    if (items[i] is FileGridItem) return i;
  }
  return null;
}

/// Returns the index of the previous [FileGridItem] before [currentIndex],
/// or null if there is no file row before the current position.
///
/// Searches backward from [currentIndex] - 1 through the list. Returns
/// null if [currentIndex] is out of bounds (<= 0 or >= items.length).
int? previousFileRowIndex(List<GridItem> items, int currentIndex) {
  if (currentIndex <= 0 || currentIndex >= items.length) return null;

  for (var i = currentIndex - 1; i >= 0; i--) {
    if (items[i] is FileGridItem) return i;
  }
  return null;
}

/// Extracts an ordered list of file paths from grid items,
/// excluding all separator items.
///
/// Iterates through [items] and collects the file path from each
/// [FileGridItem], skipping any [SeparatorGridItem] entries.
List<String> filePathsFromGridItems(List<GridItem> items) {
  return [
    for (final item in items)
      if (item is FileGridItem) item.file.path,
  ];
}
