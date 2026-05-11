import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sort_state.dart';

/// Provider for the file list sort state.
final sortStateProvider =
    StateNotifierProvider<SortStateNotifier, SortState>((ref) {
  return SortStateNotifier();
});

/// Manages the sort state with a three-click cycle:
/// unsorted → ascending → descending → unsorted.
class SortStateNotifier extends StateNotifier<SortState> {
  SortStateNotifier() : super(const SortState());

  /// Toggles sort on the given [columnId].
  ///
  /// - If currently unsorted or sorted by a different column: sort ascending.
  /// - If currently ascending on this column: switch to descending.
  /// - If currently descending on this column: return to unsorted.
  void toggleSort(String columnId) {
    if (state.columnId != columnId) {
      // Different column or unsorted → ascending
      state = SortState(columnId: columnId, direction: SortDirection.ascending);
    } else if (state.direction == SortDirection.ascending) {
      // Same column, ascending → descending
      state = SortState(columnId: columnId, direction: SortDirection.descending);
    } else {
      // Same column, descending → unsorted
      state = const SortState();
    }
  }
}
