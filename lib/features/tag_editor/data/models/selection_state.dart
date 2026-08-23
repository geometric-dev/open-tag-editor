/// Represents the current file selection state in the file list.
///
/// Tracks both the set of selected file paths and the anchor path
/// used for Shift+click range selection.
class SelectionState {
  /// Creates a [SelectionState].
  const SelectionState({
    this.selectedPaths = const {},
    this.anchorPath,
    this.activePath,
  });

  /// The set of currently selected file paths.
  final Set<String> selectedPaths;

  /// The last single-clicked path, used as the anchor for Shift+click range selection.
  final String? anchorPath;

  /// The current active end of the selection range (moves with Shift+arrow).
  ///
  /// When null, defaults to [anchorPath] for range calculations.
  final String? activePath;

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
    String? activePath,
    bool clearActivePath = false,
  }) {
    return SelectionState(
      selectedPaths: selectedPaths ?? this.selectedPaths,
      anchorPath: anchorPath ?? this.anchorPath,
      activePath: clearActivePath ? null : (activePath ?? this.activePath),
    );
  }
}
