import 'package:flutter/material.dart';

/// A small colored corner triangle indicating a cell has been modified
/// but not yet saved to disk.
class ModifiedCellIndicator extends StatelessWidget {
  const ModifiedCellIndicator({
    super.key,
    this.size = 8.0,
  });

  /// Size of the triangle indicator in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: CustomPaint(
        size: Size(size, size),
        painter: _TrianglePainter(
          color: Theme.of(context).colorScheme.tertiary,
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) =>
      color != oldDelegate.color;
}
