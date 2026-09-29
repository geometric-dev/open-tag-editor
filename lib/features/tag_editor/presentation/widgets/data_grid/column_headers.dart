import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/column_definition.dart';
import '../../../data/models/sort_state.dart';
import '../../../data/providers/column_config_provider.dart';
import '../../../data/providers/sort_state_provider.dart';
import 'resize_handle.dart';

/// Column header row for the data grid.
///
/// Supports click-to-sort with visible sort indicators, hover feedback,
/// tooltips, right-click context menu for show/hide, drag-to-resize columns,
/// and double-click to auto-fit.
class ColumnHeaders extends ConsumerWidget {
  const ColumnHeaders({
    super.key,
    required this.effectiveWidths,
    this.onAutoFit,
    this.hasSelection = false,
    this.onRemoveSelected,
  });

  /// Pre-computed widths for each visible column, in display order.
  final List<double> effectiveWidths;

  /// Callback to auto-fit a column to its content width.
  /// Called with the column ID when the resize handle is double-clicked.
  final void Function(String columnId)? onAutoFit;

  /// Whether any files are currently selected.
  final bool hasSelection;

  /// Callback to remove selected files from the list.
  final VoidCallback? onRemoveSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(columnConfigProvider);
    final sortState = ref.watch(sortStateProvider);

    // Get visible column definitions in order
    final visibleColumns = config.visibleColumnIds
        .map(
          (id) => defaultColumns.firstWhere(
            (c) => c.id == id,
            orElse: () => defaultColumns.first,
          ),
        )
        .toList();

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: List.generate(visibleColumns.length, (i) {
          final column = visibleColumns[i];
          final width = i < effectiveWidths.length
              ? effectiveWidths[i]
              : column.defaultWidth;
          return _ColumnHeaderCell(
            columnIndex: i,
            column: column,
            effectiveWidth: width,
            sortState: sortState,
            onSort: () =>
                ref.read(sortStateProvider.notifier).toggleSort(column.id),
            onToggleVisibility: (columnId) => ref
                .read(columnConfigProvider.notifier)
                .toggleVisibility(columnId),
            onResize: (newWidth) => ref
                .read(columnConfigProvider.notifier)
                .setColumnWidth(column.id, newWidth),
            onResizeEnd: () =>
                ref.read(columnConfigProvider.notifier).persistWidths(),
            onAutoFit: () => onAutoFit?.call(column.id),
            onResetWidths: () =>
                ref.read(columnConfigProvider.notifier).resetColumnWidths(),
            onReorder: (oldIndex, newIndex) => ref
                .read(columnConfigProvider.notifier)
                .reorderColumn(oldIndex, newIndex),
            allColumns: defaultColumns,
            visibleColumnIds: config.visibleColumnIds,
            hasSelection: hasSelection,
            onRemoveSelected: onRemoveSelected,
          );
        }),
      ),
    );
  }
}

/// A single column header cell with hover feedback, sort indicator,
/// tooltip, resize handle, and context menu.
class _ColumnHeaderCell extends StatefulWidget {
  const _ColumnHeaderCell({
    required this.columnIndex,
    required this.column,
    required this.effectiveWidth,
    required this.sortState,
    required this.onSort,
    required this.onToggleVisibility,
    required this.onResize,
    required this.onResizeEnd,
    required this.onAutoFit,
    required this.onResetWidths,
    required this.onReorder,
    required this.allColumns,
    required this.visibleColumnIds,
    this.hasSelection = false,
    this.onRemoveSelected,
  });

  /// Display index of this column within the visible columns.
  final int columnIndex;

  final ColumnDefinition column;
  final double effectiveWidth;
  final SortState sortState;
  final VoidCallback onSort;
  final void Function(String columnId) onToggleVisibility;
  final void Function(double newWidth) onResize;
  final VoidCallback onResizeEnd;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final VoidCallback onAutoFit;
  final VoidCallback onResetWidths;
  final List<ColumnDefinition> allColumns;
  final List<String> visibleColumnIds;
  final bool hasSelection;
  final VoidCallback? onRemoveSelected;

  @override
  State<_ColumnHeaderCell> createState() => _ColumnHeaderCellState();
}

class _ColumnHeaderCellState extends State<_ColumnHeaderCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSorted = widget.sortState.columnId == widget.column.id;
    final isResizable = widget.column.id != 'tagIndicator';
    final isSortable = widget.column.id != 'tagIndicator';

    // Determine background colour: sorted tint > hover tint > none
    Color? backgroundColor;
    if (isSorted) {
      backgroundColor = Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.08);
    } else if (_isHovered && isSortable) {
      backgroundColor = Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.05);
    }

    return SizedBox(
      width: widget.effectiveWidth,
      child: Stack(
        children: [
          MouseRegion(
            onEnter: isSortable
                ? (_) => setState(() => _isHovered = true)
                : null,
            onExit: isSortable
                ? (_) => setState(() => _isHovered = false)
                : null,
            child: GestureDetector(
              onTap: isSortable ? widget.onSort : null,
              onSecondaryTapUp: (details) {
                _showContextMenu(context, details.globalPosition);
              },
              child: Container(
                decoration: BoxDecoration(color: backgroundColor),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: isSortable
                          ? Tooltip(
                              message: widget.column.label,
                              child: Text(
                                widget.column.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : Text(
                              widget.column.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    if (isSorted)
                      Icon(
                        widget.sortState.direction == SortDirection.ascending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (isResizable)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: ResizeHandle(
                columnId: widget.column.id,
                currentWidth: widget.effectiveWidth,
                onDragUpdate: widget.onResize,
                onDragEnd: widget.onResizeEnd,
                onDoubleTap: widget.onAutoFit,
              ),
            ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final items = <PopupMenuEntry<String>>[];

    // Column reorder (not offered for fixed columns)
    if (!widget.column.isFixed) {
      final canMoveLeft =
          widget.columnIndex > 0 &&
          widget.visibleColumnIds[widget.columnIndex - 1] != 'tagIndicator';
      final canMoveRight =
          widget.columnIndex < widget.visibleColumnIds.length - 1;
      items.add(
        PopupMenuItem<String>(
          value: '__move_left__',
          enabled: canMoveLeft,
          child: const Text('Move Left', style: TextStyle(fontSize: 12)),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: '__move_right__',
          enabled: canMoveRight,
          child: const Text('Move Right', style: TextStyle(fontSize: 12)),
        ),
      );
      items.add(const PopupMenuDivider());
    }

    // Column visibility toggles
    for (final col in widget.allColumns) {
      if (col.isFixed) continue; // Can't toggle fixed columns
      items.add(
        CheckedPopupMenuItem<String>(
          value: col.id,
          checked: widget.visibleColumnIds.contains(col.id),
          child: Text(col.label, style: const TextStyle(fontSize: 12)),
        ),
      );
    }

    // Separator and reset option
    items.add(const PopupMenuDivider());
    items.add(
      const PopupMenuItem<String>(
        value: '__reset_widths__',
        child: Text('Reset Column Widths', style: TextStyle(fontSize: 12)),
      ),
    );

    // Remove selected files option (only when selection is non-empty)
    if (widget.hasSelection) {
      items.add(const PopupMenuDivider());
      items.add(
        const PopupMenuItem<String>(
          value: '__remove_selected__',
          child: Text(
            'Remove Selected from List',
            style: TextStyle(fontSize: 12),
          ),
        ),
      );
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: items,
    ).then((value) {
      if (value == '__move_left__') {
        widget.onReorder?.call(widget.columnIndex, widget.columnIndex - 1);
      } else if (value == '__move_right__') {
        widget.onReorder?.call(widget.columnIndex, widget.columnIndex + 1);
      } else if (value == '__reset_widths__') {
        widget.onResetWidths();
      } else if (value == '__remove_selected__') {
        widget.onRemoveSelected?.call();
      } else if (value != null) {
        widget.onToggleVisibility(value);
      }
    });
  }
}
