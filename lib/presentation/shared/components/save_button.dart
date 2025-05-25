import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

/// A reusable save button component
class SaveButton extends StatelessWidget {
  /// Function to call when save button is pressed
  final VoidCallback onSave;

  /// Tooltip text to show on hover
  final String? tooltip;

  /// Whether there are unsaved changes
  final bool hasUnsavedChanges;

  /// Whether to show the saved message
  final bool showSavedMessage;

  /// Whether to show a vertical divider before the button
  final bool showDivider;

  /// Constructor
  const SaveButton({
    super.key,
    required this.onSave,
    this.tooltip,
    this.hasUnsavedChanges = false,
    this.showSavedMessage = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final defaultTooltip = translationService.translate(SharedTranslationKeys.saveListOptions);

    if (!showSavedMessage && !hasUnsavedChanges) {
      return const SizedBox.shrink();
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      // Divider
      if (showDivider)
        Container(
          width: 1,
          height: 24,
          color: AppTheme.surface3,
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
        ),

      // Save Button
      if (hasUnsavedChanges)
        Tooltip(
          message: tooltip ?? defaultTooltip,
          child: IconButton(
            icon: const Icon(Icons.save_outlined),
            iconSize: AppTheme.iconSizeMedium,
            color: Theme.of(context).primaryColor,
            onPressed: onSave,
          ),
        ),

      // Saved Message
      if (showSavedMessage)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.done,
              color: Colors.green,
            ),
            const SizedBox(width: AppTheme.sizeSmall),
            Text(
              translationService.translate(SharedTranslationKeys.savedButton),
              style: const TextStyle(color: Colors.green),
            ),
          ],
        ),
    ]);
  }
}
