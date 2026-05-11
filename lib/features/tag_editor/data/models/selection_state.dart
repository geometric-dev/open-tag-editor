/// Represents the current file selection state in the file list.
///
/// Tracks both the set of selected file paths and the anchor path
/// used for Shift+click range selection.
class SelectionState {
  /// Creates a [SelectionState].
  const SelectionState({
    this.selectedPaths = const {},
    this.anchorPath,
  });

  /// The set of currently selected file paths.
  final Set<String> selectedPaths;

  /// The last single-clicked path, used as the anchor for Shift+click range selection.
  final String? anchorPath;

  /// Whether any files are selected.
  bool get hasSelection => selectedPaths.isNotEmpty;

  /// The number of selected files.
  int get count => selectedPaths.length;

  /// Whether the given [path] is selected.
  bool isSelected(String path) => selectedPaths.contains(path);

  /// Creates a copy with updated fields.
  SelectionState copyWith({
    Set<String>? selectedPaths,
    String? anchorPath,
  }) {
    return SelectionState(
      selectedPaths: selectedPaths ?? this.selectedPaths,
      anchorPath: anchorPath ?? this.anchorPath,
    );
  }
}
