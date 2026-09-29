import 'package:flutter/material.dart';

/// A draggable horizontal splitter between two child widgets.
///
/// The bottom child has a configurable height controlled by dragging the
/// splitter handle. Constraints (min/max) are enforced during drag.
class VerticalResizableSplitter extends StatefulWidget {
  const VerticalResizableSplitter({
    super.key,
    required this.topChild,
    required this.bottomChild,
    required this.bottomHeight,
    this.minBottomHeight = 120.0,
    this.maxBottomHeightFraction = 0.5,
    required this.onHeightChanged,
    this.onDragEnd,
  });

  /// The top-side child widget (expands to fill remaining space).
  final Widget topChild;

  /// The bottom-side child widget (fixed height controlled by splitter).
  final Widget bottomChild;

  /// Current height of the bottom child in logical pixels.
  final double bottomHeight;

  /// Minimum allowed height for the bottom child.
  final double minBottomHeight;

  /// Maximum height for the bottom child as a fraction of total height.
  final double maxBottomHeightFraction;

  /// Called during drag with the new bottom-child height.
  final ValueChanged<double> onHeightChanged;

  /// Called when the drag gesture ends (for persistence).
  final VoidCallback? onDragEnd;

  @override
  State<VerticalResizableSplitter> createState() =>
      _VerticalResizableSplitterState();
}

class _VerticalResizableSplitterState extends State<VerticalResizableSplitter> {
  /// Height of the draggable splitter hit target.
  static const double _splitterHeight = 8.0;

  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final maxBottom = totalHeight * widget.maxBottomHeightFraction;
        final effectiveBottomHeight = widget.bottomHeight.clamp(
          widget.minBottomHeight,
          maxBottom,
        );

        return Column(
          children: [
            // Top child
            Expanded(child: widget.topChild),
            // Splitter handle
            MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: GestureDetector(
                onVerticalDragStart: (_) {
                  setState(() => _isDragging = true);
                },
                onVerticalDragUpdate: (details) {
                  final newBottomHeight =
                      effectiveBottomHeight - details.delta.dy;
                  final clamped = newBottomHeight.clamp(
                    widget.minBottomHeight,
                    maxBottom,
                  );
                  widget.onHeightChanged(clamped);
                },
                onVerticalDragEnd: (_) {
                  setState(() => _isDragging = false);
                  widget.onDragEnd?.call();
                },
                child: Container(
                  height: _splitterHeight,
                  color: _isDragging || _isHovering
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            // Bottom child
            SizedBox(height: effectiveBottomHeight, child: widget.bottomChild),
          ],
        );
      },
    );
  }
}
