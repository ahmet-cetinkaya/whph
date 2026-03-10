import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:acore/acore.dart' as acore;

/// Builder utility for creating consistent priority option tiles
/// Extracted from the main dialog to promote reusability
class PriorityTileBuilder {
  /// Builds a priority option tile with consistent styling and accessibility
  static Widget buildPriorityOptionTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    Color? selectedColor,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final theme = Theme.of(context);

    // Calculate accessible text color based on background
    final Color backgroundColor =
        isSelected ? (selectedColor ?? theme.colorScheme.primaryContainer) : theme.colorScheme.surface;
    final Color textColor = acore.ColorContrastHelper.getContrastingTextColor(backgroundColor);

    return ListTile(
      leading: Icon(
        icon,
        color: iconColor,
        size: 24,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check,
              color: acore.ColorContrastHelper.getContrastingTextColor(
                selectedColor ?? theme.colorScheme.primaryContainer,
              ),
              size: 20,
            )
          : null,
      selected: isSelected,
      selectedTileColor: selectedColor ?? theme.colorScheme.primaryContainer,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  /// Builds a compact version of the priority tile for use in tighter spaces
  static Widget buildCompactPriorityOptionTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    Color? selectedColor,
  }) {
    return buildPriorityOptionTile(
      context: context,
      title: title,
      icon: icon,
      iconColor: iconColor,
      isSelected: isSelected,
      onTap: onTap,
      selectedColor: selectedColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}
