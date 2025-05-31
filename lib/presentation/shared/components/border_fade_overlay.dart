import 'package:flutter/material.dart';

/// Defines which borders should have fade effects
enum FadeBorder {
  left,
  right,
  top,
  bottom,
}

/// A generic wrapper that adds gradient fade-out effects to widget borders
/// to indicate that more content is available in the fade direction.
/// Commonly used with scrollable widgets like ListView, TabBar, etc.
class BorderFadeOverlay extends StatelessWidget {
  const BorderFadeOverlay({
    super.key,
    required this.child,
    this.fadeWidth = 32.0,
    this.fadeBorders = const {FadeBorder.right},
    this.backgroundColor,
  });

  /// The widget to wrap with fade effects
  final Widget child;

  /// The width/height of the gradient fade-out effect
  final double fadeWidth;

  /// Set of borders that should have fade effects
  final Set<FadeBorder> fadeBorders;

  /// Background color for the gradient. If null, uses theme's scaffold background color
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: fadeBorders.contains(FadeBorder.left) ? fadeWidth / 3 : 0,
            right: fadeBorders.contains(FadeBorder.right) ? fadeWidth / 3 : 0,
            top: fadeBorders.contains(FadeBorder.top) ? fadeWidth / 3 : 0,
            bottom: fadeBorders.contains(FadeBorder.bottom) ? fadeWidth / 3 : 0,
          ),
          child: child,
        ),

        // Left fade
        if (fadeBorders.contains(FadeBorder.left))
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: fadeWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    bgColor.withValues(alpha: 0),
                    bgColor,
                  ],
                ),
              ),
            ),
          ),

        // Right fade
        if (fadeBorders.contains(FadeBorder.right))
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: fadeWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    bgColor.withValues(alpha: 0),
                    bgColor,
                  ],
                ),
              ),
            ),
          ),

        // Top fade
        if (fadeBorders.contains(FadeBorder.top))
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: fadeWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    bgColor.withValues(alpha: 0),
                    bgColor,
                  ],
                ),
              ),
            ),
          ),

        // Bottom fade
        if (fadeBorders.contains(FadeBorder.bottom))
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: fadeWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor.withValues(alpha: 0),
                    bgColor,
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
