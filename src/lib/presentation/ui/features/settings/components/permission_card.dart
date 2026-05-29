import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/features/settings/components/permission_dialog.dart';

class PermissionCard extends StatelessWidget {
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final bool isLoading;
  final bool showError;
  final VoidCallback onRequestPermission;

  /// Required - Dialog description for the "Fix Permission" dialog
  final String learnMoreDialogDescription;

  final List<String>? learnMoreDialogSteps;

  final List<PermissionInstructionSection>? learnMoreDialogSections;
  final String? learnMoreDialogInfoText;

  final List<String>? copyableCommands;

  final String? actionButtonText;
  final Future<void> Function()? onAutomaticAction;
  final String? automaticActionButtonText;
  final bool autoCloseAfterAutomaticAction;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionButtonText;
  final Widget? additionalDialogContent;
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
    this.autoCloseAfterAutomaticAction = true,
    this.onSecondaryAction,
    this.secondaryActionButtonText,
    this.additionalDialogContent,
    this.showInstructionsAlertBox = true,
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
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
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
            const SizedBox(height: AppTheme.sizeSmall),
            Text(
              description,
              style: theme.textTheme.bodyMedium,
            ),
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
