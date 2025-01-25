import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class AppUsageUiConstants {
  // Icons
  static const IconData deviceIcon = Icons.devices;
  static const IconData tagsIcon = Icons.label;
  static const IconData colorIcon = Icons.color_lens;
  static const IconData editIcon = Icons.edit;
  static const IconData patternIcon = Icons.pattern;
  static const IconData helpIcon = Icons.help_outline;
  static const IconData saveIcon = Icons.save;
  static const IconData checkIcon = Icons.check;

  // Labels
  static const String deviceLabel = 'Device';
  static const String tagsLabel = 'Tags';
  static const String colorLabel = 'Color';
  static const String patternLabel = 'Pattern';
  static const String patternsLabel = 'Patterns';
  static const String unknownDeviceLabel = 'Unknown Device';

  // Hints
  static const String selectTagsHint = 'Select tags to associate';
  static const String clickToChangeColorHint = 'Click to change color';
  static const String patternHint = 'e.g., .*Chrome.*\n.*Firefox.*\n.*Edge.*';
  static const String onePatternPerLineHint =
      '• Enter one pattern per line\n• Each line will be treated as a separate rule';

  // Messages
  static const String noRulesFoundMessage = 'No rules found';
  static const String noAppUsageDataMessage = 'No app usage data found';
  static const String deleteRuleConfirmTitle = 'Delete Rule';
  static const String deleteAppUsageConfirmTitle = 'Delete App Usage';

  // Button Labels
  static const String addButtonLabel = 'Add';
  static const String saveButtonLabel = 'Save';
  static const String savedButtonLabel = 'Saved';
  static const String patternHelpTooltip = 'Pattern Help';
  static const String deleteRuleTooltip = 'Delete rule';

  // Error Messages
  static const String errorLoadingAppUsage = 'Failed to load app usage';
  static const String errorSavingAppUsage = 'Failed to save app usage';
  static const String errorLoadingTags = 'Error occurred while getting app usage tags';
  static const String errorAddingRule = 'Error occurred while adding rule';
  static const String errorDeletingRule = 'Error occurred while deleting rule';

  static String getDeleteRuleConfirmMessage(String pattern) => 'Are you sure you want to delete the rule "$pattern"?';

  static String getDeleteAppUsageConfirmMessage(String name) =>
      'Are you sure you want to delete the app usage "$name"?';

  // Styles
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  static const double tagContainerBorderRadius = 12.0;
  static const double iconSize = 18.0;

  // Colors
  static Color getTagColor(String? hexColor) {
    if (hexColor == null) return AppTheme.disabledColor;
    return Color(int.parse('FF$hexColor', radix: 16));
  }
}
