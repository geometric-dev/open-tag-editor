/// Utility functions for marquee (rubber-band) selection in the DataGrid.
library;

/// Computes which row indices are intersected by the marquee rectangle.
///
/// [marqueeTop] and [marqueeBottom] are in scroll-content coordinates
/// (accounting for scroll offset).
/// [rowHeight] is the fixed height of each row.
/// [totalRows] is the total number of rows in the list.
///
/// Returns the set of row indices whose vertical bounds overlap the marquee.
Set<int> computeMarqueeIntersectedRows({
  required double marqueeTop,
  required double marqueeBottom,
  required double rowHeight,
  required int totalRows,
}) {
  if (totalRows == 0 || rowHeight <= 0) return {};

  final top = marqueeTop < marqueeBottom ? marqueeTop : marqueeBottom;
  final bottom = marqueeTop < marqueeBottom ? marqueeBottom : marqueeTop;

  final firstRow = (top / rowHeight).floor().clamp(0, totalRows - 1);
  final lastRow = (bottom / rowHeight).floor().clamp(0, totalRows - 1);

  return {for (var i = firstRow; i <= lastRow; i++) i};
}
