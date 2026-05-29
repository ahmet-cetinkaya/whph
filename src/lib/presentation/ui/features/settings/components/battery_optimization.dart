import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:acore/acore.dart' show PlatformUtils;
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/components/permission_card.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class BatteryOptimization extends StatefulWidget {
  const BatteryOptimization({super.key});

  @override
  State<BatteryOptimization> createState() => _BatteryOptimizationState();
}

class _BatteryOptimizationState extends State<BatteryOptimization> {
  final _translationService = container.resolve<ITranslationService>();
  bool _isIgnoringBatteryOptimizations = false;
  bool _isLoading = true;
  bool _showError = false;
  bool _isInitialCheck = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  static const int _maxRetries = 3;

  Future<void> _checkPermission() async {
    if (!PlatformUtils.isMobile) {
      setState(() {
        _isIgnoringBatteryOptimizations = true;
        _isLoading = false;
        _showError = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool isIgnoring = false;
    bool success = false;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }

      try {
        final platform = MethodChannel(AndroidAppConstants.channels.batteryOptimization);
        try {
          final result = await platform.invokeMethod<bool>('isIgnoringBatteryOptimizations');
          isIgnoring = result ?? false;
          success = true;
          break;
        } catch (e) {
          // Fallback: Check via package name intent
          try {
            final checkIntent = AndroidIntent(
              action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
              data: 'package:${AndroidAppConstants.packageName}',
            );

            // If intent is resolvable, optimizations are NOT being ignored
            final canResolve = await checkIntent.canResolveActivity();
            isIgnoring = canResolve != null ? !canResolve : false;
            success = true;
            break;
          } catch (e2) {}
        }
      } catch (e) {}
    }

    if (mounted) {
      setState(() {
        _isIgnoringBatteryOptimizations = isIgnoring;
        _isLoading = false;
        _showError = !isIgnoring && !_isInitialCheck;
      });
    }

    if (mounted && _isInitialCheck) {
      setState(() {
        _isInitialCheck = false;
      });
    }

    if (!_isIgnoringBatteryOptimizations && !_isInitialCheck) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_isIgnoringBatteryOptimizations && !_isInitialCheck) {
          _checkPermission();
        }
      });
    }
  }

  Future<void> _requestPermission() async {
    if (!PlatformUtils.isMobile) return;

    setState(() {
      _isLoading = true;
      _showError = false;
      _isInitialCheck = false;
    });

    await _openBatteryOptimizationSettings();
  }

  Future<void> _openBatteryOptimizationSettings() async {
    // Try multiple intent actions in order of specificity
    try {
      try {
        final intent = AndroidIntent(
          action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
        );
        await intent.launch();
      } catch (e) {
        try {
          final appIntent = AndroidIntent(
            action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
            data: 'package:${AndroidAppConstants.packageName}',
          );
          await appIntent.launch();
        } catch (e2) {
          try {
            final batteryIntent = AndroidIntent(
              action: 'android.settings.BATTERY_SAVER_SETTINGS',
            );
            await batteryIntent.launch();
          } catch (e3) {
            try {
              final appDetailsIntent = AndroidIntent(
                action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
                data: 'package:${AndroidAppConstants.packageName}',
              );
              await appDetailsIntent.launch();
            } catch (e4) {}
          }
        }
      }
    } catch (e) {
      // Fallback to URL launcher when AndroidIntent fails
      try {
        final Uri appSettingsUri = Uri.parse('package:${AndroidAppConstants.packageName}');
        if (await canLaunchUrl(appSettingsUri)) {
          await launchUrl(appSettingsUri);
        }
      } catch (urlError) {}
    }

    // Give time for permission to propagate before checking status
    await Future.delayed(const Duration(seconds: 5));
    await _checkPermission();

    // Re-check multiple times with increasing delays since the first check may lag
    for (int i = 1; i <= 3; i++) {
      await Future.delayed(Duration(seconds: i));
      await _checkPermission();

      if (_isIgnoringBatteryOptimizations) {
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isMobile) return const SizedBox.shrink();

    return PermissionCard(
      icon: Icons.battery_alert,
      title: _translationService.translate(SettingsTranslationKeys.batteryOptimizationTitle),
      description: _translationService.translate(SettingsTranslationKeys.batteryOptimizationDescription),
      isGranted: _isIgnoringBatteryOptimizations,
      isLoading: _isLoading,
      showError: _showError,
      onRequestPermission: _requestPermission,
      // Dialog parameters
      learnMoreDialogDescription: _translationService.translate(SettingsTranslationKeys.batteryOptimizationDescription),
      learnMoreDialogSteps: [
        _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep1),
        _translationService
            .translate(SettingsTranslationKeys.batteryOptimizationStep2, namedArgs: {'appName': AppInfo.name}),
        _translationService
            .translate(SettingsTranslationKeys.batteryOptimizationStep3, namedArgs: {'appName': AppInfo.name}),
        _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep4),
        _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep5),
        _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep6),
      ],
      learnMoreDialogInfoText: _translationService.translate(SettingsTranslationKeys.batteryOptimizationImportance),
    );
  }
}
