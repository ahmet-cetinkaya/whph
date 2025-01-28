import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class TagUiConstants {
  // Icons
  static const IconData tagIcon = Icons.label;
  static const IconData archiveIcon = Icons.archive;
  static const IconData unarchiveIcon = Icons.unarchive;
  static const IconData colorIcon = Icons.color_lens;
  static const IconData editIcon = Icons.edit;

  // Colors
  static Color getTagColor(String? hexColor) {
    if (hexColor == null) return AppTheme.disabledColor;
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  // Dimensions
  static const EdgeInsets tagCardPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
}
