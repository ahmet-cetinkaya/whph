import 'package:flutter/material.dart';

/// Custom painter that draws a dimmed overlay with a clear rectangular area.
class DimOverlayPainter extends CustomPainter {
  final Rect clearRect;
  final Color backgroundColor;

  const DimOverlayPainter({
    required this.clearRect,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    // Draw four rectangles around the clear area
    final rects = <Rect>[
      // Top rectangle (above clear area)
      Rect.fromLTRB(0, 0, size.width, clearRect.top),
      // Bottom rectangle (below clear area)
      Rect.fromLTRB(0, clearRect.bottom, size.width, size.height),
      // Left rectangle (middle section)
      Rect.fromLTRB(0, clearRect.top, clearRect.left, clearRect.bottom),
      // Right rectangle (middle section)
      Rect.fromLTRB(clearRect.right, clearRect.top, size.width, clearRect.bottom),
    ];

    for (final rect in rects) {
      if (rect.width > 0 && rect.height > 0) {
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DimOverlayPainter oldDelegate) {
    return oldDelegate.clearRect != clearRect || oldDelegate.backgroundColor != backgroundColor;
  }
}
