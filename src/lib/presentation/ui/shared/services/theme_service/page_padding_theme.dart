import 'package:flutter/material.dart';

/// A theme extension for controlling page-level padding consistently across the application.
class PagePaddingTheme extends ThemeExtension<PagePaddingTheme> {
  final double horizontal;
  final double vertical;

  const PagePaddingTheme({
    required this.horizontal,
    required this.vertical,
  });

  EdgeInsets get padding => EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: vertical,
      );

  @override
  PagePaddingTheme copyWith({
    double? horizontal,
    double? vertical,
  }) {
    return PagePaddingTheme(
      horizontal: horizontal ?? this.horizontal,
      vertical: vertical ?? this.vertical,
    );
  }

  @override
  PagePaddingTheme lerp(ThemeExtension<PagePaddingTheme>? other, double t) {
    if (other is! PagePaddingTheme) {
      return this;
    }
    return PagePaddingTheme(
      horizontal: lerpDouble(horizontal, other.horizontal, t) ?? horizontal,
      vertical: lerpDouble(vertical, other.vertical, t) ?? vertical,
    );
  }

  static double? lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}
