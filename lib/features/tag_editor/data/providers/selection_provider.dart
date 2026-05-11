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

  /// Move selection one row down (plain Down arrow).
  ///
  /// Selects only the next row and sets it as the anchor.
  /// No-op if already at the last row or list is empty.
  void moveDown(List<String> orderedPaths) {
    if (orderedPaths.isEmpty) return;
    final anchor = state.anchorPath;
    if (anchor == null) {
      select(orderedPaths.first);
      return;
    }
    final currentIndex = orderedPaths.indexOf(anchor);
    if (currentIndex < 0 || currentIndex >= orderedPaths.length - 1) return;
    select(orderedPaths[currentIndex + 1]);
  }

  /// Move selection one row up (plain Up arrow).
  ///
  /// Selects only the previous row and sets it as the anchor.
  /// No-op if already at the first row or list is empty.
  void moveUp(List<String> orderedPaths) {
    if (orderedPaths.isEmpty) return;
    final anchor = state.anchorPath;
    if (anchor == null) {
      select(orderedPaths.last);
      return;
    }
    final currentIndex = orderedPaths.indexOf(anchor);
    if (currentIndex <= 0) return;
    select(orderedPaths[currentIndex - 1]);
  }

  /// Extend selection one row down (Shift+Down).
  ///
  /// Adds the row below the current selection edge without changing the anchor.
  void extendDown(List<String> orderedPaths) {
    _extendSelection(orderedPaths, 1);
  }

  /// Extend selection one row up (Shift+Up).
  ///
  /// Adds the row above the current selection edge without changing the anchor.
  void extendUp(List<String> orderedPaths) {
    _extendSelection(orderedPaths, -1);
  }

  /// Extend selection from anchor to the first row (Ctrl+Shift+Home).
  void extendToStart(List<String> orderedPaths) {
    final anchor = state.anchorPath;
    if (anchor == null || orderedPaths.isEmpty) return;
    final anchorIndex = orderedPaths.indexOf(anchor);
    if (anchorIndex < 0) return;

    final rangePaths = orderedPaths.sublist(0, anchorIndex + 1).toSet();
    state = SelectionState(
      selectedPaths: rangePaths,
      anchorPath: anchor,
    );
  }

  /// Extend selection from anchor to the last row (Ctrl+Shift+End).
  void extendToEnd(List<String> orderedPaths) {
    final anchor = state.anchorPath;
    if (anchor == null || orderedPaths.isEmpty) return;
    final anchorIndex = orderedPaths.indexOf(anchor);
    if (anchorIndex < 0) return;

    final rangePaths = orderedPaths.sublist(anchorIndex).toSet();
    state = SelectionState(
      selectedPaths: rangePaths,
      anchorPath: anchor,
    );
  }

  /// Ctrl+Shift+click: add contiguous range from anchor to target
  /// to the existing selection.
  void addRangeSelect(String path, List<String> orderedPaths) {
    final anchor = state.anchorPath;
    if (anchor == null) {
      toggleSelect(path);
      return;
    }

    final anchorIndex = orderedPaths.indexOf(anchor);
    final targetIndex = orderedPaths.indexOf(path);
    if (anchorIndex < 0 || targetIndex < 0) return;

    final start = min(anchorIndex, targetIndex);
    final end = max(anchorIndex, targetIndex);
    final rangePaths = orderedPaths.sublist(start, end + 1).toSet();

    state = SelectionState(
      selectedPaths: state.selectedPaths.union(rangePaths),
      anchorPath: anchor,
    );
  }

  /// Replace the entire selection with the given paths (used by marquee).
  void replaceSelection(Set<String> paths) {
    state = SelectionState(
      selectedPaths: paths,
      anchorPath: paths.isNotEmpty ? paths.first : null,
    );
  }

  /// Add paths to the existing selection (Ctrl+marquee).
  void addToSelection(Set<String> paths) {
    state = SelectionState(
      selectedPaths: state.selectedPaths.union(paths),
      anchorPath: state.anchorPath,
    );
  }

  void _extendSelection(List<String> orderedPaths, int direction) {
    final anchor = state.anchorPath;
    if (anchor == null || orderedPaths.isEmpty) return;

    final selectedIndices = state.selectedPaths
        .map((p) => orderedPaths.indexOf(p))
        .where((i) => i >= 0)
        .toList()
      ..sort();

    if (selectedIndices.isEmpty) return;

    final edgeIndex =
        direction > 0 ? selectedIndices.last : selectedIndices.first;
    final newIndex = edgeIndex + direction;
    if (newIndex < 0 || newIndex >= orderedPaths.length) return;

    final newPaths = Set<String>.from(state.selectedPaths)
      ..add(orderedPaths[newIndex]);

    state = SelectionState(
      selectedPaths: newPaths,
      anchorPath: anchor,
    );
  }
}
