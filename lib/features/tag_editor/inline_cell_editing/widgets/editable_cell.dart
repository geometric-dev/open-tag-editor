import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/filtered_sorted_file_list_provider.dart';
import '../../data/providers/selection_provider.dart';
import '../models/cell_coordinate.dart';
import '../providers/inline_cell_edit_provider.dart';
import '../utils/column_editability.dart';
import 'inline_text_field.dart';
import 'modified_cell_indicator.dart';

/// A cell widget that supports inline editing.
///
/// Renders either a static text display or an [InlineTextField] depending
/// on whether this cell is the active edit cell.
class EditableCell extends ConsumerWidget {
  const EditableCell({
    super.key,
    required this.coordinate,
    required this.value,
    required this.width,
    required this.isModified,
  });

  /// The cell's position in the grid.
  final CellCoordinate coordinate;

  /// The current display value for this cell.
  final String value;

  /// The cell width in logical pixels.
  final double width;

  /// Whether this cell's value differs from the on-disk value.
  final bool isModified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editState = ref.watch(inlineCellEditProvider);
    final isEditing = editState.editingCell == coordinate;
    final isFocused = editState.focusedCell == coordinate;
    final editable = isColumnEditable(coordinate.columnId);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onDoubleTap: editable
          ? () {
              // Row selection guard: only enter edit mode if row is selected
              final files = ref.read(filteredSortedFileListProvider);
              if (coordinate.rowIndex >= files.length) return;
              final filePath = files[coordinate.rowIndex].path;
              final selection = ref.read(selectionProvider);
              if (!selection.isSelected(filePath)) return;

              ref
                  .read(inlineCellEditProvider.notifier)
                  .enterEditMode(coordinate, prePopulate: true);
            }
          : null,
      onTap: () =>
          ref.read(inlineCellEditProvider.notifier).moveFocus(coordinate),
      child: MouseRegion(
        cursor: editable
            ? SystemMouseCursors.text
            : SystemMouseCursors.forbidden,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            border: isEditing
                ? Border.all(color: colorScheme.primary, width: 2)
                : isFocused
                    ? Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.5),
                      )
                    : null,
          ),
          child: Stack(
            children: [
              if (isEditing)
                InlineTextField(
                  initialValue: editState.currentValue ?? '',
                  selectAll: editState.selectAll,
                  width: width,
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (isModified) const ModifiedCellIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
