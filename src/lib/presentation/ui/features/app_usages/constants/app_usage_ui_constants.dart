import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

class AppUsageUiConstants {
  // Icons
  static const IconData deviceIcon = Icons.devices;
  static const IconData tagsIcon = Icons.label;
  static const IconData colorIcon = Icons.color_lens;
  static const IconData editIcon = Icons.edit;
  static const IconData patternIcon = Icons.pattern;
  static const IconData saveIcon = Icons.save;
  static const IconData checkIcon = Icons.check;

  // Styles
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  static const double tagContainerBorderRadius = 12.0;

  // Colors
  static Color getTagColor(String? hexColor) {
    if (hexColor == null) return AppTheme.disabledColor;
    return Color(int.parse('FF$hexColor', radix: 16));
  }
}
