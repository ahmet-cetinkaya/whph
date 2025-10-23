import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/api/api.dart';
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
import 'package:whph/presentation/ui/shared/components/accordion_widget.dart';

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
  static final String _linuxFirewallManualConfirmationKey = 'linux_firewall_manually_confirmed_$webSocketPort';

  ISetupService? _setupService;
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  final Mediator _mediator = container.resolve<Mediator>();
  bool _isFirewallPermissionGranted = false;
  bool _isCheckingFirewallPermission = false;
  bool _isVerifyingPermission = false;
  bool _isManuallyConfirmed = false;
  bool _shouldHideCard = false;

  @override
  void initState() {
    super.initState();
    Logger.info('🔒 [PERMISSION_CARD] initState() called');
    _initializeSetupService();
    // Start with checking state to prevent showing error state before check completes
    _isCheckingFirewallPermission = true;
    Logger.debug('🔒 [PERMISSION_CARD] Initial state set - checking firewall permission');
    _initializeAsync();
  }

  /// Initialize async operations
  Future<void> _initializeAsync() async {
    Logger.info('🔒 [PERMISSION_CARD] _initializeAsync() starting...');
    Logger.debug('🔒 [PERMISSION_CARD] Step 1: Loading manual confirmation...');
    await _loadManualConfirmation();
    Logger.debug('🔒 [PERMISSION_CARD] Step 2: Checking firewall permission...');
    await _checkFirewallPermission();
    Logger.info('🔒 [PERMISSION_CARD] _initializeAsync() completed');
  }

  /// Initialize setup service for firewall operations (desktop only)
  void _initializeSetupService() {
    Logger.debug('🔒 [PERMISSION_CARD] _initializeSetupService() called');
    if (!PlatformUtils.isDesktop) {
      Logger.debug('🔒 [PERMISSION_CARD] Not a desktop platform - skipping setup service initialization');
      return;
    }

    try {
      _setupService = container.resolve<ISetupService>();
      Logger.info('✅ [PERMISSION_CARD] Setup service initialized: ${_setupService.runtimeType}');
    } catch (e) {
      Logger.warning('⚠️ [PERMISSION_CARD] Setup service not available: $e');
    }
  }

  /// Load manual confirmation status from settings (Linux only)
  Future<void> _loadManualConfirmation() async {
    // Manual confirmation is only available for Linux
    // Manual confirmation is only available for Linux
    final isLinux = Platform.isLinux;
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

      // Also check if actual firewall rules exist, which should take precedence
      if (!_isManuallyConfirmed) {
        await _checkFirewallPermission();
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
    // Manual confirmation is only available for Linux
    final isLinux = Platform.isLinux;
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
        if (confirmed) {
          // First check if actual firewall rules exist (which should take precedence)
          await _checkFirewallPermission();

          if (mounted) {
            setState(() {
              _isManuallyConfirmed = confirmed;
              _isFirewallPermissionGranted = true;

              // If firewall rules actually exist, hide immediately
              // Otherwise, hide after 5 seconds when manually confirmed
              if (!_shouldHideCard) {
                // Only set timer if not already hidden by actual rules
                Future.delayed(const Duration(seconds: 5), () {
                  if (mounted) {
                    setState(() {
                      _shouldHideCard = true;
                    });
                  }
                });
              }
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isManuallyConfirmed = confirmed;
              _shouldHideCard = false;
            });
          }
          // Reset to automatic detection result when unchecked
          await _checkFirewallPermission();
        }

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
    Logger.debug('🔒 [PERMISSION_CARD] _checkFirewallPermission() called');
    Logger.debug('🔒 [PERMISSION_CARD] isDesktop: ${PlatformUtils.isDesktop}, setupService: ${_setupService != null}');

    if (!PlatformUtils.isDesktop || _setupService == null) {
      Logger.debug('🔒 [PERMISSION_CARD] Skipping firewall check - not desktop or no setup service');
      return;
    }

    setState(() {
      _isCheckingFirewallPermission = true;
      _isVerifyingPermission = false; // Reset verification state during regular check
    });

    Logger.info('🔒 [PERMISSION_CARD] Starting firewall permission check...');

    try {
      // Check if both inbound and outbound firewall rules exist for the sync port
      final port = webSocketPort.toString();
      final inboundRuleName = 'WHPH Sync Port $port (Inbound)';
      final outboundRuleName = 'WHPH Sync Port $port (Outbound)';

      Logger.debug('🔒 [PERMISSION_CARD] WebSocket port: $port');
      Logger.debug('🔒 [PERMISSION_CARD] Checking rules:');
      Logger.debug('🔒 [PERMISSION_CARD]   - Inbound: $inboundRuleName');
      Logger.debug('🔒 [PERMISSION_CARD]   - Outbound: $outboundRuleName');

      Logger.info('🔒 [PERMISSION_CARD] Querying inbound firewall rule...');
      final inboundRuleExists = await _setupService!.checkFirewallRule(ruleName: inboundRuleName);
      Logger.info('🔒 [PERMISSION_CARD] Inbound rule exists: $inboundRuleExists');

      Logger.info('🔒 [PERMISSION_CARD] Querying outbound firewall rule...');
      final outboundRuleExists = await _setupService!.checkFirewallRule(ruleName: outboundRuleName);
      Logger.info('🔒 [PERMISSION_CARD] Outbound rule exists: $outboundRuleExists');

      // For P2P sync, we need both inbound and outbound rules
      final bothRulesExist = inboundRuleExists && outboundRuleExists;
      Logger.info('🔒 [PERMISSION_CARD] Both rules exist: $bothRulesExist');

      if (mounted) {
        setState(() {
          // Consider both automatic detection and manual confirmation
          _isFirewallPermissionGranted = bothRulesExist || _isManuallyConfirmed;
          _isCheckingFirewallPermission = false;

          // Hide card immediately if both rules exist (meaning firewall rules already configured)
          if (bothRulesExist) {
            _shouldHideCard = true;
            Logger.info('✅ [PERMISSION_CARD] Firewall rules detected - HIDING CARD');
          } else {
            Logger.info('⚠️ [PERMISSION_CARD] Firewall rules NOT complete - SHOWING CARD');
            if (!inboundRuleExists) Logger.info('⚠️ [PERMISSION_CARD]   Missing: Inbound rule');
            if (!outboundRuleExists) Logger.info('⚠️ [PERMISSION_CARD]   Missing: Outbound rule');
          }
        });

        // Notify parent of permission change
        widget.onPermissionChanged?.call();
      }

      Logger.info(
          '✅ [PERMISSION_CARD] Firewall permission check completed: inbound=$inboundRuleExists, outbound=$outboundRuleExists, both=$bothRulesExist, granted=$_isFirewallPermissionGranted, hideCard=$_shouldHideCard');
    } catch (e) {
      Logger.error('❌ [PERMISSION_CARD] Failed to check firewall permission: $e');
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

  /// Initiates the permission verification process after successful firewall addition
  Future<void> _initiatePermissionVerification() async {
    Logger.debug('Initiating permission verification process');

    // Update component state to reflect pending verification status
    if (mounted) {
      setState(() {
        _isVerifyingPermission = true;
        _isCheckingFirewallPermission = false; // Clear regular check state
      });
    }

    try {
      // Execute permission validation against the firewall configuration API
      await _validateFirewallConfiguration();

      Logger.info('Permission verification completed successfully');
    } catch (e) {
      Logger.error('Permission verification failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingPermission = false;
        });
      }
    }
  }

  /// Validates firewall configuration against the API
  Future<void> _validateFirewallConfiguration() async {
    Logger.info('✔️ [PERMISSION_CARD] _validateFirewallConfiguration() starting...');
    Logger.debug('✔️ [PERMISSION_CARD] isDesktop: ${PlatformUtils.isDesktop}, setupService: ${_setupService != null}');

    if (!PlatformUtils.isDesktop || _setupService == null) {
      Logger.debug('✔️ [PERMISSION_CARD] Skipping validation - not desktop or no setup service');
      return;
    }

    // Check if both inbound and outbound firewall rules exist for the sync port
    final port = webSocketPort.toString();
    final inboundRuleName = 'WHPH Sync Port $port (Inbound)';
    final outboundRuleName = 'WHPH Sync Port $port (Outbound)';

    Logger.debug('✔️ [PERMISSION_CARD] Validating rules:');
    Logger.debug('✔️ [PERMISSION_CARD]   - Inbound: $inboundRuleName');
    Logger.debug('✔️ [PERMISSION_CARD]   - Outbound: $outboundRuleName');

    // Sometimes firewall rules take a moment to be fully applied by the system
    // So we'll try multiple times with a delay
    bool inboundRuleExists = false;
    bool outboundRuleExists = false;
    bool bothRulesExist = false;
    int attempts = 0;
    const maxAttempts = 5;
    const delayBetweenAttempts = Duration(milliseconds: 500);

    Logger.info('✔️ [PERMISSION_CARD] Starting validation loop (max $maxAttempts attempts)...');

    while (attempts < maxAttempts) {
      attempts++;
      Logger.debug('✔️ [PERMISSION_CARD] Validation attempt $attempts/$maxAttempts');

      Logger.info('✔️ [PERMISSION_CARD] Checking inbound rule...');
      inboundRuleExists = await _setupService!.checkFirewallRule(ruleName: inboundRuleName);
      Logger.info('✔️ [PERMISSION_CARD]   Inbound exists: $inboundRuleExists');

      Logger.info('✔️ [PERMISSION_CARD] Checking outbound rule...');
      outboundRuleExists = await _setupService!.checkFirewallRule(ruleName: outboundRuleName);
      Logger.info('✔️ [PERMISSION_CARD]   Outbound exists: $outboundRuleExists');

      bothRulesExist = inboundRuleExists && outboundRuleExists;

      Logger.info(
          '✔️ [PERMISSION_CARD] Validation attempt $attempts: inbound=$inboundRuleExists, outbound=$outboundRuleExists, both=$bothRulesExist');

      if (bothRulesExist) {
        // Both rules exist, we can stop checking
        Logger.info('✅ [PERMISSION_CARD] Both rules found - validation successful!');
        break;
      } else {
        if (attempts < maxAttempts) {
          Logger.debug('⏳ [PERMISSION_CARD] Waiting ${delayBetweenAttempts.inMilliseconds}ms before next attempt...');
          await Future.delayed(delayBetweenAttempts);
        }
      }
    }

    if (mounted) {
      setState(() {
        // Update permission state based on validation result
        _isFirewallPermissionGranted = bothRulesExist || _isManuallyConfirmed;
        Logger.info('✔️ [PERMISSION_CARD] Permission granted: $_isFirewallPermissionGranted');

        // If firewall permission is granted after verification, hide the card after a short delay
        if (_isFirewallPermissionGranted && !bothRulesExist && _isManuallyConfirmed) {
          // This case is when manual confirmation was the reason for granting permission
          Logger.info('✔️ [PERMISSION_CARD] Permission granted by manual confirmation - scheduling hide after 5s');
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _shouldHideCard = true;
                Logger.info('✅ [PERMISSION_CARD] Hiding card (manual confirmation)');
              });
            }
          });
        } else if (_isFirewallPermissionGranted && bothRulesExist) {
          // This case is when both rules exist after verification
          // Hide the card immediately since rules already existed
          _shouldHideCard = true;
          Logger.info('✅ [PERMISSION_CARD] Hiding card immediately (both rules detected)');
        }
      });

      // Notify parent of permission change
      widget.onPermissionChanged?.call();
    }

    Logger.info(
        '✅ [PERMISSION_CARD] Firewall configuration validation completed after $attempts attempts: inbound=$inboundRuleExists, outbound=$outboundRuleExists, both=$bothRulesExist');
  }

  /// Get platform name for display
  String _getPlatformName() {
    // Manual confirmation is only available for Linux
    final isLinux = Platform.isLinux;
    final isWindows = Platform.isWindows;

    if (isLinux) return 'Linux';
    if (isWindows) return 'Windows';
    return 'Desktop';
  }

  /// Get the main command for the platform
  String _getMainCommand() {
    // Manual confirmation is only available for Linux
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

  /// Get Windows instruction sections (simplified)
  List<PermissionInstructionSection> _getWindowsInstructionSections() {
    return [
      // Simplified GUI instructions
      PermissionInstructionSection(
        title: '', // No title for the main section
        steps: [
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStepOpenDefender),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStepCreateInboundRule),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStepCreateOutboundRule),
        ],
        copyableCommands: List.filled(3, ''), // No copyable commands for GUI steps
      ),
      // Command prompt alternative
      PermissionInstructionSection(
        title: 'Command Prompt (Alternative)',
        steps: [
          'Open Command Prompt as Administrator and run:',
        ],
        copyableCommands: [
          '', // No command for opening CMD
          _getMainCommand(), // The actual commands
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
    Logger.info('🔧 [PERMISSION_CARD] _onAutomaticFirewallRuleAddition() called');
    final isWindows = Platform.isWindows;
    Logger.debug('🔧 [PERMISSION_CARD] isWindows: $isWindows, setupService: ${_setupService != null}');

    if (!isWindows || _setupService == null) {
      Logger.warning('⚠️ [PERMISSION_CARD] Skipping firewall rule addition - not Windows or no setup service');
      return false;
    }

    try {
      Logger.info('🔧 [PERMISSION_CARD] Starting automatic Windows firewall rule addition');
      Logger.debug('🔧 [PERMISSION_CARD] Port: $webSocketPort');
      Logger.debug('🔧 [PERMISSION_CARD] Executable: ${Platform.resolvedExecutable}');

      // Add both inbound and outbound firewall rules for P2P sync in a single operation
      // Inbound: allow other devices to connect to this device (server mode)
      // Outbound: allow this device to connect to other devices (client mode)
      Logger.info('🔧 [PERMISSION_CARD] Calling setupService.addFirewallRules()...');
      await _setupService!.addFirewallRules(
        ruleNamePrefix: 'WHPH Sync Port $webSocketPort',
        appPath: Platform.resolvedExecutable,
        port: webSocketPort.toString(),
        protocol: 'TCP',
      );
      Logger.info('✅ [PERMISSION_CARD] Firewall rules added successfully');

      // After successful addition, initiate permission verification process
      Logger.info('🔧 [PERMISSION_CARD] Initiating permission verification...');
      await _initiatePermissionVerification();
      Logger.info('✅ [PERMISSION_CARD] Permission verification completed');

      Logger.info('✅ [PERMISSION_CARD] Automatic Windows firewall rule addition completed successfully');

      if (mounted) {
        OverlayNotificationHelper.showSuccess(
          context: context,
          message: _translationService.translate(SettingsTranslationKeys.firewallRuleAddedSuccess),
        );
      }

      return true; // Success
    } catch (e) {
      Logger.error('❌ [PERMISSION_CARD] Failed to add Windows firewall rule automatically: $e');

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
    // Manual confirmation is only available for Linux
    final isLinux = Platform.isLinux;
    final isWindows = Platform.isWindows;

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
            isLoading: _isCheckingFirewallPermission || _isVerifyingPermission,
            showError: !_isFirewallPermissionGranted && !_isCheckingFirewallPermission && !_isVerifyingPermission,
            onRequestPermission: _onPermissionRequest,
            learnMoreDialogDescription: isWindows
                ? _translationService.translate(SettingsTranslationKeys.firewallWindowsAutoDescription)
                : _translationService.translate(
                    SettingsTranslationKeys.firewallPermissionDialogDescription,
                    namedArgs: {'platform': _getPlatformName()},
                  ),
            // Use accordion with manual guide for both Windows and Linux
            learnMoreDialogInfoText:
                _translationService.translate(SettingsTranslationKeys.firewallPermissionDialogInfoText),
            // Add accordion with manual guide for both Windows and Linux
            additionalDialogContent: (!_isFirewallPermissionGranted && (isWindows || isLinux))
                ? AccordionWidget(
                    title: 'Manual Setup Guide',
                    hintText: 'Click to show/hide',
                    initiallyExpanded: false,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _translationService.translate(SettingsTranslationKeys.firewallManualConfigureInstruction),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: AppTheme.sizeMedium),

                        if (isWindows) ...[
                          // GUI Method for Windows
                          Text(
                            _translationService
                                .translate(SettingsTranslationKeys.firewallInstructionWindowsMethodGuiTitle),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: AppTheme.sizeSmall),
                          ..._getWindowsInstructionSections()[0].steps.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppTheme.sizeXSmall, left: AppTheme.sizeSmall),
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
                              ? _translationService
                                  .translate(SettingsTranslationKeys.firewallInstructionWindowsMethodCommandTitle)
                              : _translationService
                                  .translate(SettingsTranslationKeys.firewallInstructionLinuxMethodTerminalTitle),
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
                                  _translationService
                                      .translate(SettingsTranslationKeys.firewallInstructionStepOpenTerminal),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: AppTheme.sizeXSmall),
                                Text(
                                  _translationService
                                      .translate(SettingsTranslationKeys.firewallInstructionStepRunCommand),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ] else ...[
                                Text(
                                  _translationService
                                      .translate(SettingsTranslationKeys.firewallInstructionStepOpenCommandPrompt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: AppTheme.sizeXSmall),
                                Text(
                                  _translationService
                                      .translate(SettingsTranslationKeys.firewallInstructionStepRunCommands),
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
                            _translationService
                                .translate(SettingsTranslationKeys.firewallInstructionStepClickConfirmation),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  )
                : null,
            // Don't show the redundant warning/info box when we have the accordion guide
            showInstructionsAlertBox: false,
            actionButtonText: _translationService.translate('shared.buttons.done'),
            // Windows automatic action
            onAutomaticAction: isWindows ? _onAutomaticFirewallRuleAdditionWithDialogControl : null,
            automaticActionButtonText:
                isWindows ? _translationService.translate(SettingsTranslationKeys.firewallAddRuleButtonText) : null,
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
