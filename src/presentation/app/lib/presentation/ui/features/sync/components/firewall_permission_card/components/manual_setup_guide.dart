import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/components/firewall_permission_card/helpers/firewall_platform_helper.dart';
import 'package:whph/presentation/ui/shared/components/accordion_widget.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Widget that displays the manual setup guide for firewall configuration.
///
/// Shows platform-specific instructions for Windows (GUI and CLI) and Linux (terminal).
class ManualSetupGuide extends StatelessWidget {
  final ITranslationService translationService;
  final FirewallPlatformHelper platformHelper;

  const ManualSetupGuide({
    super.key,
    required this.translationService,
    required this.platformHelper,
  });

  @override
  Widget build(BuildContext context) {
    final isWindows = Platform.isWindows;
    final isLinux = Platform.isLinux;

    return AccordionWidget(
      title: 'Manual Setup Guide',
      hintText: 'Click to show/hide',
      initiallyExpanded: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translationService.translate(SettingsTranslationKeys.firewallManualConfigureInstruction),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppTheme.sizeMedium),
          if (isWindows) ..._buildWindowsGuiInstructions(context),
          _buildCommandInstructions(context, isWindows: isWindows, isLinux: isLinux),
          if (isLinux) ...[
            const SizedBox(height: AppTheme.sizeMedium),
            Text(
              translationService.translate(SettingsTranslationKeys.firewallInstructionStepClickConfirmation),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildWindowsGuiInstructions(BuildContext context) {
    final sections = platformHelper.getWindowsInstructionSections();
    final guiSection = sections.isNotEmpty ? sections[0] : null;

    if (guiSection == null) return [];

    return [
      Text(
        translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsMethodGuiTitle),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      const SizedBox(height: AppTheme.sizeSmall),
      ...guiSection.steps.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.sizeXSmall, left: AppTheme.sizeSmall),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${entry.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.w500)),
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
    ];
  }

  Widget _buildCommandInstructions(BuildContext context, {required bool isWindows, required bool isLinux}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isWindows
              ? translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsMethodCommandTitle)
              : translationService.translate(SettingsTranslationKeys.firewallInstructionLinuxMethodTerminalTitle),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppTheme.sizeSmall),
        Container(
          padding: const EdgeInsets.all(AppTheme.sizeSmall),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLinux) ...[
                Text(
                  translationService.translate(SettingsTranslationKeys.firewallInstructionStepOpenTerminal),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTheme.sizeXSmall),
                Text(
                  translationService.translate(SettingsTranslationKeys.firewallInstructionStepRunCommand),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else ...[
                Text(
                  translationService.translate(SettingsTranslationKeys.firewallInstructionStepOpenCommandPrompt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTheme.sizeXSmall),
                Text(
                  translationService.translate(SettingsTranslationKeys.firewallInstructionStepRunCommands),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppTheme.sizeXSmall),
              ..._buildCommandDisplay(context, isLinux: isLinux),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCommandDisplay(BuildContext context, {required bool isLinux}) {
    final command = platformHelper.getMainCommand();

    if (isLinux) {
      return [
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.sizeSmall),
          child: Text(
            command,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
      ];
    }

    return command.split('\n').map((cmd) {
      return Padding(
        padding: const EdgeInsets.only(left: AppTheme.sizeSmall),
        child: Text(
          cmd,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
    }).toList();
  }
}
