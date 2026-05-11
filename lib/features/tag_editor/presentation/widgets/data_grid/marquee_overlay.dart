import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/selection_provider.dart';
import '../../../inline_cell_editing/providers/inline_cell_edit_provider.dart';
import 'marquee_utils.dart';

/// Minimum drag distance (logical pixels) to activate marquee selection.
const double kMarqueeDragThreshold = 4.0;

/// Distance from viewport edge that triggers auto-scroll during marquee.
const double kAutoScrollEdgeInset = 40.0;

/// Auto-scroll speed in pixels per second.
const double kAutoScrollSpeed = 200.0;

/// Overlay widget that handles rubber-band (marquee) selection.
///
/// Wraps the DataGrid's scrollable content and draws a semi-transparent
/// rectangle during drag operations. Computes row intersection on each
/// pointer move and updates the [SelectionNotifier].
class MarqueeOverlay extends ConsumerStatefulWidget {
  const MarqueeOverlay({
    super.key,
    required this.child,
    required this.rowHeight,
    required this.scrollController,
    required this.orderedPaths,
  });

  /// The child widget (typically the ListView).
  final Widget child;

  /// Fixed height of each row in the list.
  final double rowHeight;

  /// The vertical scroll controller of the list.
  final ScrollController scrollController;

  /// Ordered list of file paths corresponding to row indices.
  final List<String> orderedPaths;

  @override
  ConsumerState<MarqueeOverlay> createState() => _MarqueeOverlayState();
}

class _MarqueeOverlayState extends ConsumerState<MarqueeOverlay> {
  bool _isActive = false;
  Offset _startPosition = Offset.zero;
  Offset _currentPosition = Offset.zero;
  bool _isCtrlHeld = false;
  Set<String> _preExistingSelection = {};
  Timer? _autoScrollTimer;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    // Only handle primary button
    if (event.buttons != kPrimaryButton) return;

    final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.any(
      (k) =>
          k == LogicalKeyboardKey.controlLeft ||
          k == LogicalKeyboardKey.controlRight,
    );

    _startPosition = event.localPosition;
    _currentPosition = event.localPosition;
    _isCtrlHeld = isCtrl;

    if (isCtrl) {
      _preExistingSelection =
          Set<String>.from(ref.read(selectionProvider).selectedPaths);
    } else {
      _preExistingSelection = {};
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.buttons != kPrimaryButton) return;

    _currentPosition = event.localPosition;

    // Check if drag exceeds threshold
    final dx = (_currentPosition.dx - _startPosition.dx).abs();
    final dy = (_currentPosition.dy - _startPosition.dy).abs();

    if (!_isActive && (dx > kMarqueeDragThreshold || dy > kMarqueeDragThreshold)) {
      // Confirm edit if active before starting marquee
      final editState = ref.read(inlineCellEditProvider);
      if (editState.isEditing) {
        ref.read(inlineCellEditProvider.notifier).confirmEdit();
      }

      setState(() {
        _isActive = true;
      });
      _startAutoScroll();
    }

    if (_isActive) {
      _updateSelection();
      setState(() {});
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isActive) {
      _stopAutoScroll();
      setState(() {
        _isActive = false;
      });
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_isActive) {
      _stopAutoScroll();
      setState(() {
        _isActive = false;
      });
    }
  }

  void _updateSelection() {
    final scrollOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0.0;

    // Convert local positions to scroll-content coordinates
    final marqueeTop = _startPosition.dy + scrollOffset;
    final marqueeBottom = _currentPosition.dy + scrollOffset;

    final intersectedRows = computeMarqueeIntersectedRows(
      marqueeTop: marqueeTop,
      marqueeBottom: marqueeBottom,
      rowHeight: widget.rowHeight,
      totalRows: widget.orderedPaths.length,
    );

    final intersectedPaths = intersectedRows
        .where((i) => i < widget.orderedPaths.length)
        .map((i) => widget.orderedPaths[i])
        .toSet();

    final selNotifier = ref.read(selectionProvider.notifier);

    if (_isCtrlHeld) {
      selNotifier.replaceSelection(
        _preExistingSelection.union(intersectedPaths),
      );
    } else {
      selNotifier.replaceSelection(intersectedPaths);
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 16), // ~60fps
      (_) => _performAutoScroll(),
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _performAutoScroll() {
    if (!_isActive || !widget.scrollController.hasClients) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportHeight = renderBox.size.height;
    final pointerY = _currentPosition.dy;

    double scrollDelta = 0;

    if (pointerY < kAutoScrollEdgeInset) {
      // Scroll up
      final factor = 1.0 - (pointerY / kAutoScrollEdgeInset).clamp(0.0, 1.0);
      scrollDelta = -kAutoScrollSpeed * factor / 60;
    } else if (pointerY > viewportHeight - kAutoScrollEdgeInset) {
      // Scroll down
      final distFromEdge = pointerY - (viewportHeight - kAutoScrollEdgeInset);
      final factor = (distFromEdge / kAutoScrollEdgeInset).clamp(0.0, 1.0);
      scrollDelta = kAutoScrollSpeed * factor / 60;
    }

    if (scrollDelta != 0) {
      final newOffset = (widget.scrollController.offset + scrollDelta).clamp(
        0.0,
        widget.scrollController.position.maxScrollExtent,
      );
      widget.scrollController.jumpTo(newOffset);
      _updateSelection();
    }
  }

  Rect get _marqueeRect {
    final left = min(_startPosition.dx, _currentPosition.dx);
    final top = min(_startPosition.dy, _currentPosition.dy);
    final right = max(_startPosition.dx, _currentPosition.dx);
    final bottom = max(_startPosition.dy, _currentPosition.dy);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Stack(
        children: [
          widget.child,
          if (_isActive)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MarqueePainter(
                    rect: _marqueeRect,
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3),
                    borderColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarqueePainter extends CustomPainter {
  _MarqueePainter({
    required this.rect,
    required this.color,
    required this.borderColor,
  });

  final Rect rect;
  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(_MarqueePainter oldDelegate) {
    return rect != oldDelegate.rect ||
        color != oldDelegate.color ||
        borderColor != oldDelegate.borderColor;
  }
}
