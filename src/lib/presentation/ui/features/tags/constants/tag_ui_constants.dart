import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/core/domain/features/tags/tag.dart';

class TagUiConstants {
  // Icons
  static const IconData tagIcon = Icons.label_outline;
  static const IconData archiveIcon = Icons.archive;
  static const IconData unarchiveIcon = Icons.unarchive;
  static const IconData colorIcon = Icons.color_lens;

  // Type Icons
  static const IconData labelIcon = Icons.tag;
  static const IconData contextIcon = Icons.alternate_email;
  static const IconData projectIcon = Icons.folder;

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

  /// Get icon for tag type
  static IconData getTagTypeIcon(TagType type) {
    switch (type) {
      case TagType.label:
        return labelIcon;
      case TagType.context:
        return contextIcon;
      case TagType.project:
        return projectIcon;
    }
  }
}
