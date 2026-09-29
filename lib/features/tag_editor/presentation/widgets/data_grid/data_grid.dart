import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/models/audio_file.dart';
import '../../../../../shared/services/taglib/taglib_types.dart';
import '../../../data/column_width_resolver.dart';
import '../../../data/models/column_definition.dart';
import '../../../data/models/grid_item.dart';
import '../../../data/models/selection_state.dart';
import '../../../data/providers/column_config_provider.dart';
import '../../../data/providers/editor_state_provider.dart';
import '../../../data/providers/file_list_provider.dart';
import '../../../data/providers/filtered_sorted_file_list_provider.dart';
import '../../../data/providers/grid_items_provider.dart';
import '../../../data/providers/selection_provider.dart';
import '../../../inline_cell_editing/models/cell_coordinate.dart';
import '../../../inline_cell_editing/providers/inline_cell_edit_provider.dart';
import '../../../inline_cell_editing/utils/column_editability.dart';
import '../../../inline_cell_editing/widgets/editable_cell.dart';
import '../../helpers/grid_navigation.dart';
import '../address_bar.dart';
import 'column_headers.dart';
import 'folder_separator_row.dart';
import 'marquee_overlay.dart';

/// The main data grid widget displaying audio files in a virtualized table.
///
/// Uses [ListView.builder] with fixed item extent for smooth scrolling
/// performance with hundreds of files.
class DataGrid extends ConsumerWidget {
  const DataGrid({super.key});

  /// The fixed height for all rows (file rows and separator rows).
  static const double rowHeight = 28;

  /// Rows jumped by PageUp/PageDown.
  static const int pageJumpRows = 20;

  /// Upper bound on rows measured during auto-fit. Beyond this the
  /// extra TextPainter layouts cost more than the precision is worth.
  static const int autoFitSampleCap = 1000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(filteredSortedFileListProvider);
    final gridItems = ref.watch(gridItemsProvider);
    final selection = ref.watch(selectionProvider);
    final config = ref.watch(columnConfigProvider);
    final rootFolder = ref.watch(loadedFolderPathProvider);

    final visibleColumns = config.visibleColumnIds
        .map(
          (id) => defaultColumns.firstWhere(
            (c) => c.id == id,
            orElse: () => defaultColumns.first,
          ),
        )
        .toList();

    return Column(
      children: [
        Expanded(
          child: files.isEmpty
              ? _buildEmptyState(context)
              : _FocusableDataGrid(
                  files: files,
                  gridItems: gridItems,
                  selection: selection,
                  visibleColumns: visibleColumns,
                  widthOverrides: config.widthOverrides,
                  rootFolder: rootFolder,
                  onRowTap: (path, modifiers) => _handleRowTap(
                    ref,
                    path,
                    modifiers,
                    filePathsFromGridItems(gridItems),
                  ),
                  onRowDoubleTap: (path) {
                    // Only open side panel if not in edit mode
                    final editState = ref.read(inlineCellEditProvider);
                    if (editState.isEditing) return;
                    ref.read(selectionProvider.notifier).select(path);
                    ref.read(tagPanelOpenProvider.notifier).state = true;
                  },
                  onAutoFit: (columnId, fitWidth) {
                    ref
                        .read(columnConfigProvider.notifier)
                        .setColumnWidth(columnId, fitWidth);
                    ref.read(columnConfigProvider.notifier).persistWidths();
                  },
                  onKeyEvent: (event) => _handleKeyEvent(ref, context, event),
                  hasSelection: selection.hasSelection,
                  onRemoveSelected: () {
                    final selectedFiles = ref.read(selectedFilesProvider);
                    if (selectedFiles.isEmpty) return;
                    _removeSelectedFiles(ref, context, selectedFiles);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audio_file_outlined,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Drop files or folders here\nor use the toolbar to open',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRowTap(
    WidgetRef ref,
    String path,
    _KeyModifiers modifiers,
    List<String> orderedPaths,
  ) {
    // Exit edit mode on any row tap (confirm current edit)
    final editState = ref.read(inlineCellEditProvider);
    if (editState.isEditing) {
      ref.read(inlineCellEditProvider.notifier).confirmEdit(clearFocus: true);
    } else if (editState.focusedCell != null) {
      ref.read(inlineCellEditProvider.notifier).clearFocus();
    }

    final notifier = ref.read(selectionProvider.notifier);

    if (modifiers.isCtrl && modifiers.isShift) {
      notifier.addRangeSelect(path, orderedPaths);
    } else if (modifiers.isShift) {
      notifier.rangeSelect(path, orderedPaths);
    } else if (modifiers.isCtrl) {
      notifier.toggleSelect(path);
    } else {
      notifier.select(path);

      // Set focused cell to first editable column in this row
      // so F2/typing can enter edit mode immediately.
      // Use soft focus (no visible border) since this is a mouse click.
      final files = ref.read(filteredSortedFileListProvider);
      final rowIndex = files.indexWhere((f) => f.path == path);
      if (rowIndex >= 0) {
        final config = ref.read(columnConfigProvider);
        final firstEditable = config.visibleColumnIds.firstWhere(
          isColumnEditable,
          orElse: () => '',
        );
        if (firstEditable.isNotEmpty) {
          ref
              .read(inlineCellEditProvider.notifier)
              .moveFocus(
                CellCoordinate(rowIndex: rowIndex, columnId: firstEditable),
                showBorder: false,
              );
        }
      }
    }
  }

  KeyEventResult _handleKeyEvent(
    WidgetRef ref,
    BuildContext context,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final editNotifier = ref.read(inlineCellEditProvider.notifier);
    final editState = ref.read(inlineCellEditProvider);
    final gridItems = ref.read(gridItemsProvider);
    final orderedPaths = filePathsFromGridItems(gridItems);
    final selNotifier = ref.read(selectionProvider.notifier);

    final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.any(
      (k) =>
          k == LogicalKeyboardKey.controlLeft ||
          k == LogicalKeyboardKey.controlRight,
    );
    final isShift = HardwareKeyboard.instance.logicalKeysPressed.any(
      (k) =>
          k == LogicalKeyboardKey.shiftLeft ||
          k == LogicalKeyboardKey.shiftRight,
    );

    // If already editing, let the InlineTextField handle keys
    if (editState.isEditing) return KeyEventResult.ignored;

    // Escape: clear selection when not editing
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      selNotifier.clear();
      return KeyEventResult.handled;
    }

    // Ctrl+A: select all
    if (isCtrl && !isShift && event.logicalKey == LogicalKeyboardKey.keyA) {
      selNotifier.selectAll(orderedPaths);
      return KeyEventResult.handled;
    }

    // Ctrl+Shift+Home: extend selection to start
    if (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.home) {
      selNotifier.extendToStart(orderedPaths);
      return KeyEventResult.handled;
    }

    // Ctrl+Shift+End: extend selection to end
    if (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.end) {
      selNotifier.extendToEnd(orderedPaths);
      return KeyEventResult.handled;
    }

    // Arrow Down
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (isShift) {
        selNotifier.extendDown(orderedPaths);
      } else {
        selNotifier.moveDown(orderedPaths);
      }
      return KeyEventResult.handled;
    }

    // Arrow Up
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (isShift) {
        selNotifier.extendUp(orderedPaths);
      } else {
        selNotifier.moveUp(orderedPaths);
      }
      return KeyEventResult.handled;
    }

    // F2: enter edit mode on focused cell (guard is in enterEditMode)
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      final focused = editState.focusedCell;
      if (focused != null && isColumnEditable(focused.columnId)) {
        editNotifier.enterEditMode(focused, prePopulate: true, selectAll: true);
        return KeyEventResult.handled;
      }
    }

    // Printable character: enter edit mode (guard is in enterEditMode)
    if (event.character != null && event.character!.length == 1 && !isCtrl) {
      final focused = editState.focusedCell;
      if (focused != null && isColumnEditable(focused.columnId)) {
        editNotifier.enterEditMode(focused, initialCharacter: event.character!);
        return KeyEventResult.handled;
      }
    }

    // PageUp/PageDown: jump selection by a page, clamping at edges
    final isPageUp = event.logicalKey == LogicalKeyboardKey.pageUp;
    final isPageDown = event.logicalKey == LogicalKeyboardKey.pageDown;
    if (isPageUp || isPageDown) {
      final direction = isPageUp ? -1 : 1;
      if (isShift) {
        selNotifier.extendByPage(orderedPaths, direction, pageJumpRows);
      } else {
        selNotifier.moveByPage(orderedPaths, direction, pageJumpRows);
      }
      return KeyEventResult.handled;
    }

    // Home/End (plain and Shift): jump to first/last row
    final isHome = event.logicalKey == LogicalKeyboardKey.home;
    final isEnd = event.logicalKey == LogicalKeyboardKey.end;
    if ((isHome || isEnd) && !isCtrl) {
      if (isShift) {
        isHome
            ? selNotifier.extendToStart(orderedPaths)
            : selNotifier.extendToEnd(orderedPaths);
      } else {
        isHome
            ? selNotifier.moveHome(orderedPaths)
            : selNotifier.moveEnd(orderedPaths);
      }
      return KeyEventResult.handled;
    }

    // Enter: begin editing the focused cell
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final focused = editState.focusedCell;
      if (focused != null && isColumnEditable(focused.columnId)) {
        editNotifier.enterEditMode(focused, prePopulate: true, selectAll: true);
        return KeyEventResult.handled;
      }
    }

    // Delete key: remove selected files from list
    if (event.logicalKey == LogicalKeyboardKey.delete) {
      final selectedFiles = ref.read(selectedFilesProvider);
      if (selectedFiles.isEmpty) return KeyEventResult.ignored;
      _removeSelectedFiles(ref, context, selectedFiles);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _removeSelectedFiles(
    WidgetRef ref,
    BuildContext context,
    List<AudioFile> selectedFiles,
  ) async {
    final modifiedCount = selectedFiles.where((f) => f.isModified).length;
    final totalCount = selectedFiles.length;
    final selectedPaths = selectedFiles.map((f) => f.path).toSet();

    if (modifiedCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove from List'),
          content: Text(
            'Remove $totalCount file(s) from list? '
            '$modifiedCount have unsaved changes that will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    ref.read(fileListProvider.notifier).removeFiles(selectedPaths);
    ref.read(selectionProvider.notifier).clear();
  }
}

/// Wraps [_ScrollableDataGrid] with a [Focus] widget that re-requests focus
/// on every row tap, ensuring keyboard events (arrow keys, Shift+arrows)
/// continue to work after mouse interactions.
class _FocusableDataGrid extends StatefulWidget {
  const _FocusableDataGrid({
    required this.files,
    required this.gridItems,
    required this.selection,
    required this.visibleColumns,
    required this.widthOverrides,
    required this.rootFolder,
    required this.onRowTap,
    required this.onRowDoubleTap,
    required this.onKeyEvent,
    this.onAutoFit,
    this.hasSelection = false,
    this.onRemoveSelected,
  });

  final List<AudioFile> files;
  final List<GridItem> gridItems;
  final SelectionState selection;
  final List<ColumnDefinition> visibleColumns;
  final Map<String, double> widthOverrides;
  final String? rootFolder;
  final void Function(String path, _KeyModifiers modifiers) onRowTap;
  final void Function(String path) onRowDoubleTap;
  final KeyEventResult Function(KeyEvent event) onKeyEvent;
  final void Function(String columnId, double fitWidth)? onAutoFit;
  final bool hasSelection;
  final VoidCallback? onRemoveSelected;

  @override
  State<_FocusableDataGrid> createState() => _FocusableDataGridState();
}

class _FocusableDataGridState extends State<_FocusableDataGrid> {
  final _focusNode = FocusNode(debugLabel: 'DataGrid');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _ensureFocus() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => widget.onKeyEvent(event),
      child: _ScrollableDataGrid(
        files: widget.files,
        gridItems: widget.gridItems,
        selection: widget.selection,
        visibleColumns: widget.visibleColumns,
        widthOverrides: widget.widthOverrides,
        rootFolder: widget.rootFolder,
        onRowTap: (path, modifiers) {
          widget.onRowTap(path, modifiers);
          _ensureFocus();
        },
        onRowDoubleTap: widget.onRowDoubleTap,
        onAutoFit: widget.onAutoFit,
        hasSelection: widget.hasSelection,
        onRemoveSelected: widget.onRemoveSelected,
      ),
    );
  }
}

class _ScrollableDataGrid extends ConsumerStatefulWidget {
  const _ScrollableDataGrid({
    required this.files,
    required this.gridItems,
    required this.selection,
    required this.visibleColumns,
    required this.widthOverrides,
    required this.rootFolder,
    required this.onRowTap,
    required this.onRowDoubleTap,
    this.onAutoFit,
    this.hasSelection = false,
    this.onRemoveSelected,
  });

  final List<AudioFile> files;
  final List<GridItem> gridItems;
  final SelectionState selection;
  final List<ColumnDefinition> visibleColumns;
  final Map<String, double> widthOverrides;
  final String? rootFolder;
  final void Function(String path, _KeyModifiers modifiers) onRowTap;
  final void Function(String path) onRowDoubleTap;
  final void Function(String columnId, double fitWidth)? onAutoFit;
  final bool hasSelection;
  final VoidCallback? onRemoveSelected;

  @override
  ConsumerState<_ScrollableDataGrid> createState() =>
      _ScrollableDataGridState();
}

class _ScrollableDataGridState extends ConsumerState<_ScrollableDataGrid> {
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Keyboard navigation must keep the active row visible. Listen for
    // active-path changes and reveal the row (no-op while marquee-dragging
    // since pointer selection sets activePath only via clicks, which are
    // already on-screen).
    ref.listenManual(selectionProvider.select((s) => s.activePath), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _revealRow(next);
        });
      }
    });
  }

  /// Scrolls the vertical viewport so the given file's row is visible.
  void _revealRow(String path) {
    if (!_verticalController.hasClients) return;

    // Map the path to its grid item index (separators share the rows).
    int? gridIndex;
    for (var i = 0; i < widget.gridItems.length; i++) {
      final item = widget.gridItems[i];
      if (item is FileGridItem && item.file.path == path) {
        gridIndex = i;
        break;
      }
    }
    if (gridIndex == null) return;

    final top = gridIndex * DataGrid.rowHeight;
    final bottom = top + DataGrid.rowHeight;
    final offset = _verticalController.offset;
    final viewport = _verticalController.position.viewportDimension;

    if (top < offset) {
      _verticalController.jumpTo(top);
    } else if (bottom > offset + viewport) {
      _verticalController.jumpTo(bottom - viewport);
    }
  }

  @override
  void didUpdateWidget(covariant _ScrollableDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Preserve scroll position when grid items change (separators added/removed)
    if (oldWidget.gridItems != widget.gridItems &&
        _verticalController.hasClients) {
      final oldOffset = _verticalController.offset;
      if (oldOffset <= 0) return;

      // Find which file was at the top of the viewport in the old list
      final oldTopIndex = (oldOffset / DataGrid.rowHeight).floor().clamp(
        0,
        oldWidget.gridItems.length - 1,
      );

      // Find the file at that position in the old grid items
      String? topFilePath;
      for (var i = oldTopIndex; i < oldWidget.gridItems.length; i++) {
        final item = oldWidget.gridItems[i];
        if (item is FileGridItem) {
          topFilePath = item.file.path;
          break;
        }
      }
      if (topFilePath == null) return;

      // Find that file's new position in the updated grid items
      int? newIndex;
      for (var i = 0; i < widget.gridItems.length; i++) {
        final item = widget.gridItems[i];
        if (item is FileGridItem && item.file.path == topFilePath) {
          newIndex = i;
          break;
        }
      }

      if (newIndex != null) {
        final newOffset = newIndex * DataGrid.rowHeight;
        final maxExtent =
            (widget.gridItems.length * DataGrid.rowHeight) -
            (_verticalController.position.viewportDimension);
        final clampedOffset = newOffset.clamp(
          0.0,
          maxExtent > 0 ? maxExtent : 0.0,
        );

        if ((clampedOffset - oldOffset).abs() > 0.5) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_verticalController.hasClients) {
              _verticalController.jumpTo(clampedOffset);
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  /// Pre-compute effective widths for all visible columns once per build.
  List<double> _computeEffectiveWidths() {
    return widget.visibleColumns
        .map(
          (c) => resolveEffectiveWidth(
            c.id,
            widget.widthOverrides,
            widget.visibleColumns,
          ),
        )
        .toList();
  }

  void _handleAutoFit(String columnId) {
    final column = widget.visibleColumns.firstWhere(
      (c) => c.id == columnId,
      orElse: () => widget.visibleColumns.first,
    );

    // Measure header label width
    final headerPainter = TextPainter(
      text: TextSpan(
        text: column.label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final headerWidth = headerPainter.width;

    // Measure visible cell content widths
    final cellWidths = <double>[];
    for (final file in widget.files) {
      final value =
          column.valueExtractor?.call(file, rootFolder: widget.rootFolder) ??
          '';
      if (value.isNotEmpty) {
        final cellPainter = TextPainter(
          text: TextSpan(text: value, style: const TextStyle(fontSize: 12)),
          textDirection: TextDirection.ltr,
        )..layout();
        cellWidths.add(cellPainter.width);
      }
    }

    final fitWidth = calculateAutoFitWidth(
      cellWidths: cellWidths,
      headerLabelWidth: headerWidth,
    );

    widget.onAutoFit?.call(columnId, fitWidth);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveWidths = _computeEffectiveWidths();
    final totalWidth = effectiveWidths.fold(0.0, (sum, w) => sum + w);

    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        notificationPredicate: (notification) => notification.depth == 0,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _horizontalController,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                RepaintBoundary(
                  child: ColumnHeaders(
                    effectiveWidths: effectiveWidths,
                    onAutoFit: _handleAutoFit,
                    hasSelection: widget.hasSelection,
                    onRemoveSelected: widget.onRemoveSelected,
                  ),
                ),
                Expanded(
                  child: MarqueeOverlay(
                    rowHeight: DataGrid.rowHeight,
                    scrollController: _verticalController,
                    gridItems: widget.gridItems,
                    orderedPaths: filePathsFromGridItems(widget.gridItems),
                    child: ListView.builder(
                      controller: _verticalController,
                      itemCount: widget.gridItems.length,
                      itemExtent: DataGrid.rowHeight,
                      itemBuilder: (context, index) {
                        final item = widget.gridItems[index];
                        switch (item) {
                          case SeparatorGridItem(:final relativePath):
                            return FolderSeparatorRow(
                              relativePath: relativePath,
                            );
                          case FileGridItem(:final file, :final fileIndex):
                            final isSelected = widget.selection.isSelected(
                              file.path,
                            );
                            return _DataRow(
                              file: file,
                              rowIndex: fileIndex,
                              isSelected: isSelected,
                              visibleColumns: widget.visibleColumns,
                              effectiveWidths: effectiveWidths,
                              rootFolder: widget.rootFolder,
                              onTap: (modifiers) =>
                                  widget.onRowTap(file.path, modifiers),
                              onDoubleTap: () =>
                                  widget.onRowDoubleTap(file.path),
                            );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DataRow extends ConsumerWidget {
  const _DataRow({
    required this.file,
    required this.rowIndex,
    required this.isSelected,
    required this.visibleColumns,
    required this.effectiveWidths,
    required this.rootFolder,
    required this.onTap,
    required this.onDoubleTap,
  });

  final AudioFile file;
  final int rowIndex;
  final bool isSelected;
  final List<ColumnDefinition> visibleColumns;
  final List<double> effectiveWidths;
  final String? rootFolder;
  final void Function(_KeyModifiers modifiers) onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // Selective rebuild: only rebuild when THIS row's edit/focus state changes.
    // The watch ensures the row rebuilds when cells enter/exit edit or focus.
    ref.watch(
      inlineCellEditProvider.select(
        (s) =>
            s.editingCell?.rowIndex == rowIndex ||
            s.focusedCell?.rowIndex == rowIndex,
      ),
    );

    // Only suppress onDoubleTap when this row is actively being *edited*
    // (not just focused), so double-clicking non-editable cells still opens
    // the tag panel on a focused-but-not-editing row.
    final isEditingThisRow = ref.watch(
      inlineCellEditProvider.select((s) => s.editingCell?.rowIndex == rowIndex),
    );

    // Determine row background: selection > zebra stripe > transparent
    Color? rowBackground;
    if (isSelected) {
      rowBackground = colorScheme.primaryContainer.withValues(alpha: 0.5);
    } else if (rowIndex.isEven) {
      rowBackground = colorScheme.onSurface.withValues(alpha: 0.03);
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        canRequestFocus: false,
        onTap: () {
          final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.any(
            (k) =>
                k == LogicalKeyboardKey.controlLeft ||
                k == LogicalKeyboardKey.controlRight ||
                k == LogicalKeyboardKey.metaLeft ||
                k == LogicalKeyboardKey.metaRight,
          );
          final isShift = HardwareKeyboard.instance.logicalKeysPressed.any(
            (k) =>
                k == LogicalKeyboardKey.shiftLeft ||
                k == LogicalKeyboardKey.shiftRight,
          );
          onTap(_KeyModifiers(isCtrl: isCtrl, isShift: isShift));
        },
        onDoubleTap: isEditingThisRow ? null : onDoubleTap,
        child: Container(
          decoration: BoxDecoration(
            color: rowBackground,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: List.generate(visibleColumns.length, (i) {
              final column = visibleColumns[i];
              final width = i < effectiveWidths.length
                  ? effectiveWidths[i]
                  : column.defaultWidth;

              if (column.id == 'tagIndicator') {
                return _TagIndicatorCell(file: file, width: width);
              }

              final value =
                  column.valueExtractor?.call(file, rootFolder: rootFolder) ??
                  '';

              // Use EditableCell for editable columns
              if (isColumnEditable(column.id)) {
                return EditableCell(
                  coordinate: CellCoordinate(
                    rowIndex: rowIndex,
                    columnId: column.id,
                  ),
                  value: value,
                  width: width,
                  isModified:
                      file.isModified &&
                      file.modifiedTags.containsKey(column.id),
                );
              }

              return _TextCell(value: value, width: width);
            }),
          ),
        ),
      ),
    );
  }
}

class _TagIndicatorCell extends StatelessWidget {
  const _TagIndicatorCell({required this.file, required this.width});

  final AudioFile file;
  final double width;

  @override
  Widget build(BuildContext context) {
    // Show error indicator for corrupt files
    if (file.readError != null) {
      return SizedBox(
        width: width,
        child: Center(
          child: Tooltip(
            message: file.readError!,
            child: Icon(
              Icons.error,
              size: 14,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }

    // Show read-only indicator
    if (file.isReadOnly) {
      return SizedBox(
        width: width,
        child: Center(
          child: Tooltip(
            message: 'Read-only file',
            child: Icon(
              Icons.lock,
              size: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    // Existing tag indicator logic
    final hasTags = file.tags.values.any((v) => v.isNotEmpty);
    final formatName = _tagFormatName(file.tagFormat);

    return SizedBox(
      width: width,
      child: Center(
        child: Tooltip(
          message: hasTags ? formatName : 'No tags',
          child: Icon(
            hasTags ? Icons.label : Icons.label_outline,
            size: 14,
            color: hasTags
                ? Theme.of(context).colorScheme.primary
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  String _tagFormatName(TagFormat? format) {
    switch (format) {
      case TagFormat.id3v1:
        return 'ID3v1';
      case TagFormat.id3v2_3:
        return 'ID3v2.3';
      case TagFormat.id3v2_4:
        return 'ID3v2.4';
      case TagFormat.vorbisComment:
        return 'Vorbis Comment';
      case TagFormat.apeTag:
        return 'APE';
      case TagFormat.asf:
        return 'ASF';
      case TagFormat.mp4Atoms:
        return 'MP4';
      case TagFormat.unknown:
        return 'Tagged (format unknown)';
      case null:
        return 'None detected';
    }
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell({required this.value, required this.width});

  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          value,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _KeyModifiers {
  const _KeyModifiers({this.isCtrl = false, this.isShift = false});

  final bool isCtrl;
  final bool isShift;
}
