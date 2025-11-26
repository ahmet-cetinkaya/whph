import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';

/// Helper class for showing quick task dialogs responsively
class QuickTaskDialogHelper {
  /// Shows a quick task dialog with estimated time section
  static Future<void> showEstimatedTimeDialog({
    required BuildContext context,
    required Widget content,
  }) {
    return ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.large,
      child: content,
      isDismissible: true,
      enableDrag: true,
    );
  }

  /// Shows a quick task dialog with description section
  static Future<void> showDescriptionDialog({
    required BuildContext context,
    required Widget content,
  }) {
    return ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.large,
      child: content,
      isDismissible: true,
      enableDrag: true,
    );
  }

  /// Shows a confirmation dialog for destructive actions
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) {
    return ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.large,
      child: AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Shows a lock settings dialog
  static Future<void> showLockSettingsDialog({
    required BuildContext context,
    required Widget content,
  }) {
    return ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.large,
      child: content,
      isDismissible: true,
      enableDrag: true,
    );
  }
}
