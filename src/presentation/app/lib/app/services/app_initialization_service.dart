import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:application/features/settings/queries/get_setting_query.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:acore/utils/platform_utils.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/shared/constants/setting_keys.dart';
import 'package:application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/features/about/components/onboarding_dialog.dart';
import 'package:whph/features/about/services/abstraction/i_support_dialog_service.dart';
import 'package:whph/features/about/services/abstraction/i_changelog_dialog_service.dart';
import 'package:domain/shared/utils/logger.dart';

/// Service responsible for handling app initialization tasks
class AppInitializationService {
  static const Duration _updateCheckDelay = Duration(milliseconds: 1000);

  final Mediator _mediator;
  final ISupportDialogService _supportDialogService;
  final IChangelogDialogService _changelogDialogService;
  final ISetupService _setupService;

  AppInitializationService(
    this._mediator,
    this._supportDialogService,
    this._changelogDialogService,
    this._setupService,
  );

  bool _hasCheckedForUpdates = false;

  /// Initialize all app-level services and dialogs
  Future<void> initializeApp(GlobalKey<NavigatorState> navigatorKey) async {
    await _checkAndShowOnboarding(navigatorKey);
    await _checkAndShowChangelogDialog(navigatorKey);
    await _checkAndShowSupportDialog(navigatorKey);
    if (!PlatformUtils.isMobile) {
      await _checkForUpdates(navigatorKey);
    }
  }

  /// Check and show onboarding dialog if not completed (or always in debug mode)
  Future<void> _checkAndShowOnboarding(GlobalKey<NavigatorState> navigatorKey) async {
    final shouldShowOnboarding = await _shouldShowOnboardingDialog();
    if (shouldShowOnboarding) {
      _showOnboardingDialog(navigatorKey);
    }
  }

  /// Determine if onboarding dialog should be shown
  Future<bool> _shouldShowOnboardingDialog() async {
    try {
      final setting = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: SettingKeys.onboardingCompleted),
      );

      if (setting == null) {
        return true;
      }

      final hasCompletedOnboarding = setting.value == 'true';
      DomainLogger.info("Onboarding completed setting: $hasCompletedOnboarding");
      return !hasCompletedOnboarding;
    } catch (e) {
      DomainLogger.info('Onboarding setting not found, showing onboarding dialog. Error: $e');
      return true;
    }
  }

  void _showOnboardingDialog(GlobalKey<NavigatorState> navigatorKey) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ResponsiveDialogHelper.showResponsiveDialog(
        context: context,
        child: const OnboardingDialog(),
        isDismissible: false,
        size: DialogSize.min,
      );
    } else {
      DomainLogger.warning("Context not available for onboarding dialog");
    }
  }

  /// Check and show changelog dialog for new version
  Future<void> _checkAndShowChangelogDialog(GlobalKey<NavigatorState> navigatorKey) async {
    try {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await _changelogDialogService.checkAndShowChangelogDialog(context);
      }
    } catch (e) {
      DomainLogger.error('Error checking changelog dialog: $e');
    }
  }

  /// Check and show support dialog if conditions are met
  Future<void> _checkAndShowSupportDialog(GlobalKey<NavigatorState> navigatorKey) async {
    if (kDebugMode) {
      DomainLogger.info("Skipping support dialog in debug mode.");
      return;
    }

    try {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await _supportDialogService.checkAndShowSupportDialog(context);
      }
    } catch (e) {
      DomainLogger.error('Error checking support dialog: $e', component: 'AppInitializationService');
    }
  }

  /// Check for app updates
  Future<void> _checkForUpdates(GlobalKey<NavigatorState> navigatorKey) async {
    if (_hasCheckedForUpdates) return;

    try {
      await Future.delayed(_updateCheckDelay, () async {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          await _setupService.checkForUpdates(context);
          _hasCheckedForUpdates = true;
        }
      });
    } catch (e) {
      DomainLogger.error('Error checking for updates: $e', component: 'AppInitializationService');
      _hasCheckedForUpdates = true; // Mark as checked even if failed to avoid repeated attempts
    }
  }
}
