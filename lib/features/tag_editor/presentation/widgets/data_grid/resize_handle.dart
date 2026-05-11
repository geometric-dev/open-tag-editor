import 'package:flutter/material.dart';

/// A draggable handle on the right edge of a column header for resizing.
///
/// Displays as a thin invisible hit-target that changes the cursor on hover
/// and reports drag deltas to the parent.
class ResizeHandle extends StatefulWidget {
  const ResizeHandle({
    super.key,
    required this.columnId,
    required this.currentWidth,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDoubleTap,
  });

  final String columnId;
  final double currentWidth;
  final void Function(double newWidth) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDoubleTap;

  /// Hit-target width in logical pixels.
  static const double hitTargetWidth = 8.0;

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  double _startWidth = 0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onDoubleTap: widget.onDoubleTap,
        child: const SizedBox(
          width: ResizeHandle.hitTargetWidth,
          height: double.infinity,
        ),
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    _startWidth = widget.currentWidth;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final newWidth = _startWidth + details.localPosition.dx;
    widget.onDragUpdate(newWidth);
  }

  void _onDragEnd(DragEndDetails details) {
    widget.onDragEnd();
  }
}
