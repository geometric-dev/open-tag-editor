import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../data/providers/column_config_provider.dart';
import '../../data/providers/file_list_provider.dart';
import '../../data/providers/filtered_sorted_file_list_provider.dart';
import '../../data/providers/selection_provider.dart';
import '../models/cell_coordinate.dart';
import '../models/inline_cell_edit_state.dart';
import '../utils/build_tag_edit_command.dart';
import '../utils/cell_navigation.dart';
import '../utils/column_editability.dart';

/// Manages the inline cell editing lifecycle.
class InlineCellEditNotifier extends StateNotifier<InlineCellEditState> {
  /// Creates an [InlineCellEditNotifier] with the given [ref].
  InlineCellEditNotifier({required this.ref})
      : super(const InlineCellEditState());

  /// Riverpod ref for accessing other providers.
  final Ref ref;

  /// Enters edit mode on the given cell.
  ///
  /// [prePopulate] fills the text field with the current tag value.
  /// [selectAll] selects all text (used for F2 entry).
  /// [initialCharacter] starts with just that character (typing entry).
  void enterEditMode(
    CellCoordinate cell, {
    bool prePopulate = false,
    bool selectAll = false,
    String? initialCharacter,
  }) {
    // Guard: don't edit read-only columns
    if (!isColumnEditable(cell.columnId)) return;

    // Guard: validate row index
    final files = ref.read(filteredSortedFileListProvider);
    if (cell.rowIndex < 0 || cell.rowIndex >= files.length) return;

    // Guard: row must be selected (select-then-edit workflow)
    final selection = ref.read(selectionProvider);
    final filePath = files[cell.rowIndex].path;
    if (!selection.isSelected(filePath)) return;

    // If already editing a different cell, confirm the current edit first
    if (state.isEditing && state.editingCell != cell) {
      _confirmEditInternal();
    }

    final file = files[cell.rowIndex];
    final currentValue = file.tags[cell.columnId] ?? '';

    if (initialCharacter != null) {
      state = InlineCellEditState(
        focusedCell: cell,
        editingCell: cell,
        originalValue: currentValue,
        currentValue: initialCharacter,
        selectAll: false,
      );
    } else {
      state = InlineCellEditState(
        focusedCell: cell,
        editingCell: cell,
        originalValue: currentValue,
        currentValue: prePopulate ? currentValue : '',
        selectAll: selectAll,
      );
    }
  }

  /// Confirms the current edit and applies the value.
  ///
  /// [batchMode] forces batch application without prompt (Ctrl+Enter).
  /// [clearFocus] clears the focused cell state (used on focus loss).
  /// Returns true if the edit was applied (value changed), false otherwise.
  bool confirmEdit({bool batchMode = false, bool clearFocus = false}) {
    return _confirmEditInternal(
      batchMode: batchMode,
      clearFocus: clearFocus,
    );
  }

  /// Cancels the current edit, restoring the original value.
  void cancelEdit() {
    state = InlineCellEditState(
      focusedCell: state.focusedCell,
    );
  }

  /// Updates the current text value as the user types.
  void updateValue(String value) {
    if (!state.isEditing) return;
    state = InlineCellEditState(
      focusedCell: state.focusedCell,
      editingCell: state.editingCell,
      originalValue: state.originalValue,
      currentValue: value,
      selectAll: false,
    );
  }

  /// Moves focus to the given cell (without entering edit mode).
  ///
  /// [showBorder] controls whether the focus border is rendered.
  /// Keyboard navigation sets this to true; mouse clicks set it to false.
  void moveFocus(CellCoordinate cell, {bool showBorder = true}) {
    if (state.isEditing) {
      _confirmEditInternal();
    }
    state = InlineCellEditState(
      focusedCell: cell,
      showFocusBorder: showBorder,
    );
  }

  /// Clears the focused cell state (removes focus border).
  void clearFocus() {
    if (state.isEditing) {
      _confirmEditInternal(clearFocus: true);
    } else {
      state = const InlineCellEditState();
    }
  }

  /// Navigates to the next editable cell (Tab).
  void navigateNext() {
    _confirmEditInternal();
    final current = state.focusedCell;
    if (current == null) return;

    final config = ref.read(columnConfigProvider);
    final files = ref.read(filteredSortedFileListProvider);

    final target = nextEditableColumn(
      current,
      config.visibleColumnIds,
      files.length,
    );

    if (target != null) {
      enterEditMode(target, prePopulate: true, selectAll: true);
    }
  }

  /// Navigates to the previous editable cell (Shift+Tab).
  void navigatePrevious() {
    _confirmEditInternal();
    final current = state.focusedCell;
    if (current == null) return;

    final config = ref.read(columnConfigProvider);
    final files = ref.read(filteredSortedFileListProvider);

    final target = previousEditableColumn(
      current,
      config.visibleColumnIds,
      files.length,
    );

    if (target != null) {
      enterEditMode(target, prePopulate: true, selectAll: true);
    }
  }

  /// Navigates to the same column in the next row (Enter after confirm).
  void navigateDown() {
    final current = state.focusedCell;
    if (current == null) return;

    final files = ref.read(filteredSortedFileListProvider);
    if (current.rowIndex < files.length - 1) {
      final target = CellCoordinate(
        rowIndex: current.rowIndex + 1,
        columnId: current.columnId,
      );
      enterEditMode(target, prePopulate: true, selectAll: true);
    }
  }

  /// Internal confirm logic. Returns true if a command was executed.
  bool _confirmEditInternal({bool batchMode = false, bool clearFocus = false}) {
    if (!state.isEditing) return false;

    final newValue = state.currentValue ?? '';
    final editingCell = state.editingCell!;

    // Exit edit mode first
    final focusedCell = clearFocus ? null : state.focusedCell;
    state = InlineCellEditState(focusedCell: focusedCell);

    // No-op check for single file
    final selection = ref.read(selectionProvider);
    final files = ref.read(filteredSortedFileListProvider);
    final fileListNotifier = ref.read(fileListProvider.notifier);

    // Determine affected file paths
    List<String> filePaths;
    if (batchMode && selection.selectedPaths.length > 1) {
      filePaths = selection.selectedPaths.toList();
    } else {
      if (editingCell.rowIndex >= files.length) return false;
      filePaths = [files[editingCell.rowIndex].path];
    }

    // Build and execute the command
    final command = buildTagEditCommand(
      fileListNotifier: fileListNotifier,
      filePaths: filePaths,
      columnId: editingCell.columnId,
      newValue: newValue,
      allFiles: files,
    );

    if (command == null) return false;

    ref.read(undoRedoProvider.notifier).execute(command);
    return true;
  }
}
