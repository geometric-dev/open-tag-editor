import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tag_editor/data/providers/recursive_loading_provider.dart';
import '../../tag_editor/presentation/widgets/address_bar.dart';
import '../data/breadcrumb_parser.dart';

/// Breadcrumb-style path display with clickable segments for ancestor navigation.
///
/// Displays the currently loaded folder path as a series of clickable text
/// segments separated by chevron dividers. Clicking a segment navigates to
/// that ancestor directory via [onFolderSelected]. The last segment (current
/// folder) is styled bold and is not clickable.
///
/// Supports edit mode (double-click or Ctrl+L to switch to a text input field)
/// and overflow handling (leading segments collapse into a dropdown when the
/// path exceeds visible width).
///
/// Includes the same recursive-loading toggle as the existing [AddressBar].
class BreadcrumbBar extends ConsumerStatefulWidget {
  const BreadcrumbBar({super.key, this.onFolderSelected});

  /// Callback when a folder path is selected (segment click or typed path).
  final void Function(String path)? onFolderSelected;

  @override
  ConsumerState<BreadcrumbBar> createState() => _BreadcrumbBarState();
}

class _BreadcrumbBarState extends ConsumerState<BreadcrumbBar> {
  final _parser = const BreadcrumbParser();
  final _editController = TextEditingController();
  final _editFocusNode = FocusNode();
  bool _isEditing = false;

  // Double-tap detection state (using Listener to avoid gesture arena conflicts)
  DateTime? _lastTapTime;
  static const _doubleTapTimeout = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _editFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _editFocusNode.removeListener(_onFocusChange);
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_editFocusNode.hasFocus && _isEditing) {
      _cancelEditing();
    }
  }

  void _startEditing() {
    final currentPath = ref.read(loadedFolderPathProvider) ?? '';
    _editController.text = currentPath;
    _editController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: currentPath.length,
    );
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode.requestFocus();
    });
  }

  void _submitPath() {
    final path = _editController.text.trim();
    setState(() => _isEditing = false);
    if (path.isNotEmpty) {
      widget.onFolderSelected?.call(path);
    }
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final folderPath = ref.watch(loadedFolderPathProvider);
    final isRecursive = ref.watch(recursiveLoadingProvider);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: _isEditing
                ? _buildEditField()
                : _buildBreadcrumbArea(context, folderPath),
          ),
          const SizedBox(width: 4),
          // Recursive toggle
          Tooltip(
            message: isRecursive
                ? 'Recursive: scanning subfolders'
                : 'Non-recursive: top-level only',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => ref.read(recursiveLoadingProvider.notifier).toggle(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRecursive
                          ? Icons.subdirectory_arrow_right
                          : Icons.horizontal_rule,
                      size: 14,
                      color: isRecursive
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Recursive',
                      style: TextStyle(
                        fontSize: 11,
                        color: isRecursive
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField() {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _cancelEditing();
        }
      },
      child: TextField(
        controller: _editController,
        focusNode: _editFocusNode,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          hintText: 'Enter folder path...',
        ),
        onSubmitted: (_) => _submitPath(),
      ),
    );
  }

  Widget _buildBreadcrumbArea(BuildContext context, String? folderPath) {
    if (folderPath == null) {
      return Text(
        'No folder loaded',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    return Listener(
      onPointerDown: (_) {
        final now = DateTime.now();
        if (_lastTapTime != null &&
            now.difference(_lastTapTime!) < _doubleTapTimeout) {
          _startEditing();
          _lastTapTime = null;
        } else {
          _lastTapTime = now;
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyL, control: true):
              _startEditing,
        },
        child: Focus(child: _buildBreadcrumbs(context, folderPath)),
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context, String folderPath) {
    final segments = _parser.splitSegments(folderPath);
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final segmentWidgets = _buildSegmentWidgets(context, segments);

        // Estimate total width of all segments
        final totalWidth = _estimateTotalWidth(segments);

        if (totalWidth <= availableWidth) {
          // All segments fit — show them all
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: segmentWidgets,
            ),
          );
        }

        // Overflow: collapse leading segments into a dropdown
        return _buildOverflowBreadcrumbs(context, segments, availableWidth);
      },
    );
  }

  List<Widget> _buildSegmentWidgets(
    BuildContext context,
    List<String> segments,
  ) {
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final isLast = i == segments.length - 1;

      if (isLast) {
        children.add(
          Text(
            segments[i],
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        );
      } else {
        final index = i;
        children.add(
          InkWell(
            borderRadius: BorderRadius.circular(2),
            onTap: () {
              final path = _parser.pathAtIndex(segments, index);
              widget.onFolderSelected?.call(path);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                segments[i],
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.chevron_right,
              size: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        );
      }
    }
    return children;
  }

  /// Estimates the total pixel width of all breadcrumb segments.
  ///
  /// Uses approximate character width (7px per char at font size 12) plus
  /// padding and chevron icon widths.
  double _estimateTotalWidth(List<String> segments) {
    const charWidth = 7.0;
    const chevronWidth = 18.0; // icon size 14 + 4px padding
    const segmentPadding = 4.0; // horizontal padding per segment

    var total = 0.0;
    for (var i = 0; i < segments.length; i++) {
      total += segments[i].length * charWidth + segmentPadding;
      if (i < segments.length - 1) {
        total += chevronWidth;
      }
    }
    return total;
  }

  Widget _buildOverflowBreadcrumbs(
    BuildContext context,
    List<String> segments,
    double availableWidth,
  ) {
    // Reserve space for the overflow button (~30px)
    const overflowButtonWidth = 30.0;
    final remainingWidth = availableWidth - overflowButtonWidth;

    // Find how many trailing segments fit in the remaining width
    const charWidth = 7.0;
    const chevronWidth = 18.0;
    const segmentPadding = 4.0;

    var visibleCount = 0;
    var usedWidth = 0.0;

    for (var i = segments.length - 1; i >= 0; i--) {
      final segWidth = segments[i].length * charWidth + segmentPadding;
      final chevron = (i < segments.length - 1) ? chevronWidth : 0.0;
      if (usedWidth + segWidth + chevron > remainingWidth && visibleCount > 0) {
        break;
      }
      usedWidth += segWidth + chevron;
      visibleCount++;
    }

    // Ensure at least the last segment is always visible
    if (visibleCount == 0) visibleCount = 1;

    final hiddenCount = segments.length - visibleCount;
    final hiddenSegments = segments.sublist(0, hiddenCount);
    final visibleSegments = segments.sublist(hiddenCount);

    final children = <Widget>[];

    // Overflow dropdown button
    if (hiddenSegments.isNotEmpty) {
      children.add(
        PopupMenuButton<int>(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          tooltip: 'Show hidden path segments',
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Icon(Icons.more_horiz, size: 16),
          ),
          itemBuilder: (_) => [
            for (var i = 0; i < hiddenSegments.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: Text(
                  hiddenSegments[i],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          onSelected: (index) {
            final path = _parser.pathAtIndex(segments, index);
            widget.onFolderSelected?.call(path);
          },
        ),
      );
      // Chevron after overflow button
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.chevron_right,
            size: 14,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    // Visible trailing segments
    for (var i = 0; i < visibleSegments.length; i++) {
      final isLast = i == visibleSegments.length - 1;
      final globalIndex = hiddenCount + i;

      if (isLast) {
        children.add(
          Flexible(
            child: Text(
              visibleSegments[i],
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      } else {
        children.add(
          InkWell(
            borderRadius: BorderRadius.circular(2),
            onTap: () {
              final path = _parser.pathAtIndex(segments, globalIndex);
              widget.onFolderSelected?.call(path);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                visibleSegments[i],
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.chevron_right,
              size: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        );
      }
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
