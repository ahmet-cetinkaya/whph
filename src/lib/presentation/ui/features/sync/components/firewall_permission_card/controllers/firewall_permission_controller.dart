import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/api/api.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/components/firewall_permission_card/helpers/firewall_platform_helper.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:acore/acore.dart' hide Container;

/// Controller for managing firewall permission state and operations.
///
/// Handles:
/// - Firewall permission checking and verification
/// - Manual confirmation for Linux platforms
/// - Automatic firewall rule addition for Windows
class FirewallPermissionController extends ChangeNotifier {
  static final String _linuxFirewallManualConfirmationKey = 'linux_firewall_manually_confirmed_$webSocketPort';

  final Mediator _mediator;
  final ITranslationService _translationService;
  final FirewallPlatformHelper _platformHelper;
  ISetupService? _setupService;

  bool _isFirewallPermissionGranted = false;
  bool _isCheckingFirewallPermission = false;
  bool _isVerifyingPermission = false;
  bool _isManuallyConfirmed = false;
  bool _shouldHideCard = false;

  // Getters
  bool get isFirewallPermissionGranted => _isFirewallPermissionGranted;
  bool get isCheckingFirewallPermission => _isCheckingFirewallPermission;
  bool get isVerifyingPermission => _isVerifyingPermission;
  bool get isManuallyConfirmed => _isManuallyConfirmed;
  bool get shouldHideCard => _shouldHideCard;
  bool get isLoading => _isCheckingFirewallPermission || _isVerifyingPermission;
  bool get showError => !_isFirewallPermissionGranted && !_isCheckingFirewallPermission && !_isVerifyingPermission;
  ISetupService? get setupService => _setupService;

  FirewallPermissionController({
    required Mediator mediator,
    required ITranslationService translationService,
    required FirewallPlatformHelper platformHelper,
  })  : _mediator = mediator,
        _translationService = translationService,
        _platformHelper = platformHelper {
    _isCheckingFirewallPermission = true;
  }

  /// Initialize the controller with setup service and load initial state
  Future<void> initialize() async {
    Logger.info('[PERMISSION_CONTROLLER] initialize() starting...');
    _initializeSetupService();
    await _loadManualConfirmation();
    await checkFirewallPermission();
    Logger.info('[PERMISSION_CONTROLLER] initialize() completed');
  }

  void _initializeSetupService() {
    Logger.debug('[PERMISSION_CONTROLLER] _initializeSetupService() called');
    if (!PlatformUtils.isDesktop) {
      Logger.debug('[PERMISSION_CONTROLLER] Not a desktop platform - skipping');
      return;
    }

    try {
      _setupService = container.resolve<ISetupService>();
      Logger.info('[PERMISSION_CONTROLLER] Setup service initialized: ${_setupService.runtimeType}');
    } catch (e) {
      Logger.warning('[PERMISSION_CONTROLLER] Setup service not available: $e');
    }
  }

  Future<void> _loadManualConfirmation() async {
    if (!Platform.isLinux) {
      _isManuallyConfirmed = false;
      return;
    }

    try {
      final query = GetSettingQuery(key: _linuxFirewallManualConfirmationKey);
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(query);

      _isManuallyConfirmed = response.getValue<bool>();
      if (_isManuallyConfirmed) {
        _isFirewallPermissionGranted = true;
        _shouldHideCard = true;
      }
      notifyListeners();

      if (!_isManuallyConfirmed) {
        await checkFirewallPermission();
      }

      Logger.debug('[PERMISSION_CONTROLLER] Loaded manual confirmation: $_isManuallyConfirmed');
    } catch (e) {
      Logger.debug('[PERMISSION_CONTROLLER] Manual confirmation setting not found, defaulting to false');
      _isManuallyConfirmed = false;
      notifyListeners();
    }
  }

  /// Save manual confirmation status (Linux only)
  Future<void> saveManualConfirmation(bool confirmed, BuildContext context) async {
    if (!Platform.isLinux) return;

    try {
      final command = SaveSettingCommand(
        key: _linuxFirewallManualConfirmationKey,
        value: confirmed.toString(),
        valueType: SettingValueType.bool,
      );

      await _mediator.send<SaveSettingCommand, SaveSettingCommandResponse>(command);

      if (confirmed) {
        await checkFirewallPermission();
        _isManuallyConfirmed = confirmed;
        _isFirewallPermissionGranted = true;

        if (!_shouldHideCard) {
          Future.delayed(const Duration(seconds: 5), () {
            _shouldHideCard = true;
            notifyListeners();
          });
        }
      } else {
        _isManuallyConfirmed = confirmed;
        _shouldHideCard = false;
        await checkFirewallPermission();
      }
      notifyListeners();

      Logger.debug('[PERMISSION_CONTROLLER] Saved manual confirmation: $confirmed');
    } catch (e) {
      Logger.error('[PERMISSION_CONTROLLER] Failed to save manual confirmation: $e');
      if (context.mounted) {
        OverlayNotificationHelper.showError(
          context: context,
          message: _translationService.translate(SettingsTranslationKeys.firewallSaveConfirmationError),
        );
      }
    }
  }

  /// Called when user manually configures firewall on Linux
  void onLinuxFirewallConfigured(BuildContext context) {
    saveManualConfirmation(true, context);
  }

  /// Check if firewall rules are properly configured
  Future<void> checkFirewallPermission() async {
    Logger.debug('[PERMISSION_CONTROLLER] checkFirewallPermission() called');

    if (!PlatformUtils.isDesktop || _setupService == null) {
      Logger.debug('[PERMISSION_CONTROLLER] Skipping - not desktop or no setup service');
      return;
    }

    _isCheckingFirewallPermission = true;
    _isVerifyingPermission = false;
    notifyListeners();

    Logger.info('[PERMISSION_CONTROLLER] Starting firewall permission check...');

    try {
      final inboundRuleName = _platformHelper.getInboundRuleName();
      final outboundRuleName = _platformHelper.getOutboundRuleName();

      Logger.debug('[PERMISSION_CONTROLLER] Checking rules: $inboundRuleName, $outboundRuleName');

      final inboundRuleExists = await _setupService!.checkFirewallRule(ruleName: inboundRuleName);
      final outboundRuleExists = await _setupService!.checkFirewallRule(ruleName: outboundRuleName);
      final bothRulesExist = inboundRuleExists && outboundRuleExists;

      _isFirewallPermissionGranted = bothRulesExist || _isManuallyConfirmed;
      _isCheckingFirewallPermission = false;

      if (bothRulesExist) {
        _shouldHideCard = true;
        Logger.info('[PERMISSION_CONTROLLER] Firewall rules detected - HIDING CARD');
      } else {
        Logger.info('[PERMISSION_CONTROLLER] Firewall rules NOT complete - SHOWING CARD');
      }

      notifyListeners();

      Logger.info(
          '[PERMISSION_CONTROLLER] Check completed: granted=$_isFirewallPermissionGranted, hideCard=$_shouldHideCard');
    } catch (e) {
      Logger.error('[PERMISSION_CONTROLLER] Failed to check firewall permission: $e');
      _isFirewallPermissionGranted = _isManuallyConfirmed;
      _isCheckingFirewallPermission = false;
      notifyListeners();
    }
  }

  /// Add Windows firewall rules automatically
  Future<bool> addWindowsFirewallRules(BuildContext context) async {
    Logger.info('[PERMISSION_CONTROLLER] addWindowsFirewallRules() called');

    if (!Platform.isWindows || _setupService == null) {
      Logger.warning('[PERMISSION_CONTROLLER] Skipping - not Windows or no setup service');
      return false;
    }

    try {
      Logger.info('[PERMISSION_CONTROLLER] Adding firewall rules...');

      await _setupService!.addFirewallRules(
        ruleNamePrefix: 'WHPH Sync Port $webSocketPort',
        appPath: Platform.resolvedExecutable,
        port: webSocketPort.toString(),
        protocol: 'TCP',
      );

      Logger.info('[PERMISSION_CONTROLLER] Firewall rules added, initiating verification...');
      await _initiatePermissionVerification();

      if (context.mounted) {
        OverlayNotificationHelper.showSuccess(
          context: context,
          message: _translationService.translate(SettingsTranslationKeys.firewallRuleAddedSuccess),
        );
      }

      return true;
    } catch (e) {
      Logger.error('[PERMISSION_CONTROLLER] Failed to add firewall rules: $e');

      if (context.mounted) {
        OverlayNotificationHelper.showError(
          context: context,
          message: _translationService.translate(SettingsTranslationKeys.firewallRuleAddError),
        );
      }

      return false;
    }
  }

  Future<void> _initiatePermissionVerification() async {
    Logger.debug('[PERMISSION_CONTROLLER] Initiating permission verification');

    _isVerifyingPermission = true;
    _isCheckingFirewallPermission = false;
    notifyListeners();

    try {
      await _validateFirewallConfiguration();
      Logger.info('[PERMISSION_CONTROLLER] Permission verification completed');
    } catch (e) {
      Logger.error('[PERMISSION_CONTROLLER] Permission verification failed: $e');
    } finally {
      _isVerifyingPermission = false;
      notifyListeners();
    }
  }

  Future<void> _validateFirewallConfiguration() async {
    Logger.info('[PERMISSION_CONTROLLER] _validateFirewallConfiguration() starting...');

    if (!PlatformUtils.isDesktop || _setupService == null) return;

    final inboundRuleName = _platformHelper.getInboundRuleName();
    final outboundRuleName = _platformHelper.getOutboundRuleName();

    bool inboundRuleExists = false;
    bool outboundRuleExists = false;
    bool bothRulesExist = false;
    int attempts = 0;
    const maxAttempts = 5;
    const delayBetweenAttempts = Duration(milliseconds: 500);

    Logger.info('[PERMISSION_CONTROLLER] Starting validation loop (max $maxAttempts attempts)...');

    while (attempts < maxAttempts) {
      attempts++;
      Logger.debug('[PERMISSION_CONTROLLER] Validation attempt $attempts/$maxAttempts');

      inboundRuleExists = await _setupService!.checkFirewallRule(ruleName: inboundRuleName);
      outboundRuleExists = await _setupService!.checkFirewallRule(ruleName: outboundRuleName);
      bothRulesExist = inboundRuleExists && outboundRuleExists;

      Logger.info(
          '[PERMISSION_CONTROLLER] Attempt $attempts: inbound=$inboundRuleExists, outbound=$outboundRuleExists');

      if (bothRulesExist) {
        Logger.info('[PERMISSION_CONTROLLER] Both rules found - validation successful!');
        break;
      } else if (attempts < maxAttempts) {
        await Future.delayed(delayBetweenAttempts);
      }
    }

    _isFirewallPermissionGranted = bothRulesExist || _isManuallyConfirmed;

    if (_isFirewallPermissionGranted && !bothRulesExist && _isManuallyConfirmed) {
      Logger.info('[PERMISSION_CONTROLLER] Permission granted by manual confirmation - scheduling hide');
      Future.delayed(const Duration(seconds: 5), () {
        _shouldHideCard = true;
        notifyListeners();
      });
    } else if (_isFirewallPermissionGranted && bothRulesExist) {
      _shouldHideCard = true;
      Logger.info('[PERMISSION_CONTROLLER] Hiding card immediately (both rules detected)');
    }

    notifyListeners();

    Logger.info('[PERMISSION_CONTROLLER] Validation completed after $attempts attempts');
  }
}
