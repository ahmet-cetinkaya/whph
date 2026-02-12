import 'package:flutter/material.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/components/information_card.dart';

/// Generic confirmation dialog component for clearing fields
/// Can be reused throughout the app for various confirmation scenarios
class ClearFieldsConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final IconData? icon;
  final ITranslationService translationService;
  final ThemeData theme;

  const ClearFieldsConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.icon,
    required this.translationService,
    required this.theme,
  });

  /// Convenience constructor for the specific clear fields scenario
  factory ClearFieldsConfirmationDialog.forQuickTaskClear({
    required ITranslationService translationService,
    required ThemeData theme,
  }) {
    return ClearFieldsConfirmationDialog(
      title: translationService.translate(TaskTranslationKeys.quickTaskResetConfirmTitle),
      message: translationService.translate(TaskTranslationKeys.quickTaskResetConfirmMessage),
      icon: Icons.warning_amber_outlined,
      translationService: translationService,
      theme: theme,
    );
  }

  /// Shows the confirmation dialog and returns the user's decision
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    IconData? icon,
    required ITranslationService translationService,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ClearFieldsConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        translationService: translationService,
        theme: Theme.of(context),
      ),
    );

    return result ?? false;
  }

  /// Convenience method for the quick task clear scenario
  static Future<bool> showForQuickTaskClear({
    required BuildContext context,
    required ITranslationService translationService,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ClearFieldsConfirmationDialog.forQuickTaskClear(
        translationService: translationService,
        theme: Theme.of(context),
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppTheme.sizeMedium),
          ],
          InformationCard.themed(
            context: context,
            icon: Icons.info_outline,
            text: message,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText ?? translationService.translate(SharedTranslationKeys.cancelButton)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText ?? translationService.translate(SharedTranslationKeys.confirmButton)),
        ),
      ],
    );
  }
}
