import 'package:flutter/material.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

/// Builds standard action buttons (Clear/Done) for dialogs
class ActionButtonsBuilder {
  static Widget build({
    required BuildContext context,
    required VoidCallback onClear,
    required VoidCallback onDone,
    String? clearText,
    String? doneText,
    MainAxisAlignment? mainAxisAlignment,
  }) {
    final translationService = container.resolve<ITranslationService>();

    return Padding(
      padding: EdgeInsets.only(top: AppTheme.sizeMedium),
      child: Row(
        mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onClear,
            child: Text(clearText ?? translationService.translate(SharedTranslationKeys.clearButton)),
          ),
          SizedBox(width: AppTheme.sizeSmall),
          ElevatedButton(
            onPressed: onDone,
            child: Text(doneText ?? translationService.translate(SharedTranslationKeys.doneButton)),
          ),
        ],
      ),
    );
  }

  /// Builds a single action button
  static Widget buildSingle({
    required BuildContext context,
    required VoidCallback onPressed,
    required String text,
    bool isPrimary = true,
    Widget? icon,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: AppTheme.sizeMedium),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isPrimary)
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: icon ?? const SizedBox.shrink(),
              label: Text(text),
            )
          else
            TextButton.icon(
              onPressed: onPressed,
              icon: icon ?? const SizedBox.shrink(),
              label: Text(text),
            ),
        ],
      ),
    );
  }

  /// Builds action buttons with spacing between them
  static Widget buildWithSpacing({
    required BuildContext context,
    required VoidCallback onClear,
    required VoidCallback onDone,
    double spacing = AppTheme.sizeSmall,
    String? clearText,
    String? doneText,
  }) {
    final translationService = container.resolve<ITranslationService>();

    return Padding(
      padding: EdgeInsets.only(top: AppTheme.sizeMedium),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: TextButton(
              onPressed: onClear,
              child: Text(clearText ?? translationService.translate(SharedTranslationKeys.clearButton)),
            ),
          ),
          SizedBox(width: spacing),
          ElevatedButton(
            onPressed: onDone,
            child: Text(doneText ?? translationService.translate(SharedTranslationKeys.doneButton)),
          ),
        ],
      ),
    );
  }
}
