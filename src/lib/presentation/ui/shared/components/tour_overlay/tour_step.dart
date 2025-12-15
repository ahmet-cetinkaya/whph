import 'package:flutter/material.dart';

/// Represents a single step in the guided tour.
class TourStep {
  final String title;
  final String description;
  final GlobalKey? targetKey;
  final Offset? targetPosition;
  final Size? targetSize;
  final TourHighlightShape shape;
  final TourPosition position;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final IconData? icon;
  final bool highlightFullScreen;

  const TourStep({
    required this.title,
    required this.description,
    this.targetKey,
    this.targetPosition,
    this.targetSize,
    this.shape = TourHighlightShape.rectangle,
    this.position = TourPosition.bottom,
    this.onNext,
    this.onPrevious,
    this.icon,
    this.highlightFullScreen = false,
  });
}

/// Shape option for highlighting the tour target area.
enum TourHighlightShape {
  rectangle,
  circle,
  roundedRectangle,
}

/// Position of the tour content relative to the target element.
enum TourPosition {
  top,
  bottom,
  left,
  right,
  center,
}
