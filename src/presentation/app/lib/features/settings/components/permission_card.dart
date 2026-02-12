import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/services/abstraction/i_theme_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/features/settings/components/permission_dialog.dart';

/// A shared card component for displaying permission settings with consistent UI
class PermissionCard extends StatelessWidget {
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  /// Icon to display for this permission
  final IconData icon;

  /// Title of the permission
  final String title;

  /// Description of why this permission is needed
  final String description;

  /// Whether the permission is granted
  final bool isGranted;

  /// Whether the permission check is in progress
  final bool isLoading;

  /// Whether to show error status
  final bool showError;

  /// Called when the request permission button is pressed
  final VoidCallback onRequestPermission;

  /// Required - Dialog description for the "Fix Permission" dialog
  final String learnMoreDialogDescription;

  /// Optional - Instructions steps for the "Fix Permission" dialog
  /// DEPRECATED: Use learnMoreDialogSections instead
  final List<String>? learnMoreDialogSteps;

  /// Optional - Multiple instruction sections for the "Fix Permission" dialog
  /// Each section contains a title and a list of steps
  final List<PermissionInstructionSection>? learnMoreDialogSections;

  /// Optional - Additional info text for the "Fix Permission" dialog
  final String? learnMoreDialogInfoText;

  /// Optional - Commands that should have copy buttons in the dialog
  /// DEPRECATED: Use copyableCommands in PermissionInstructionSection instead
  final List<String>? copyableCommands;

  /// Optional - Custom text for the action button (defaults to "Open Settings")
  final String? actionButtonText;

  /// Optional - Automatic action callback (e.g., for Windows firewall rule addition)
  final Future<void> Function()? onAutomaticAction;

  /// Optional - Text for the automatic action button
  final String? automaticActionButtonText;

  /// Optional - Whether to automatically close the dialog after performing the automatic action
  /// If false, the action is responsible for closing the dialog
  final bool autoCloseAfterAutomaticAction;

  /// Optional - Secondary action callback (e.g., for Linux firewall manual confirmation)
  final VoidCallback? onSecondaryAction;

  /// Optional - Text for the secondary action button
  final String? secondaryActionButtonText;

  /// Optional - Additional content to display in the dialog
  final Widget? additionalDialogContent;

  /// Optional - Whether to show the warning/info instructions box in the dialog
  /// Defaults to true. Set to false when using additionalDialogContent with custom instructions.
  final bool showInstructionsAlertBox;

  PermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.isLoading,
    required this.showError,
    required this.onRequestPermission,
    required this.learnMoreDialogDescription,
    this.learnMoreDialogSteps,
    this.learnMoreDialogSections,
    this.learnMoreDialogInfoText,
    this.copyableCommands,
    this.actionButtonText,
    this.onAutomaticAction,
    this.automaticActionButtonText,
    this.autoCloseAfterAutomaticAction = true, // Default to true for backward compatibility
    this.onSecondaryAction,
    this.secondaryActionButtonText,
    this.additionalDialogContent,
    this.showInstructionsAlertBox = true, // Default to true for backward compatibility
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and status icon
            Row(
              children: [
                // Title
                Icon(icon),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),

                // Status icon
                if (isLoading)
                  SizedBox(
                    width: AppTheme.iconSizeMedium,
                    height: AppTheme.iconSizeMedium,
                    child: CircularProgressIndicator(
                      color: _themeService.primaryColor,
                      strokeWidth: 2.0,
                    ),
                  )
                else
                  Icon(
                    isGranted ? Icons.check_circle : Icons.error,
                    color: isGranted ? Colors.green : Colors.red,
                  ),
              ],
            ),

            // Description
            const SizedBox(height: AppTheme.sizeSmall),
            Text(
              description,
              style: theme.textTheme.bodyMedium,
            ),

            // Action button
            if (!isGranted && !isLoading) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showLearnMoreDialog(context),
                    icon: const Icon(Icons.settings),
                    label: Text(_translationService.translate(SettingsTranslationKeys.permissionFixIt)),
                    style: FilledButton.styleFrom(alignment: Alignment.centerLeft, minimumSize: const Size(0, 36)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showLearnMoreDialog(BuildContext context) {
    return ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: PermissionDialog(
        title: title,
        description: learnMoreDialogDescription,
        showInstructionsAlertBox: showInstructionsAlertBox,
        sections: learnMoreDialogSections,
        steps: learnMoreDialogSteps,
        copyableCommands: copyableCommands,
        infoText: learnMoreDialogInfoText,
        additionalContent: additionalDialogContent,
        onSecondaryAction: onSecondaryAction,
        secondaryActionButtonText: secondaryActionButtonText,
        onAutomaticAction: onAutomaticAction,
        automaticActionButtonText: automaticActionButtonText,
        autoCloseAfterAutomaticAction: autoCloseAfterAutomaticAction,
        onRequestPermission: onRequestPermission,
        actionButtonText: actionButtonText,
      ),
      size: DialogSize.max,
    );
  }
}
