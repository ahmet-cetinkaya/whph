import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

/// A data class representing an instruction section
class PermissionInstructionSection {
  /// Title of the instruction section
  final String title;

  /// Steps in this instruction section
  final List<String> steps;

  /// Optional - Commands that should have copy buttons in this section
  final List<String>? copyableCommands;

  PermissionInstructionSection({
    required this.title,
    required this.steps,
    this.copyableCommands,
  });
}

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
  final VoidCallback? onAutomaticAction;

  /// Optional - Text for the automatic action button
  final String? automaticActionButtonText;

  /// Optional - Whether to automatically close the dialog after performing the automatic action
  /// If false, the action is responsible for closing the dialog
  final bool autoCloseAfterAutomaticAction;

  /// Optional - Secondary action callback (e.g., for Linux firewall manual confirmation)
  final VoidCallback? onSecondaryAction;

  /// Optional - Text for the secondary action button
  final String? secondaryActionButtonText;

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

                    // Instructions section(s)
                    const SizedBox(height: AppTheme.sizeMedium),
                    // Use multiple sections if provided, otherwise use the single section approach
                    if (learnMoreDialogSections != null && learnMoreDialogSections!.isNotEmpty) ...[
                      ...learnMoreDialogSections!.asMap().entries.expand((sectionEntry) {
                        final sectionIndex = sectionEntry.key;
                        final section = sectionEntry.value;

                        final sectionWidgets = <Widget>[];

                        // Add section title (except for the first section to maintain backward compatibility)
                        if (sectionIndex > 0 && section.title.isNotEmpty) {
                          sectionWidgets.addAll([
                            const SizedBox(height: AppTheme.sizeMedium),
                            Text(
                              section.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppTheme.sizeSmall),
                          ]);
                        }

                        // Add section steps
                        sectionWidgets.addAll(section.steps.asMap().entries.map((stepEntry) {
                          final stepIndex = stepEntry.key;
                          final step = stepEntry.value;
                          final isCommand = section.copyableCommands != null &&
                              stepIndex < section.copyableCommands!.length &&
                              section.copyableCommands![stepIndex].isNotEmpty;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• '),
                                Expanded(
                                  child: isCommand
                                      ? _buildCommandStep(context, step, section.copyableCommands![stepIndex])
                                      : Text(
                                          step,
                                          style: TextStyle(color: theme.colorScheme.onSurface),
                                        ),
                                ),
                              ],
                            ),
                          );
                        }));

                        return sectionWidgets;
                      }),
                    ] else if (learnMoreDialogSteps != null && learnMoreDialogSteps!.isNotEmpty) ...[
                      // Fallback to single section approach for backward compatibility
                      ...learnMoreDialogSteps!.asMap().entries.map((entry) {
                        final index = entry.key;
                        final step = entry.value;
                        final isCommand = copyableCommands != null &&
                            index < copyableCommands!.length &&
                            copyableCommands![index].isNotEmpty;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• '),
                              Expanded(
                                child: isCommand
                                    ? _buildCommandStep(context, step, copyableCommands![index])
                                    : Text(
                                        step,
                                        style: TextStyle(color: theme.colorScheme.onSurface),
                                      ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      // No instructions provided
                      const SizedBox.shrink(),
                    ],
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
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Secondary action button (e.g., Linux firewall manual confirmation)
              if (onSecondaryAction != null && secondaryActionButtonText != null) ...[
                FilledButton.icon(
                  onPressed: () => _performSecondaryActionAndClose(context),
                  icon: const Icon(Icons.check),
                  style: FilledButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size(0, 36),
                    backgroundColor: Colors.green,
                  ),
                  label: Text(secondaryActionButtonText!),
                ),
                const SizedBox(width: 8),
              ],
              // Automatic action button (e.g., Windows firewall rule addition)
              if (onAutomaticAction != null && automaticActionButtonText != null) ...[
                FilledButton.icon(
                  onPressed: () => _performAutomaticActionAndClose(context),
                  icon: const Icon(Icons.play_arrow),
                  style: FilledButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size(0, 36),
                    backgroundColor: Colors.green,
                  ),
                  label: Text(automaticActionButtonText!),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton(
                onPressed: () => _requestPermissionAndClose(context),
                style: FilledButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(0, 36),
                ),
                child: Text(actionButtonText ?? _translationService.translate(SettingsTranslationKeys.openSettings)),
              ),
            ],
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

  void _performAutomaticActionAndClose(BuildContext context) {
    if (autoCloseAfterAutomaticAction) {
      Navigator.of(context).pop();
    }
    onAutomaticAction?.call();
    // If autoCloseAfterAutomaticAction is false, the action is responsible for closing the dialog
  }

  void _performSecondaryActionAndClose(BuildContext context) {
    Navigator.of(context).pop();
    onSecondaryAction?.call();
  }

  /// Copy command to clipboard
  Future<void> _copyCommand(BuildContext context, String command) async {
    await Clipboard.setData(ClipboardData(text: command));

    if (context.mounted) {
      OverlayNotificationHelper.showSuccess(
        context: context,
        message: 'Command copied to clipboard',
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Build a command step with copy functionality
  Widget _buildCommandStep(BuildContext context, String step, String command) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step text
        Text(
          step,
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),

        // Command container with copy button
        if (command.isNotEmpty) ...[
          const SizedBox(height: AppTheme.sizeSmall),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    command,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.sizeSmall),
                IconButton(
                  onPressed: () => _copyCommand(context, command),
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy command',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
