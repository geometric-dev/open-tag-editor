import 'cell_coordinate.dart';

/// Represents the current inline editing state of the DataGrid.
class InlineCellEditState {
  /// Creates an [InlineCellEditState].
  const InlineCellEditState({
    this.focusedCell,
    this.editingCell,
    this.originalValue,
    this.currentValue,
    this.selectAll = false,
    this.showFocusBorder = false,
  });

  /// The cell that currently has keyboard focus (highlight shown).
  final CellCoordinate? focusedCell;

  /// The cell currently in edit mode (text field shown). Null if not editing.
  final CellCoordinate? editingCell;

  /// The original tag value when edit mode was entered.
  final String? originalValue;

  /// The current text field value (tracks user input).
  final String? currentValue;

  /// Whether all text should be selected on edit mode entry (F2).
  final bool selectAll;

  /// Whether the focus border should be rendered.
  ///
  /// True when focus was set via keyboard navigation (arrows, Tab).
  /// False when focus was set implicitly by row click selection.
  final bool showFocusBorder;

  /// Whether a cell is actively being edited.
  bool get isEditing => editingCell != null;

  /// Creates a copy with updated fields.
  ///
  /// Set [clearEditing] to true to reset all editing-related fields.
  InlineCellEditState copyWith({
    CellCoordinate? focusedCell,
    CellCoordinate? editingCell,
    String? originalValue,
    String? currentValue,
    bool? selectAll,
    bool? showFocusBorder,
    bool clearEditing = false,
  }) {
    return InlineCellEditState(
      focusedCell: focusedCell ?? this.focusedCell,
      editingCell: clearEditing ? null : (editingCell ?? this.editingCell),
      originalValue:
          clearEditing ? null : (originalValue ?? this.originalValue),
      currentValue: clearEditing ? null : (currentValue ?? this.currentValue),
      selectAll: clearEditing ? false : (selectAll ?? this.selectAll),
      showFocusBorder: showFocusBorder ?? this.showFocusBorder,
    );
  }
}
