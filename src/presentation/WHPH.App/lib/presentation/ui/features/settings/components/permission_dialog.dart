import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'automatic_action_button.dart';

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

class PermissionDialog extends StatelessWidget {
  final String title;
  final String description;
  final bool showInstructionsAlertBox;
  final List<PermissionInstructionSection>? sections;
  final List<String>? steps; // Deprecated, for backward compatibility
  final List<String>? copyableCommands; // Deprecated, for backward compatibility
  final String? infoText;
  final Widget? additionalContent;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionButtonText;
  final Future<void> Function()? onAutomaticAction;
  final String? automaticActionButtonText;
  final bool autoCloseAfterAutomaticAction;
  final VoidCallback onRequestPermission;
  final String? actionButtonText;

  final ITranslationService _translationService = container.resolve<ITranslationService>();

  PermissionDialog({
    super.key,
    required this.title,
    required this.description,
    this.showInstructionsAlertBox = true,
    this.sections,
    this.steps,
    this.copyableCommands,
    this.infoText,
    this.additionalContent,
    this.onSecondaryAction,
    this.secondaryActionButtonText,
    this.onAutomaticAction,
    this.automaticActionButtonText,
    this.autoCloseAfterAutomaticAction = true,
    required this.onRequestPermission,
    this.actionButtonText,
  });

  void _dismissDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _requestPermissionAndClose(BuildContext context) {
    Navigator.of(context).pop();
    onRequestPermission();
  }

  Future<void> _performAutomaticActionAndClose(BuildContext context) async {
    await onAutomaticAction?.call();
    if (autoCloseAfterAutomaticAction) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _performSecondaryActionAndClose(BuildContext context) {
    Navigator.of(context).pop();
    onSecondaryAction?.call();
  }

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

  Widget _buildCommandStep(BuildContext context, String step, String command) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step,
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.sizeMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description),
                  const SizedBox(height: 16),
                  if (showInstructionsAlertBox) ...[
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
                                child: Text(
                                  _translationService.translate(SettingsTranslationKeys.instructions),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.sizeMedium),
                          if (sections != null && sections!.isNotEmpty) ...[
                            ...sections!.asMap().entries.expand((sectionEntry) {
                              final sectionIndex = sectionEntry.key;
                              final section = sectionEntry.value;
                              final sectionWidgets = <Widget>[];

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
                          ] else if (steps != null && steps!.isNotEmpty) ...[
                            ...steps!.asMap().entries.map((entry) {
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
                          ],
                        ],
                      ),
                    ),
                    if (infoText != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        infoText!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                  if (additionalContent != null) ...[
                    const SizedBox(height: 16),
                    additionalContent!,
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _dismissDialog(context),
                  child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
                ),
                const SizedBox(width: 8),
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
                if (onAutomaticAction != null && automaticActionButtonText != null) ...[
                  AutomaticActionButton(
                    label: automaticActionButtonText!,
                    onPressed: () => _performAutomaticActionAndClose(context),
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
          ),
        ],
      ),
    );
  }
}
