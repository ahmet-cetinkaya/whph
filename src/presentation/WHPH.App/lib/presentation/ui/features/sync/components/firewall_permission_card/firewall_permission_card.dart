import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/components/permission_card.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/components/firewall_permission_card/components/manual_setup_guide.dart';
import 'package:whph/presentation/ui/features/sync/components/firewall_permission_card/controllers/firewall_permission_controller.dart';
import 'package:whph/presentation/ui/features/sync/components/firewall_permission_card/helpers/firewall_platform_helper.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/acore.dart' hide Container;

/// Widget for managing firewall permissions for sync functionality.
///
/// Uses:
/// - [FirewallPermissionController] for state management and business logic
/// - [FirewallPlatformHelper] for platform-specific operations
/// - [ManualSetupGuide] for displaying setup instructions
class FirewallPermissionCard extends StatefulWidget {
  /// Callback called when permission status changes
  final VoidCallback? onPermissionChanged;

  const FirewallPermissionCard({
    super.key,
    this.onPermissionChanged,
  });

  @override
  State<FirewallPermissionCard> createState() => _FirewallPermissionCardState();
}

class _FirewallPermissionCardState extends State<FirewallPermissionCard> {
  late final ITranslationService _translationService;
  late final FirewallPlatformHelper _platformHelper;
  late final FirewallPermissionController _controller;

  @override
  void initState() {
    super.initState();
    _translationService = container.resolve<ITranslationService>();
    _platformHelper = FirewallPlatformHelper(translationService: _translationService);
    _controller = FirewallPermissionController(
      mediator: container.resolve<Mediator>(),
      translationService: _translationService,
      platformHelper: _platformHelper,
    );

    _controller.addListener(_onControllerChanged);
    _controller.initialize();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
      widget.onPermissionChanged?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onPermissionRequest() {
    // Dialog shows instructions with copyable commands, no automatic action needed
  }

  Future<void> _onAutomaticFirewallRuleAddition() async {
    final success = await _controller.addWindowsFirewallRules(context);
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLinux = Platform.isLinux;
    final isWindows = Platform.isWindows;

    // Only show on desktop platforms with setup service
    if (!PlatformUtils.isDesktop || _controller.setupService == null || _controller.shouldHideCard) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(AppTheme.sizeSmall),
      child: Column(
        children: [
          PermissionCard(
            icon: Icons.security,
            title: _translationService.translate(SettingsTranslationKeys.firewallPermissionTitle),
            description: _translationService.translate(
              SettingsTranslationKeys.firewallPermissionDescription,
              namedArgs: {'platform': _platformHelper.getPlatformName()},
            ),
            isGranted: _controller.isFirewallPermissionGranted,
            isLoading: _controller.isLoading,
            showError: _controller.showError,
            onRequestPermission: _onPermissionRequest,
            learnMoreDialogDescription: isWindows
                ? _translationService.translate(SettingsTranslationKeys.firewallWindowsAutoDescription)
                : _translationService.translate(
                    SettingsTranslationKeys.firewallPermissionDialogDescription,
                    namedArgs: {'platform': _platformHelper.getPlatformName()},
                  ),
            learnMoreDialogInfoText:
                _translationService.translate(SettingsTranslationKeys.firewallPermissionDialogInfoText),
            additionalDialogContent: _buildAdditionalDialogContent(isWindows: isWindows, isLinux: isLinux),
            showInstructionsAlertBox: false,
            actionButtonText: _translationService.translate('shared.buttons.done'),
            onAutomaticAction: isWindows ? _onAutomaticFirewallRuleAddition : null,
            automaticActionButtonText:
                isWindows ? _translationService.translate(SettingsTranslationKeys.firewallAddRuleButtonText) : null,
            autoCloseAfterAutomaticAction: false,
            onSecondaryAction: isLinux && !_controller.isFirewallPermissionGranted
                ? () => _controller.onLinuxFirewallConfigured(context)
                : null,
            secondaryActionButtonText: isLinux && !_controller.isFirewallPermissionGranted
                ? _translationService.translate(SettingsTranslationKeys.firewallLinuxManualConfirmationButton)
                : null,
          ),
        ],
      ),
    );
  }

  Widget? _buildAdditionalDialogContent({required bool isWindows, required bool isLinux}) {
    if (_controller.isFirewallPermissionGranted) return null;
    if (!isWindows && !isLinux) return null;

    return ManualSetupGuide(
      translationService: _translationService,
      platformHelper: _platformHelper,
    );
  }
}
