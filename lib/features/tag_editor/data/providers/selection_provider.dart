import 'dart:math';

import 'package:flutter_riverpod/legacy.dart';

import '../models/selection_state.dart';

/// Builds a path-to-index map so navigation helpers avoid repeated O(n)
/// [List.indexOf] scans on large libraries (one pass per operation).
Map<String, int> buildIndexMap(List<String> orderedPaths) =>
    {for (var i = 0; i < orderedPaths.length; i++) orderedPaths[i]: i};

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
      activePath: path,
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

    final indexes = buildIndexMap(orderedPaths);
    // Missing paths map to -1, preserving the original indexOf fallback.
    final anchorIndex = indexes[anchor] ?? -1;
    final targetIndex = indexes[path] ?? -1;

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
      activePath: path,
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
    final current = state.activePath ?? state.anchorPath;
    if (current == null) {
      select(orderedPaths.first);
      return;
    }
    final currentIndex = orderedPaths.indexOf(current);
    if (currentIndex < 0) {
      select(orderedPaths.first);
      return;
    }
    if (currentIndex >= orderedPaths.length - 1) return;
    select(orderedPaths[currentIndex + 1]);
  }

  /// Move selection one row up (plain Up arrow).
  ///
  /// Selects only the previous row and sets it as the anchor.
  /// No-op if already at the first row or list is empty.
  void moveUp(List<String> orderedPaths) {
    if (orderedPaths.isEmpty) return;
    final current = state.activePath ?? state.anchorPath;
    if (current == null) {
      select(orderedPaths.first);
      return;
    }
    final currentIndex = orderedPaths.indexOf(current);
    if (currentIndex < 0) {
      select(orderedPaths.first);
      return;
    }
    if (currentIndex <= 0) return;
    select(orderedPaths[currentIndex - 1]);
  }

  /// Extend selection one row down (Shift+Down).
  ///
  /// Extends the selection edge away from the anchor downward, or contracts
  /// it if the edge is above the anchor.
  void extendDown(List<String> orderedPaths) {
    _extendSelection(orderedPaths, 1);
  }

  /// Extend selection one row up (Shift+Up).
  ///
  /// Extends the selection edge away from the anchor upward, or contracts
  /// it if the edge is below the anchor.
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
      activePath: orderedPaths.first,
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
      activePath: orderedPaths.last,
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

    final indexes = buildIndexMap(orderedPaths);
    // Missing paths map to -1, preserving the original indexOf fallback.
    final anchorIndex = indexes[anchor] ?? -1;
    final targetIndex = indexes[path] ?? -1;
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

    final anchorIndex = orderedPaths.indexOf(anchor);
    if (anchorIndex < 0) return;

    // The active end is where the selection extends from
    final active = state.activePath ?? anchor;
    final activeIndex = orderedPaths.indexOf(active);
    if (activeIndex < 0) return;

    final newActiveIndex = activeIndex + direction;
    if (newActiveIndex < 0 || newActiveIndex >= orderedPaths.length) return;

    // Build the range from anchor to new active
    final start = min(anchorIndex, newActiveIndex);
    final end = max(anchorIndex, newActiveIndex);
    final rangePaths = orderedPaths.sublist(start, end + 1).toSet();

    state = SelectionState(
      selectedPaths: rangePaths,
      anchorPath: anchor,
      activePath: orderedPaths[newActiveIndex],
    );
  }
}
