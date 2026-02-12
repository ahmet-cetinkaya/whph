import 'package:flutter/material.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';

/// Builder utility for creating consistent confirmation dialogs
/// Provides reusable patterns for different confirmation scenarios
class ConfirmationDialogBuilder {
  /// Builds a standard confirmation dialog with consistent styling
  static Widget build({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    String? confirmText,
    String? cancelText,
    IconData? icon,
    Color? iconColor,
    EdgeInsets? contentPadding,
    bool barrierDismissible = true,
  }) {
    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 48,
                color: iconColor,
              ),
              const SizedBox(height: AppTheme.sizeMedium),
            ],
            Text(
              content,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      contentPadding: contentPadding ?? const EdgeInsets.all(24),
      actions: [
        TextButton(
          onPressed: () {
            onCancel?.call();
            Navigator.of(context, rootNavigator: false).pop(false);
          },
          child: Text(cancelText ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm.call();
            Navigator.of(context, rootNavigator: false).pop(true);
          },
          child: Text(confirmText ?? 'Confirm'),
        ),
      ],
    );
  }

  /// Builds a warning confirmation dialog (for destructive actions)
  static Widget buildWarning({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    String? confirmText,
    String? cancelText,
  }) {
    return build(
      context: context,
      title: title,
      content: content,
      onConfirm: onConfirm,
      onCancel: onCancel,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: Icons.warning_amber_outlined,
      iconColor: Theme.of(context).colorScheme.error,
    );
  }

  /// Builds an info confirmation dialog (for informational confirmations)
  static Widget buildInfo({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    String? confirmText,
    String? cancelText,
  }) {
    return build(
      context: context,
      title: title,
      content: content,
      onConfirm: onConfirm,
      onCancel: onCancel,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: Icons.info_outline,
      iconColor: Theme.of(context).colorScheme.primary,
    );
  }

  /// Builds a success confirmation dialog (for positive confirmations)
  static Widget buildSuccess({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    String? confirmText,
    String? cancelText,
  }) {
    return build(
      context: context,
      title: title,
      content: content,
      onConfirm: onConfirm,
      onCancel: onCancel,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: Icons.check_circle_outline,
      iconColor: Colors.green,
    );
  }

  /// Shows a standard confirmation dialog and returns the user's decision
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    IconData? icon,
    Color? iconColor,
    bool barrierDismissible = true,
    required ITranslationService translationService,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 48,
                  color: iconColor,
                ),
                const SizedBox(height: AppTheme.sizeMedium),
              ],
              Text(
                content,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText ?? translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText ?? translationService.translate(SharedTranslationKeys.confirmButton)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Shows a warning confirmation dialog for destructive actions
  static Future<bool> showWarning({
    required BuildContext context,
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    required ITranslationService translationService,
  }) async {
    return await show(
      context: context,
      title: title,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: Icons.warning_amber_outlined,
      iconColor: Theme.of(context).colorScheme.error,
      translationService: translationService,
    );
  }

  /// Shows an info confirmation dialog for informational confirmations
  static Future<bool> showInfo({
    required BuildContext context,
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    required ITranslationService translationService,
  }) async {
    return await show(
      context: context,
      title: title,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: Icons.info_outline,
      iconColor: Theme.of(context).colorScheme.primary,
      translationService: translationService,
    );
  }
}
