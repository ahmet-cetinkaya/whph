import 'package:flutter/material.dart';
import 'tour_step.dart';

/// Utility class for calculating tour overlay content positioning.
class TourPositionCalculator {
  static const double horizontalMargin = 20.0;
  static const double verticalMargin = 20.0;
  static const double overlayHeight = 200.0;
  static const double actionButtonHeight = 100.0;

  /// Calculate content position based on target and step position preference.
  static Offset calculateContentPosition({
    required BuildContext context,
    required TourStep step,
    required Offset targetPosition,
    required Size targetSize,
  }) {
    final screenSize = MediaQuery.sizeOf(context);
    final targetCenter = targetPosition + Offset(targetSize.width / 2, targetSize.height / 2);
    final overlayWidth = screenSize.width * 0.9;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom + actionButtonHeight;

    final minX = horizontalMargin;
    final maxX = (screenSize.width - overlayWidth - horizontalMargin).clamp(minX, screenSize.width - overlayWidth);
    final minY = verticalMargin;
    final maxY = (screenSize.height - overlayHeight - bottomSafeArea).clamp(minY, screenSize.height - overlayHeight);

    switch (step.position) {
      case TourPosition.top:
        return Offset(
          (targetCenter.dx - overlayWidth / 2).clamp(minX, maxX),
          (targetPosition.dy - overlayHeight - verticalMargin).clamp(minY, maxY),
        );

      case TourPosition.bottom:
        return Offset(
          (targetCenter.dx - overlayWidth / 2).clamp(minX, maxX),
          (targetPosition.dy + targetSize.height + verticalMargin)
              .clamp(minY, screenSize.height - overlayHeight - bottomSafeArea),
        );

      case TourPosition.left:
        return Offset(
          (targetPosition.dx - overlayWidth - horizontalMargin).clamp(minX, maxX),
          (targetCenter.dy - overlayHeight / 2).clamp(minY, maxY),
        );

      case TourPosition.right:
        return Offset(
          (targetPosition.dx + targetSize.width + horizontalMargin).clamp(minX, maxX),
          (targetCenter.dy - overlayHeight / 2).clamp(minY, maxY),
        );

      case TourPosition.center:
        return Offset(
          (screenSize.width - overlayWidth) / 2,
          (screenSize.height - overlayHeight) / 2,
        );
    }
  }

  /// Get current target position and size from GlobalKey or fallback values.
  static ({Offset position, Size size}) getTargetBounds({
    required TourStep step,
    required Offset fallbackPosition,
    required Size fallbackSize,
  }) {
    if (step.targetKey != null) {
      final renderBox = step.targetKey!.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;

        if (position != Offset.zero && !size.isEmpty) {
          return (position: position, size: size);
        }
      }
    }
    return (position: fallbackPosition, size: fallbackSize);
  }

  /// Calculate highlight border dimensions.
  static ({double left, double top, double width, double height}) getBorderDimensions({
    required TourStep step,
    required Offset targetPosition,
    required Size targetSize,
    required Size screenSize,
  }) {
    if (step.highlightFullScreen) {
      return (left: 0.0, top: 0.0, width: screenSize.width, height: screenSize.height);
    }
    return (
      left: targetPosition.dx - 8,
      top: targetPosition.dy - 8,
      width: targetSize.width + 16,
      height: targetSize.height + 16,
    );
  }
}
