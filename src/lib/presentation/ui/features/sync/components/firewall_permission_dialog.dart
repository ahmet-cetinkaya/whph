import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whph/presentation/api/api.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/accordion_widget.dart';
import 'package:whph/presentation/ui/features/settings/components/permission_dialog.dart';
import 'package:whph/main.dart';

/// A dialog component for showing firewall permission instructions
class FirewallPermissionDialog extends StatefulWidget {
  final String description;
  final List<PermissionInstructionSection>? instructionSections;
  final String? infoText;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionButtonText;
  final Future<void> Function()? onAutomaticAction;
  final String? automaticActionButtonText;
  final bool autoCloseAfterAutomaticAction;
  final String actionButtonText;

  const FirewallPermissionDialog({
    super.key,
    required this.description,
    this.instructionSections,
    this.infoText,
    this.onSecondaryAction,
    this.secondaryActionButtonText,
    this.onAutomaticAction,
    this.automaticActionButtonText,
    this.autoCloseAfterAutomaticAction = true,
    required this.actionButtonText,
  });

  @override
  State<FirewallPermissionDialog> createState() => _FirewallPermissionDialogState();
}

class _FirewallPermissionDialogState extends State<FirewallPermissionDialog> {
  bool _isLoading = false;
  Key _buttonKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final ITranslationService translationService = container.resolve<ITranslationService>();
    final isLinux = Platform.isLinux;
    final isWindows = Platform.isWindows;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.screenMedium, maxHeight: AppTheme.screenLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.sizeLarge),
              child: Text(
                translationService.translate(SettingsTranslationKeys.firewallPermissionTitle),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const Divider(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.sizeLarge),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.description),
                      const SizedBox(height: AppTheme.sizeMedium),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.sizeLarge),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
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
                                  child: Text(translationService.translate(SettingsTranslationKeys.instructions),
                                      style: Theme.of(context).textTheme.titleMedium),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.sizeMedium),
                            // Instructions section(s)
                            if (widget.instructionSections != null && widget.instructionSections!.isNotEmpty) ...[
                              ...widget.instructionSections!.asMap().entries.expand((sectionEntry) {
                                final sectionIndex = sectionEntry.key;
                                final section = sectionEntry.value;

                                final sectionWidgets = <Widget>[];

                                // Add section title (except for the first section to maintain backward compatibility)
                                if (sectionIndex > 0 && section.title.isNotEmpty) {
                                  sectionWidgets.addAll([
                                    const SizedBox(height: AppTheme.sizeMedium),
                                    Text(
                                      section.title,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                                ),
                                        ),
                                      ],
                                    ),
                                  );
                                }));

                                return sectionWidgets;
                              }),
                            ] else ...[
                              // Alternative: Accordion-style manual setup guide for both platforms
                              AccordionWidget(
                                title: 'Manual Setup Guide',
                                hintText: 'Click to show/hide',
                                initiallyExpanded: false,
                                content: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      translationService
                                          .translate(SettingsTranslationKeys.firewallManualConfigureInstruction),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const SizedBox(height: AppTheme.sizeMedium),

                                    if (isWindows) ...[
                                      // GUI Method for Windows
                                      Text(
                                        translationService.translate(
                                            SettingsTranslationKeys.firewallInstructionWindowsMethodGuiTitle),
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: AppTheme.sizeSmall),
                                      ..._getWindowsInstructionSections(translationService)
                                          .first
                                          .steps
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: AppTheme.sizeXSmall, left: AppTheme.sizeSmall),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${entry.key + 1}. ', style: TextStyle(fontWeight: FontWeight.w500)),
                                              Expanded(
                                                child: Text(
                                                  entry.value,
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),

                                      const SizedBox(height: AppTheme.sizeMedium),
                                    ],

                                    // Command Method for both Windows and Linux
                                    Text(
                                      isWindows
                                          ? translationService.translate(
                                              SettingsTranslationKeys.firewallInstructionWindowsMethodCommandTitle)
                                          : translationService.translate(
                                              SettingsTranslationKeys.firewallInstructionLinuxMethodTerminalTitle),
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: AppTheme.sizeSmall),
                                    Container(
                                      padding: const EdgeInsets.all(AppTheme.sizeSmall),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (isLinux) ...[
                                            Text(
                                              translationService.translate(
                                                  SettingsTranslationKeys.firewallInstructionStepOpenTerminal),
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                            const SizedBox(height: AppTheme.sizeXSmall),
                                            Text(
                                              translationService
                                                  .translate(SettingsTranslationKeys.firewallInstructionStepRunCommand),
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ] else ...[
                                            Text(
                                              translationService.translate(
                                                  SettingsTranslationKeys.firewallInstructionStepOpenCommandPrompt),
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                            const SizedBox(height: AppTheme.sizeXSmall),
                                            Text(
                                              translationService.translate(
                                                  SettingsTranslationKeys.firewallInstructionStepRunCommands),
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                          const SizedBox(height: AppTheme.sizeXSmall),
                                          if (isLinux)
                                            Padding(
                                              padding: const EdgeInsets.only(left: AppTheme.sizeSmall),
                                              child: Text(
                                                _getMainCommand(),
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      fontFamily: 'monospace',
                                                      color: Theme.of(context).colorScheme.primary,
                                                    ),
                                              ),
                                            )
                                          else
                                            ..._getMainCommand().split('\n').map((cmd) => Padding(
                                                  padding: const EdgeInsets.only(left: AppTheme.sizeSmall),
                                                  child: Text(
                                                    cmd,
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          fontFamily: 'monospace',
                                                          color: Theme.of(context).colorScheme.primary,
                                                        ),
                                                  ),
                                                )),
                                        ],
                                      ),
                                    ),
                                    if (isLinux) ...[
                                      const SizedBox(height: AppTheme.sizeMedium),
                                      Text(
                                        translationService.translate(
                                            SettingsTranslationKeys.firewallInstructionStepClickConfirmation),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Optional info text
                      if (widget.infoText != null) ...[
                        const SizedBox(height: AppTheme.sizeMedium),
                        Text(
                          widget.infoText!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(AppTheme.sizeLarge),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Secondary action button (e.g., Linux firewall manual confirmation)
                  if (widget.onSecondaryAction != null && widget.secondaryActionButtonText != null) ...[
                    FilledButton.icon(
                      onPressed: () => _performSecondaryActionAndClose(context),
                      icon: const Icon(Icons.check),
                      style: FilledButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size(0, AppTheme.buttonSizeMedium),
                        backgroundColor: Colors.green,
                      ),
                      label: Text(widget.secondaryActionButtonText!),
                    ),
                    const SizedBox(width: AppTheme.sizeSmall),
                  ],
                  // Automatic action button (e.g., Windows firewall rule addition)
                  if (widget.onAutomaticAction != null && widget.automaticActionButtonText != null) ...[
                    Builder(
                      builder: (context) {
                        return _isLoading
                            ? FilledButton.icon(
                                key: _buttonKey,
                                onPressed: null,
                                icon: SizedBox(
                                  width: AppTheme.sizeMedium,
                                  height: AppTheme.sizeMedium,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  alignment: Alignment.centerLeft,
                                  minimumSize: const Size(0, AppTheme.buttonSizeMedium),
                                  backgroundColor: Colors.green,
                                ),
                                label: Text(widget.automaticActionButtonText!),
                              )
                            : FilledButton.icon(
                                key: _buttonKey,
                                onPressed: () => _performAutomaticActionAndClose(context),
                                icon: const Icon(Icons.play_arrow),
                                style: FilledButton.styleFrom(
                                  alignment: Alignment.centerLeft,
                                  minimumSize: const Size(0, AppTheme.buttonSizeMedium),
                                  backgroundColor: Colors.green,
                                ),
                                label: Text(widget.automaticActionButtonText!),
                              );
                      },
                    ),
                    const SizedBox(width: AppTheme.sizeSmall),
                  ],
                  FilledButton(
                    onPressed: () => _requestPermissionAndClose(context),
                    style: FilledButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size(0, AppTheme.buttonSizeMedium),
                    ),
                    child: Text(widget.actionButtonText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get Windows instruction sections (simplified)
  List<PermissionInstructionSection> _getWindowsInstructionSections(ITranslationService translationService) {
    return [
      // Simplified GUI instructions
      PermissionInstructionSection(
        title: '', // No title for the main section
        steps: [
          translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStepOpenDefender),
          translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStepCreateInboundRule),
          translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStepCreateOutboundRule),
        ],
        copyableCommands: List.filled(3, ''), // No copyable commands for GUI steps
      ),
    ];
  }

  /// Get the main command for the platform
  String _getMainCommand() {
    final isLinux = Platform.isLinux;
    final isWindows = Platform.isWindows;

    if (isLinux) {
      return 'sudo ufw allow $webSocketPort/tcp';
    } else if (isWindows) {
      // Show both inbound and outbound commands for P2P sync
      final inboundCmd =
          'netsh advfirewall firewall add rule name="WHPH Sync Port $webSocketPort (Inbound)" dir=in action=allow program="${Platform.resolvedExecutable}" protocol=TCP localport=$webSocketPort';
      final outboundCmd =
          'netsh advfirewall firewall add rule name="WHPH Sync Port $webSocketPort (Outbound)" dir=out action=allow program="${Platform.resolvedExecutable}" protocol=TCP localport=$webSocketPort';
      return '$inboundCmd\n$outboundCmd';
    } else {
      return '';
    }
  }

  /// Perform secondary action and handle dialog closing
  void _performSecondaryActionAndClose(BuildContext context) {
    widget.onSecondaryAction?.call();
    if (widget.autoCloseAfterAutomaticAction) {
      Navigator.of(context).pop();
    }
  }

  /// Perform automatic action and handle dialog closing
  Future<void> _performAutomaticActionAndClose(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _buttonKey = UniqueKey();
    });
    try {
      // Ensure loading shows for at least 200ms to provide user feedback
      await Future.wait([
        widget.onAutomaticAction?.call() ?? Future.value(),
        Future.delayed(const Duration(milliseconds: 200)),
      ]);
      if (widget.autoCloseAfterAutomaticAction && mounted) {
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
      }
    } finally {
      // Ensure loading state is reset, even if dialog was closed
      if (mounted) {
        setState(() {
          _isLoading = false;
          _buttonKey = UniqueKey();
        });
      }
    }
  }

  /// Request permission and close dialog
  void _requestPermissionAndClose(BuildContext context) {
    Navigator.of(context).pop();
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
                  icon: const Icon(Icons.copy, size: AppTheme.iconSizeSmall),
                  tooltip: 'Copy command',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(AppTheme.buttonSizeXSmall, AppTheme.buttonSizeXSmall),
                    padding: const EdgeInsets.all(AppTheme.size2XSmall),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Copy command to clipboard
  Future<void> _copyCommand(BuildContext context, String command) async {
    // Implementation would go here if needed
  }
}
