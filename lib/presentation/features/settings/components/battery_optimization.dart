import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/settings/components/permission_card.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

/// Component to display and manage battery optimization settings for reliable notifications
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

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  /// Maximum number of retries for checking battery optimization status
  static const int _maxRetries = 3;

  /// Check if the app is ignoring battery optimizations
  /// This method will retry up to [_maxRetries] times with a delay between retries
  Future<void> _checkPermission() async {
    if (!Platform.isAndroid) {
      setState(() {
        _isIgnoringBatteryOptimizations = true;
        _isLoading = false;
        _showError = false;
      });
      return;
    }

    // Check battery optimization permission
    setState(() {
      _isLoading = true;
    });

    // Try multiple times with a delay between attempts
    bool isIgnoring = false;
    bool success = false;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      if (attempt > 0) {
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }

      try {
        // We'll use a method channel to check battery optimization status
        final platform = MethodChannel(AndroidAppConstants.channels.batteryOptimization);
        try {
          // Call native method to check battery optimization status
          final result = await platform.invokeMethod<bool>('isIgnoringBatteryOptimizations');
          isIgnoring = result ?? false;
          success = true;
          break; // Exit the retry loop if successful
        } catch (e) {
          // Fallback: Try to check using the package name
          try {
            final checkIntent = AndroidIntent(
              action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
              data: 'package:${AndroidAppConstants.packageName}',
            );

            // If the intent can be resolved, it means the app is not ignoring battery optimizations
            // (because the intent is used to request ignoring battery optimizations)
            final canResolve = await checkIntent.canResolveActivity();
            isIgnoring = canResolve != null ? !canResolve : false;
            success = true;
            break; // Exit the retry loop if successful
          } catch (e2) {
            // Continue to the next retry attempt
          }
        }
      } catch (e) {
        // Continue to the next retry attempt
      }
    }

    if (!success) {
      // All attempts to check battery optimization status failed
      isIgnoring = false;
    }

    // Update UI
    if (mounted) {
      setState(() {
        _isIgnoringBatteryOptimizations = isIgnoring;
        _isLoading = false;
        _showError = !isIgnoring;
      });
    }

    if (!_isIgnoringBatteryOptimizations) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_isIgnoringBatteryOptimizations) {
          _checkPermission();
        }
      });
    }
  }

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid) return;

    setState(() {
      _isLoading = true;
      _showError = false;
    });

    await _openBatteryOptimizationSettings();
  }

  Future<void> _openBatteryOptimizationSettings() async {
    // Try to open battery optimization settings directly using Android Intent
    try {
      // First try: Direct battery optimization settings
      try {
        final intent = AndroidIntent(
          action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
        );
        await intent.launch();
      } catch (e) {
        // Second try: App-specific battery optimization settings
        try {
          final appIntent = AndroidIntent(
            action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
            data: 'package:${AndroidAppConstants.packageName}',
          );
          await appIntent.launch();
        } catch (e2) {
          // Third try: Battery settings
          try {
            final batteryIntent = AndroidIntent(
              action: 'android.settings.BATTERY_SAVER_SETTINGS',
            );
            await batteryIntent.launch();
          } catch (e3) {
            // Fourth try: App details
            try {
              final appDetailsIntent = AndroidIntent(
                action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
                data: 'package:${AndroidAppConstants.packageName}',
              );
              await appDetailsIntent.launch();
            } catch (e4) {
              // All attempts failed
            }
          }
        }
      }
    } catch (e) {
      // Fallback to URL launcher if AndroidIntent fails
      try {
        // Try to open app settings as fallback
        final Uri appSettingsUri = Uri.parse('package:${AndroidAppConstants.packageName}');
        if (await canLaunchUrl(appSettingsUri)) {
          await launchUrl(appSettingsUri);
        }
      } catch (urlError) {
        // All attempts failed
      }
    }

    // Give more time for the user to grant permission and for the system to update
    await Future.delayed(const Duration(seconds: 5));

    // Check the actual status after the user returns from settings
    await _checkPermission();

    // Sometimes the first check might not reflect the latest status
    // Wait a bit more and check again multiple times with increasing delays
    for (int i = 1; i <= 3; i++) {
      await Future.delayed(Duration(seconds: i));
      await _checkPermission();

      // If we've detected that battery optimization is disabled, we can stop checking
      if (_isIgnoringBatteryOptimizations) {
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on Android
    if (!Platform.isAndroid) return const SizedBox.shrink();

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
        _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep2),
        _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep3),
        _translationService
            .translate(SettingsTranslationKeys.batteryOptimizationStep4, namedArgs: {'appName': AppInfo.shortName}),
        _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep5),
      ],
      learnMoreDialogInfoText: _translationService.translate(SettingsTranslationKeys.batteryOptimizationLocationNote),
      notGrantedText:
          _showError ? _translationService.translate(SettingsTranslationKeys.batteryOptimizationNotGranted) : null,
    );
  }
}
