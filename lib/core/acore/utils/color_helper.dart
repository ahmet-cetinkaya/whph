import 'package:flutter/material.dart';

class ColorHelper {
  static Color getContrastingTextColor(
    Color backgroundColor, {
    Color darkColor = Colors.black,
    Color lightColor = Colors.white,
  }) {
    final r = (backgroundColor.r * 255.0).round() & 0xff;
    final g = (backgroundColor.g * 255.0).round() & 0xff;
    final b = (backgroundColor.b * 255.0).round() & 0xff;
    final brightness = ((r * 299) + (g * 587) + (b * 114)) / 1000;

    return brightness > 128 ? darkColor : lightColor;
  }
}
