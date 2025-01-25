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

  // Labels
  static const String tagsLabel = 'Tags';
  static const String searchTagsLabel = 'Search Tags';
  static const String clearAllLabel = 'Clear All';
  static const String doneLabel = 'Done';
  static const String colorLabel = 'Color';

  // Hints
  static const String selectTagsHint = 'Select tags to associate';
  static const String newTagDefaultName = 'New Tag';
  static const String searchTagsHint = 'Search tags...';
  static const String clickToChangeColorHint = 'Click to change color';

  // Messages
  static const String noTagsFoundMessage = 'No tags found';
  static const String archiveTagTitle = 'Archive Tag';
  static const String unarchiveTagTitle = 'Unarchive Tag';
  static const String archiveTagMessage = 'Are you sure you want to archive this tag?';
  static const String unarchiveTagMessage = 'Are you sure you want to unarchive this tag?';
  static const String deleteTagTitle = 'Delete Tag';
  static const String deleteTagMessage = 'Are you sure you want to delete this tag?';

  // Error Messages
  static const String errorLoadingTags = 'Failed to load tags';
  static const String errorSavingTag = 'Failed to save tag';
  static const String errorDeletingTag = 'Failed to delete tag';
  static const String errorToggleArchive = 'Failed to toggle archive status';
  static const String errorLoadingTagName = 'Failed to load tag name';

  // Tooltips
  static const String archiveTagTooltip = 'Archive tag';
  static const String unarchiveTagTooltip = 'Unarchive tag';

  // Dimensions
  static const EdgeInsets tagCardPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
}
