import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';

/// A shared card component for displaying permission settings with consistent UI
class PermissionCard extends StatelessWidget {
  final ITranslationService _translationService = container.resolve<ITranslationService>();

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

  /// Required - Instructions steps for the "Fix Permission" dialog
  final List<String> learnMoreDialogSteps;

  /// Optional - Additional info text for the "Fix Permission" dialog
  final String? learnMoreDialogInfoText;

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
    required this.learnMoreDialogSteps,
    this.learnMoreDialogInfoText,
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
                      color: AppTheme.primaryColor,
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
                    style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size(0, 36),
                        foregroundColor: AppTheme.darkTextColor),
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
    final theme = Theme.of(context);
    return ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(learnMoreDialogDescription),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(AppTheme.sizeLarge),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: AppTheme.fontSizeXLarge,
                        ),
                        const SizedBox(width: AppTheme.sizeSmall),
                        Expanded(
                          child: Text(_translationService.translate(SettingsTranslationKeys.instructions),
                              style: theme.textTheme.titleMedium),
                        ),
                      ],
                    ),

                    // Instructions section with steps
                    const SizedBox(height: AppTheme.sizeMedium),
                    ...learnMoreDialogSteps.map((step) => Padding(
                          padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• '),
                              Expanded(
                                child: Text(
                                  step,
                                  style: TextStyle(color: theme.colorScheme.onSurface),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),

              // Optional info text
              if (learnMoreDialogInfoText != null) ...[
                const SizedBox(height: 16),
                Text(
                  learnMoreDialogInfoText!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _dismissDialog(context),
            child: Text(_translationService.translate(SettingsTranslationKeys.commonCancel)),
          ),
          FilledButton(
            onPressed: () => _requestPermissionAndClose(context),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, 36),
              foregroundColor: AppTheme.darkTextColor,
            ),
            child: Text(_translationService.translate(SettingsTranslationKeys.openSettings)),
          ),
        ],
      ),
      size: DialogSize.min,
    );
  }

  void _dismissDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _requestPermissionAndClose(BuildContext context) {
    Navigator.of(context).pop();
    onRequestPermission();
  }
}
