import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/selection_state.dart';

/// Provider for the file selection state.
final selectionProvider =
    StateNotifierProvider<SelectionNotifier, SelectionState>((ref) {
  return SelectionNotifier();
});

/// Manages file selection with support for single click, Ctrl+click,
/// Shift+click range, and select-all operations.
class SelectionNotifier extends StateNotifier<SelectionState> {
  SelectionNotifier() : super(const SelectionState());

  /// Single click: select only this file, set as anchor.
  void select(String path) {
    state = SelectionState(
      selectedPaths: {path},
      anchorPath: path,
    );
  }

  /// Ctrl+click: toggle this file's selection without affecting others.
  void toggleSelect(String path) {
    final current = Set<String>.from(state.selectedPaths);
    if (current.contains(path)) {
      current.remove(path);
    } else {
      current.add(path);
    }
    state = SelectionState(
      selectedPaths: current,
      anchorPath: path,
    );
  }

  /// Shift+click: select contiguous range from anchor to target.
  ///
  /// [orderedPaths] is the current visible file list order used to
  /// determine the range between anchor and target.
  void rangeSelect(String path, List<String> orderedPaths) {
    final anchor = state.anchorPath;
    if (anchor == null) {
      select(path);
      return;
    }

    final anchorIndex = orderedPaths.indexOf(anchor);
    final targetIndex = orderedPaths.indexOf(path);

    if (anchorIndex < 0 || targetIndex < 0) {
      select(path);
      return;
    }

    final start = min(anchorIndex, targetIndex);
    final end = max(anchorIndex, targetIndex);
    final rangePaths = orderedPaths.sublist(start, end + 1).toSet();

    state = SelectionState(
      selectedPaths: rangePaths,
      anchorPath: anchor,
    );
  }

  /// Select all provided paths (Ctrl+A).
  void selectAll(List<String> paths) {
    state = SelectionState(
      selectedPaths: paths.toSet(),
      anchorPath: state.anchorPath,
    );
  }

  /// Clear all selection.
  void clear() {
    state = const SelectionState();
  }
}
