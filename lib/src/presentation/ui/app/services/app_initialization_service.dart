import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;
import 'package:whph/src/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/src/presentation/ui/features/about/components/onboarding_dialog.dart';
import 'package:whph/src/presentation/ui/features/about/services/abstraction/i_support_dialog_service.dart';
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

/// Service responsible for handling app initialization tasks
class AppInitializationService {
  static const Duration _updateCheckDelay = Duration(milliseconds: 1000);

  final Mediator _mediator;
  final ISupportDialogService _supportDialogService;
  final ISetupService _setupService;

  AppInitializationService(this._mediator, this._supportDialogService, this._setupService);

  bool _hasCheckedForUpdates = false;

  /// Initialize all app-level services and dialogs
  Future<void> initializeApp(GlobalKey<NavigatorState> navigatorKey) async {
    await _checkAndShowOnboarding(navigatorKey);
    await _checkAndShowSupportDialog(navigatorKey);
    if (!PlatformUtils.isMobile) {
      await _checkForUpdates(navigatorKey);
    }
  }

  /// Check and show onboarding dialog if not completed
  Future<void> _checkAndShowOnboarding(GlobalKey<NavigatorState> navigatorKey) async {
    if (kDebugMode) {
      Logger.info("Skipping onboarding dialog in debug mode.");
      return;
    }

    try {
      final setting = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(
        GetSettingQuery(key: SettingKeys.onboardingCompleted),
      );

      final hasCompletedOnboarding = setting.value == 'true';
      if (!hasCompletedOnboarding) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          ResponsiveDialogHelper.showResponsiveDialog(
            context: context,
            child: const OnboardingDialog(),
            isDismissible: false,
            size: DialogSize.min,
          );
        }
      }
    } catch (e) {
      // If setting doesn't exist (first time), show onboarding
      Logger.info('Onboarding setting not found, showing onboarding dialog');
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ResponsiveDialogHelper.showResponsiveDialog(
          context: context,
          child: const OnboardingDialog(),
          isDismissible: false,
          size: DialogSize.min,
        );
      }
    }
  }

  /// Check and show support dialog if conditions are met
  Future<void> _checkAndShowSupportDialog(GlobalKey<NavigatorState> navigatorKey) async {
    if (kDebugMode) {
      Logger.info("Skipping support dialog in debug mode.");
      return;
    }

    try {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await _supportDialogService.checkAndShowSupportDialog(context);
      }
    } catch (e) {
      Logger.error('Error checking support dialog: $e');
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
      Logger.error('Error checking for updates: $e');
      _hasCheckedForUpdates = true; // Mark as checked even if failed to avoid repeated attempts
    }
  }
}
