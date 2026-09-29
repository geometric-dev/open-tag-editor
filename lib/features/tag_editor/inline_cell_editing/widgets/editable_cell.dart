import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/undo/undo_redo_manager.dart';
import '../../../../shared/services/taglib/taglib_types.dart';
import '../../../smart_fill_menu/data/build_fill_menu_items.dart';
import '../../../smart_fill_menu/data/collect_column_values.dart';
import '../../../smart_fill_menu/data/determine_target_paths.dart';
import '../../data/providers/file_list_provider.dart';
import '../../data/providers/filtered_sorted_file_list_provider.dart';
import '../../data/providers/selection_provider.dart';
import '../models/cell_coordinate.dart';
import '../providers/inline_cell_edit_provider.dart';
import '../utils/build_tag_edit_command.dart';
import '../utils/column_editability.dart';
import 'inline_text_field.dart';
import 'modified_cell_indicator.dart';

/// A cell widget that supports inline editing and a smart fill arrow.
///
/// Double-tap enters edit mode (row must be selected).
/// Single taps pass through to the row's InkWell for selection.
/// On hover, a fill arrow appears (right-aligned) for editable columns.
class EditableCell extends ConsumerStatefulWidget {
  const EditableCell({
    super.key,
    required this.coordinate,
    required this.value,
    required this.width,
    required this.isModified,
  });

  final CellCoordinate coordinate;
  final String value;
  final double width;
  final bool isModified;

  @override
  ConsumerState<EditableCell> createState() => EditableCellState();
}

/// State for [EditableCell] managing hover state for the fill arrow.
class EditableCellState extends ConsumerState<EditableCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(inlineCellEditProvider);
    final isEditing = editState.editingCell == widget.coordinate;
    final isFocused =
        editState.focusedCell == widget.coordinate && editState.showFocusBorder;
    final editable = isColumnEditable(widget.coordinate.columnId);
    final colorScheme = Theme.of(context).colorScheme;

    // Fill arrow is visible when: hovered, editable, and not in edit mode.
    final showFillArrow = _isHovered && editable && !isEditing;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: editable
          ? () {
              // Row selection guard: only enter edit mode if row is selected
              final files = ref.read(filteredSortedFileListProvider);
              if (widget.coordinate.rowIndex >= files.length) return;
              final filePath = files[widget.coordinate.rowIndex].path;
              final selection = ref.read(selectionProvider);
              if (!selection.isSelected(filePath)) return;

              ref
                  .read(inlineCellEditProvider.notifier)
                  .enterEditMode(widget.coordinate, prePopulate: true);
            }
          : null,
      child: MouseRegion(
        cursor: editable ? SystemMouseCursors.text : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          width: widget.width,
          decoration: BoxDecoration(
            border: isEditing
                ? Border.all(color: colorScheme.primary, width: 2)
                : isFocused
                ? Border.all(color: colorScheme.primary.withValues(alpha: 0.5))
                : null,
          ),
          child: Stack(
            children: [
              if (isEditing)
                InlineTextField(
                  initialValue: editState.currentValue ?? '',
                  selectAll: editState.selectAll,
                  width: widget.width,
                  field: widget.coordinate.columnId,
                  tagFormat: _getTagFormat(),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    widget.value,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (widget.isModified) const ModifiedCellIndicator(),
              if (showFillArrow)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _FillArrowButton(
                    onPressed: () => _onFillArrowPressed(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TagFormat? _getTagFormat() {
    final files = ref.read(filteredSortedFileListProvider);
    if (widget.coordinate.rowIndex >= files.length) return null;
    return files[widget.coordinate.rowIndex].tagFormat;
  }

  /// Handles the fill arrow press. Opens the smart fill menu.
  void _onFillArrowPressed(BuildContext context) {
    _openSmartFillMenu(context);
  }

  /// Opens the smart fill menu anchored to the fill arrow.
  ///
  /// Cancels any active inline edit, captures selection state at menu-open
  /// time, collects column values, and shows the popup menu. On value
  /// selection, applies the fill action via [buildTagEditCommand] and
  /// [UndoRedoManager].
  Future<void> _openSmartFillMenu(BuildContext context) async {
    // Cancel any active edit.
    final editState = ref.read(inlineCellEditProvider);
    if (editState.isEditing) {
      ref.read(inlineCellEditProvider.notifier).cancelEdit();
    }

    // Capture state at menu-open time.
    final files = ref.read(filteredSortedFileListProvider);
    final selection = ref.read(selectionProvider);
    final columnId = widget.coordinate.columnId;

    final values = collectColumnValues(files: files, columnId: columnId);
    final selectedCount = selection.selectedPaths.length;
    final totalCount = files.length;

    final items = buildFillMenuItems(
      values: values,
      selectedCount: selectedCount,
      totalCount: totalCount,
    );

    // Anchor menu to the fill arrow's render box position.
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final position = box.localToGlobal(Offset(box.size.width, 0));

    final chosen = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: items,
      constraints: values.length > 20
          ? const BoxConstraints(maxHeight: 280)
          : null,
    );

    if (chosen == null) return; // Dismissed without selection.

    // Apply the fill action.
    final targetPaths = determineTargetPaths(
      selectedPaths: selection.selectedPaths,
      allFiles: files,
    );

    final fileListNotifier = ref.read(fileListProvider.notifier);
    final command = buildTagEditCommand(
      fileListNotifier: fileListNotifier,
      filePaths: targetPaths,
      columnId: columnId,
      newValue: chosen,
      allFiles: files,
    );

    if (command != null) {
      ref.read(undoRedoProvider.notifier).execute(command);
    }
  }
}

/// A small icon button for the fill arrow, right-aligned within the cell.
///
/// Has a 24├ù24 dp minimum hit target. Does NOT propagate taps to the
/// parent GestureDetector (preventing inline edit mode from triggering).
class _FillArrowButton extends StatelessWidget {
  const _FillArrowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        iconSize: 14,
        splashRadius: 12,
        icon: Icon(
          Icons.arrow_drop_down,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
