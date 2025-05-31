import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/models/tag_time_category.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class TagUiConstants {
  // Icons
  static const IconData tagIcon = Icons.label_outline;
  static const IconData archiveIcon = Icons.archive;
  static const IconData unarchiveIcon = Icons.unarchive;
  static const IconData colorIcon = Icons.color_lens;

  // Colors
  static Color getTagColor(String? hexColor) {
    if (hexColor == null) return AppTheme.disabledColor;
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  // Dimensions
  static const EdgeInsets tagCardPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  static IconData getTagTimeCategoryIcon(TagTimeCategory category) {
    switch (category) {
      case TagTimeCategory.all:
        return Icons.all_inclusive;
      case TagTimeCategory.tasks:
        return Icons.task;
      case TagTimeCategory.appUsage:
        return Icons.apps;
      case TagTimeCategory.habits:
        return Icons.repeat;
    }
  }
}
