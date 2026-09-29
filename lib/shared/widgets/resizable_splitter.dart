import 'package:flutter/material.dart';

/// A draggable vertical splitter between two child widgets.
///
/// The right child has a configurable width controlled by dragging the
/// splitter handle. Constraints (min/max) are enforced during drag.
class ResizableSplitter extends StatefulWidget {
  const ResizableSplitter({
    super.key,
    required this.leftChild,
    required this.rightChild,
    required this.rightWidth,
    this.minRightWidth = 280.0,
    this.maxRightWidthFraction = 0.5,
    required this.onWidthChanged,
    this.onDragEnd,
  });

  /// The left-side child widget (expands to fill remaining space).
  final Widget leftChild;

  /// The right-side child widget (fixed width controlled by splitter).
  final Widget rightChild;

  /// Current width of the right child in logical pixels.
  final double rightWidth;

  /// Minimum allowed width for the right child.
  final double minRightWidth;

  /// Maximum width for the right child as a fraction of total width.
  final double maxRightWidthFraction;

  /// Called during drag with the new right-child width.
  final ValueChanged<double> onWidthChanged;

  /// Called when the drag gesture ends (for persistence).
  final VoidCallback? onDragEnd;

  @override
  State<ResizableSplitter> createState() => _ResizableSplitterState();
}

class _ResizableSplitterState extends State<ResizableSplitter> {
  /// Width of the draggable splitter hit target.
  static const double _splitterWidth = 8.0;

  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final maxRight = totalWidth * widget.maxRightWidthFraction;
        final effectiveRightWidth = widget.rightWidth.clamp(
          widget.minRightWidth,
          maxRight,
        );
        final leftWidth = totalWidth - effectiveRightWidth - _splitterWidth;

        return Row(
          children: [
            // Left child
            ClipRect(
              child: SizedBox(
                width: leftWidth.clamp(0.0, totalWidth),
                child: widget.leftChild,
              ),
            ),
            // Splitter handle
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: GestureDetector(
                onHorizontalDragStart: (_) {
                  setState(() => _isDragging = true);
                },
                onHorizontalDragUpdate: (details) {
                  final newRightWidth = effectiveRightWidth - details.delta.dx;
                  final clamped = newRightWidth.clamp(
                    widget.minRightWidth,
                    maxRight,
                  );
                  widget.onWidthChanged(clamped);
                },
                onHorizontalDragEnd: (_) {
                  setState(() => _isDragging = false);
                  widget.onDragEnd?.call();
                },
                child: Container(
                  width: _splitterWidth,
                  color: _isDragging || _isHovering
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            // Right child
            SizedBox(width: effectiveRightWidth, child: widget.rightChild),
          ],
        );
      },
    );
  }
}
