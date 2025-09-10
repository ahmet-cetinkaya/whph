import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/components/permission_card.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:acore/acore.dart' hide Container;

/// Widget for managing firewall permissions for sync functionality
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
  static const String _linuxFirewallManualConfirmationKey = 'linux_firewall_manually_confirmed_44040xc';
  
  // DEBUG: Simulate Windows platform for testing
  static const bool _debugSimulateWindows = false;
  
  ISetupService? _setupService;
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  final Mediator _mediator = container.resolve<Mediator>();
  bool _isFirewallPermissionGranted = false;
  bool _isCheckingFirewallPermission = false;
  bool _isManuallyConfirmed = false;
  bool _shouldHideCard = false;

  @override
  void initState() {
    super.initState();
    _initializeSetupService();
    _initializeAsync();
  }
  
  /// Initialize async operations
  Future<void> _initializeAsync() async {
    await _loadManualConfirmation();
    await _checkFirewallPermission();
  }

  /// Initialize setup service for firewall operations (desktop only)
  void _initializeSetupService() {
    if (!PlatformUtils.isDesktop) return;

    try {
      _setupService = container.resolve<ISetupService>();
    } catch (e) {
      Logger.warning('Setup service not available: $e');
    }
  }

  /// Load manual confirmation status from settings (Linux only)
  Future<void> _loadManualConfirmation() async {
    // Manual confirmation is only available for Linux
    // When debugging, simulate Windows platform
    final isLinux = _debugSimulateWindows ? false : Platform.isLinux;
    if (!isLinux) {
      _isManuallyConfirmed = false;
      return;
    }
    
    try {
      final query = GetSettingQuery(key: _linuxFirewallManualConfirmationKey);
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(query);
      
      if (mounted) {
        setState(() {
          _isManuallyConfirmed = response.getValue<bool>();
          // If manually confirmed, don't show the card at all
          if (_isManuallyConfirmed) {
            _isFirewallPermissionGranted = true;
            _shouldHideCard = true;
          }
        });
      }
      
      Logger.debug('Loaded firewall manual confirmation: $_isManuallyConfirmed');
    } catch (e) {
      // Setting doesn't exist yet, default to false
      Logger.debug('Firewall manual confirmation setting not found, defaulting to false');
      if (mounted) {
        setState(() {
          _isManuallyConfirmed = false;
        });
      }
    }
  }

  /// Save manual confirmation status to settings (Linux only)
  Future<void> _saveManualConfirmation(bool confirmed) async {
    // Manual confirmation is only available for Linux
    // When debugging, simulate Windows platform
    final isLinux = _debugSimulateWindows ? false : Platform.isLinux;
    if (!isLinux) {
      return;
    }
    
    try {
      final command = SaveSettingCommand(
        key: _linuxFirewallManualConfirmationKey,
        value: confirmed.toString(),
        valueType: SettingValueType.bool,
      );
      
      await _mediator.send<SaveSettingCommand, SaveSettingCommandResponse>(command);
      
      if (mounted) {
        setState(() {
          _isManuallyConfirmed = confirmed;
          // Update permission state based on confirmation
          if (confirmed) {
            _isFirewallPermissionGranted = true;
            // Hide card after 5 seconds when confirmed
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() {
                  _shouldHideCard = true;
                });
              }
            });
          } else {
            // Reset to automatic detection result when unchecked
            _shouldHideCard = false;
            _checkFirewallPermission();
          }
        });
        
        // Notify parent of permission change
        widget.onPermissionChanged?.call();
      }
      
      Logger.debug('Saved firewall manual confirmation: $confirmed');
    } catch (e) {
      Logger.error('Failed to save firewall manual confirmation: $e');
      
      // Show error to user
      if (mounted) {
        OverlayNotificationHelper.showError(
          context: context,
          message: _translationService.translate(SettingsTranslationKeys.firewallSaveConfirmationError),
        );
      }
    }
  }

  /// Handle when user manually configures firewall on Linux
  void _onLinuxFirewallConfigured() {
    // Save the confirmation as true
    _saveManualConfirmation(true);
  }

  /// Check if firewall rules are properly configured for sync
  Future<void> _checkFirewallPermission() async {
    if (!PlatformUtils.isDesktop || _setupService == null) {
      return;
    }

    setState(() {
      _isCheckingFirewallPermission = true;
    });

    try {
      // Check if firewall rule exists for the sync port
      final port = '44040'; // WebSocket port from api.dart
      final ruleName = 'WHPH Sync Port $port';

      final ruleExists = await _setupService!.checkFirewallRule(ruleName: ruleName);

      if (mounted) {
        setState(() {
          // Consider both automatic detection and manual confirmation
          _isFirewallPermissionGranted = ruleExists || _isManuallyConfirmed;
          _isCheckingFirewallPermission = false;
        });

        // Notify parent of permission change
        widget.onPermissionChanged?.call();
      }

      Logger.debug('Firewall permission check completed: $ruleExists');
    } catch (e) {
      Logger.error('Failed to check firewall permission: $e');
      if (mounted) {
        setState(() {
          // In case of error, still consider manual confirmation
          _isFirewallPermissionGranted = _isManuallyConfirmed;
          _isCheckingFirewallPermission = false;
        });

        widget.onPermissionChanged?.call();
      }
    }
  }

  /// Get platform name for display
  String _getPlatformName() {
    // When debugging, simulate Windows platform
    final isLinux = _debugSimulateWindows ? false : Platform.isLinux;
    final isWindows = _debugSimulateWindows ? true : Platform.isWindows;
    
    if (isLinux) return 'Linux';
    if (isWindows) return 'Windows';
    return 'Desktop';
  }

  /// Get the main command for the platform
  String _getMainCommand() {
    // When debugging, simulate Windows platform
    final isLinux = _debugSimulateWindows ? false : Platform.isLinux;
    final isWindows = _debugSimulateWindows ? true : Platform.isWindows;
    
    if (isLinux) {
      return 'sudo ufw allow 44040/tcp';
    } else if (isWindows) {
      return 'netsh advfirewall firewall add rule name="WHPH Sync Port 44040" dir=in action=allow protocol=TCP localport=44040';
    } else {
      return '';
    }
  }

  /// Get Windows instruction sections (GUI and command prompt)
  List<PermissionInstructionSection> _getWindowsInstructionSections() {
    return [
      // Primary GUI instructions
      PermissionInstructionSection(
        title: '', // No title for the first section
        steps: [
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStep1),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStep2),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStep3),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStep4),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStep5),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStep6),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStep7),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStep8),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStep9),
        ],
        copyableCommands: List.filled(9, ''), // No copyable commands for GUI steps
      ),
      // Alternative command prompt instructions
      PermissionInstructionSection(
        title: _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsAlternativeCommandPromptTitle),
        steps: [
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsAlternativeCommandPromptCmdStep1),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsAlternativeCommandPromptCmdStep2),
        ],
        copyableCommands: [
          '', // No command for "Open Command Prompt"
          _getMainCommand(), // Command prompt command
        ],
      ),
    ];
  }

  /// Get Linux instruction sections
  List<PermissionInstructionSection> _getLinuxInstructionSections() {
    return [
      PermissionInstructionSection(
        title: '', // No title for the section
        steps: [
          _translationService.translate(SettingsTranslationKeys.firewallInstructionLinuxStep1),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionLinuxStep2),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionLinuxStep3),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionLinuxStep4),
        ],
        copyableCommands: [
          '', // "Open a terminal" - no command
          'sudo ufw status', // Check firewall status
          _getMainCommand(), // Add firewall rule
          'sudo ufw status', // Verify rule was added
        ],
      ),
    ];
  }

  /// Permission request callback (dialog handles the instruction)
  void _onPermissionRequest() {
    // The dialog shows instructions with copyable commands, no automatic action needed
  }

  /// Automatic firewall rule addition for Windows
  Future<bool> _onAutomaticFirewallRuleAddition() async {
    // When debugging, simulate Windows platform
    final isWindows = _debugSimulateWindows ? true : Platform.isWindows;
    
    if (!isWindows || _setupService == null) {
      return false;
    }

    try {
      Logger.debug('Starting automatic Windows firewall rule addition');
      
      // Add firewall rule using the setup service (this will request UAC)
      await _setupService!.addFirewallRule(
        ruleName: 'WHPH Sync Port 44040',
        appPath: Platform.resolvedExecutable,
        port: '44040',
        protocol: 'TCP',
      );
      
      // Refresh the firewall permission status
      await _checkFirewallPermission();
      
      Logger.info('Automatic Windows firewall rule addition completed successfully');
      
      if (mounted) {
        OverlayNotificationHelper.showSuccess(
          context: context,
          message: _translationService.translate(SettingsTranslationKeys.firewallRuleAddedSuccess),
        );
      }
      
      return true; // Success
    } catch (e) {
      Logger.error('Failed to add Windows firewall rule automatically: $e');
      
      if (mounted) {
        OverlayNotificationHelper.showError(
          context: context,
          message: _translationService.translate(SettingsTranslationKeys.firewallRuleAddError),
        );
      }
      
      return false; // Failure
    }
  }

  /// Wrapper for automatic firewall rule addition that handles dialog closing
  Future<void> _onAutomaticFirewallRuleAdditionWithDialogControl() async {
    final success = await _onAutomaticFirewallRuleAddition();
    // Only close the dialog if the operation was successful
    if (success && mounted) {
      Navigator.of(context).pop();
    }
    // If not successful, keep the dialog open so the user can see the error and try again
  }

  @override
  Widget build(BuildContext context) {
    // Only show on desktop platforms with setup service
    // When debugging, simulate Windows platform
    final isLinux = _debugSimulateWindows ? false : Platform.isLinux;
    final isWindows = _debugSimulateWindows ? true : Platform.isWindows;
    
    if (!PlatformUtils.isDesktop || _setupService == null || _shouldHideCard) {
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
              namedArgs: {'platform': _getPlatformName()},
            ),
            isGranted: _isFirewallPermissionGranted,
            isLoading: _isCheckingFirewallPermission,
            showError: !_isFirewallPermissionGranted && !_isCheckingFirewallPermission,
            onRequestPermission: _onPermissionRequest,
            learnMoreDialogDescription: isWindows
                ? _translationService.translate(SettingsTranslationKeys.firewallWindowsAutoDescription)
                : _translationService.translate(
                    SettingsTranslationKeys.firewallPermissionDialogDescription,
                    namedArgs: {'platform': _getPlatformName()},
                  ),
            // Use multiple instruction sections for Windows and Linux
            learnMoreDialogSections: isWindows 
                ? _getWindowsInstructionSections() 
                : (isLinux ? _getLinuxInstructionSections() : null),
            learnMoreDialogInfoText:
                _translationService.translate(SettingsTranslationKeys.firewallPermissionDialogInfoText),
            actionButtonText: _translationService.translate('shared.buttons.done'),
            // Windows automatic action
            onAutomaticAction: isWindows ? _onAutomaticFirewallRuleAdditionWithDialogControl : null,
            automaticActionButtonText: isWindows
                ? _translationService.translate(SettingsTranslationKeys.firewallAddRuleButtonText)
                : null,
            // Don't automatically close the dialog after automatic action - we'll handle it manually
            autoCloseAfterAutomaticAction: false,
            // Linux manual confirmation action
            onSecondaryAction: isLinux && !_isFirewallPermissionGranted ? _onLinuxFirewallConfigured : null,
            secondaryActionButtonText: isLinux && !_isFirewallPermissionGranted
                ? _translationService.translate(SettingsTranslationKeys.firewallLinuxManualConfirmationButton)
                : null,
          ),
        ],
      ),
    );
  }
}
