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
      child: _DragReorderRow(
        visibleColumns: visibleColumns,
        effectiveWidths: effectiveWidths,
        sortState: sortState,
        onMove: (oldIndex, newIndex) => ref
            .read(columnConfigProvider.notifier)
            .moveColumn(oldIndex, newIndex),
        buildCell:
            ({
              required int index,
              required ColumnDefinition column,
              required double width,
            }) {
              return _ColumnHeaderCell(
                columnIndex: index,
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
            },
      ),
    );
  }
}

/// The header row with drag-to-reorder support.
///
/// The dropped column is inserted at the *gap* the pointer is nearest, so the
/// insertion line shows where the column will land rather than snapping to
/// whichever header happens to be hovered. Indices handed to [onMove] are
/// already adjusted for the removal of the dragged column.
class _DragReorderRow extends StatefulWidget {
  const _DragReorderRow({
    required this.visibleColumns,
    required this.effectiveWidths,
    required this.sortState,
    required this.onMove,
    required this.buildCell,
  });

  final List<ColumnDefinition> visibleColumns;
  final List<double> effectiveWidths;
  final SortState sortState;

  /// (oldIndex, newIndex-after-removal) -> void
  final void Function(int oldIndex, int newIndex) onMove;

  final Widget Function({
    required int index,
    required ColumnDefinition column,
    required double width,
  })
  buildCell;

  @override
  State<_DragReorderRow> createState() => _DragReorderRowState();
}

class _DragReorderRowState extends State<_DragReorderRow> {
  /// Index of the column being dragged, or null when not dragging.
  int? _draggingIndex;

  /// Gap index the dragged column would be inserted at while hovering.
  int? _dropGap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final columns = widget.visibleColumns;

    return Row(
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (_dropGap == i) _InsertionLine(color: colorScheme.primary),
          _buildDraggableSlot(i, columns, colorScheme),
        ],
        // Trailing gap, so a column can be dropped last.
        if (_dropGap == columns.length)
          _InsertionLine(color: colorScheme.primary),
      ],
    );
  }

  Widget _buildDraggableSlot(
    int index,
    List<ColumnDefinition> columns,
    ColorScheme colorScheme,
  ) {
    final column = columns[index];
    final width = index < widget.effectiveWidths.length
        ? widget.effectiveWidths[index]
        : column.defaultWidth;

    final content = widget.buildCell(
      index: index,
      column: column,
      width: width,
    );

    // Fixed columns (the tag indicator and the filename) stay put, so they
    // are not draggable at all rather than being silently rejected on drop.
    final draggable = isFixedColumn(column.id)
        ? content
        : LongPressDraggable<int>(
            data: index,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _DragFeedback(
              label: column.label.isEmpty ? column.id : column.label,
              width: width,
            ),
            onDragStarted: () => setState(() => _draggingIndex = index),
            onDragEnd: (_) => setState(() {
              _draggingIndex = null;
              _dropGap = null;
            }),
            childWhenDragging: Opacity(opacity: 0.35, child: content),
            child: content,
          );

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        // Accept only from a different column, and only into a legal gap.
        if (details.data == index) return false;
        return _legalGap(index, details.data);
      },
      onAcceptWithDetails: (details) {
        final from = details.data;
        // onWillAccept has already rejected illegal gaps.
        setState(() {
          _draggingIndex = null;
          _dropGap = null;
        });
        _commit(from, index);
      },
      onMove: (_) {
        if (_draggingIndex != null && _dropGap != index) {
          setState(() => _dropGap = index);
        }
      },
      onLeave: (_) {
        if (_dropGap == index) setState(() => _dropGap = null);
      },
      builder: (context, _, _) => SizedBox(width: width, child: draggable),
    );
  }

  /// Whether dropping [from] at gap [gap] is allowed.
  bool _legalGap(int gap, int from) {
    if (gap < 0 || gap > widget.visibleColumns.length) return false;
    // The first column is fixed; nothing may be dropped before it.
    if (gap == 0 && widget.visibleColumns.isNotEmpty) return false;
    // A column cannot be dropped into the gap immediately after itself,
    // which is where it already is.
    if (gap == from || gap == from + 1) return false;
    return true;
  }

  void _commit(int from, int gap) {
    // Converting a "insert at gap" position into the post-removal index
    // that moveColumn expects: dropping at a gap after the source shifts the
    // target down by one, because the source vacated that slot.
    final newIndex = gap > from ? gap - 1 : gap;
    if (newIndex == from) return;
    widget.onMove(from, newIndex);
  }
}

bool isFixedColumn(String columnId) =>
    columnId == 'tagIndicator' || columnId == 'filename';

class _InsertionLine extends StatelessWidget {
  const _InsertionLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      // Inset so the line reads as a divider between headers rather than
      // overlapping the neighbour's border.
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: color,
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(3),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Container(
        width: width.clamp(60.0, 240.0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
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
