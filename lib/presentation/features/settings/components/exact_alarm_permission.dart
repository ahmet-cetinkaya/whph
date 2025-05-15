import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/settings/components/permission_card.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

/// Widget to check and request exact alarm permission on Android 12+
class ExactAlarmPermission extends StatefulWidget {
  const ExactAlarmPermission({super.key});

  @override
  State<ExactAlarmPermission> createState() => _ExactAlarmPermissionState();
}

class _ExactAlarmPermissionState extends State<ExactAlarmPermission> {
  static final platform = MethodChannel(AndroidAppConstants.channels.exactAlarm);
  final _translationService = container.resolve<ITranslationService>();

  bool _hasExactAlarmPermission = false;
  bool _isLoading = true;
  bool _showError = false;
  bool _isAndroid12OrHigher = false;

  @override
  void initState() {
    super.initState();
    _initializePermissionCheck();
  }

  Future<void> _initializePermissionCheck() async {
    // First check Android version
    await _checkAndroidVersion();

    // Then perform the thorough permission check
    if (_isAndroid12OrHigher) {
      // Add a small delay to ensure everything is initialized
      await Future.delayed(const Duration(milliseconds: 500));
      await _performThoroughPermissionCheck();
    }
  }

  Future<void> _checkAndroidVersion() async {
    if (!Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _isAndroid12OrHigher = false;
          _hasExactAlarmPermission = true;
          _isLoading = false;
          _showError = false;
        });
      }
      return;
    }

    try {
      final androidInfo = await container.resolve<DeviceInfoPlugin>().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // Android 12 is API level 31
      final isAndroid12OrHigher = sdkInt >= 31;
      if (isAndroid12OrHigher) {
        if (mounted) {
          setState(() {
            _isAndroid12OrHigher = true;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasExactAlarmPermission = true;
            _isLoading = false;
            _showError = false;
          });
        }
      }
    } catch (e) {
      // If we can't determine the version, assume it's needed
      if (mounted) {
        setState(() {
          _isAndroid12OrHigher = true;
        });
      }
    }
  }

  Future<void> _checkPermission() async {
    // This is now just a wrapper for _performThoroughPermissionCheck
    await _performThoroughPermissionCheck();
  }

  Future<void> _performThoroughPermissionCheck() async {
    if (!Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _hasExactAlarmPermission = true;
          _isLoading = false;
          _showError = false;
        });
      }
      return;
    }

    if (!_isAndroid12OrHigher) {
      if (mounted) {
        setState(() {
          _hasExactAlarmPermission = true;
          _isLoading = false;
          _showError = false;
        });
      }
      return;
    }

    try {
      // Get Android version
      final androidInfo = await container.resolve<DeviceInfoPlugin>().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      final isAndroid12Plus = sdkInt >= 31; // Android 12 is API level 31

      // For Android 12+, we need to perform a thorough check
      if (isAndroid12Plus) {
        // Try to check the actual permission status using multiple methods
        bool actualPermissionStatus = false;
        try {
          // Use the method channel directly for a more accurate check
          final bool canSchedule = await platform.invokeMethod('canScheduleExactAlarms');

          // Also check the permission directly
          final permissionStatus = await platform.invokeMethod<int>('checkExactAlarmPermission');
          final hasDirectPermission = permissionStatus == 0; // PERMISSION_GRANTED = 0

          // Try to create a test notification to verify permission
          try {
            await platform.invokeMethod('testExactAlarmPermission');
          } catch (e) {
            // Ignore errors
          }

          // Consider permission granted if at least the API check or direct permission check passes
          actualPermissionStatus = canSchedule || hasDirectPermission;

          // Update UI based on the actual permission status
          if (mounted) {
            setState(() {
              _hasExactAlarmPermission = actualPermissionStatus;
              _isLoading = false;
              _showError = !actualPermissionStatus;
            });
          }
        } catch (e) {
          // If we can't check, assume permission is not granted and show error
          if (mounted) {
            setState(() {
              _hasExactAlarmPermission = false;
              _isLoading = false;
              _showError = true;
            });
          }
        }
      } else {
        // For Android 12-14, use the standard permission check
        final bool hasPermission = await platform.invokeMethod('canScheduleExactAlarms');

        if (mounted) {
          setState(() {
            _hasExactAlarmPermission = hasPermission;
            _isLoading = false;
            _showError = !hasPermission;
          });
        }
      }
    } catch (e) {
      // If we can't check, assume we don't have permission
      if (mounted) {
        setState(() {
          _hasExactAlarmPermission = false;
          _isLoading = false;
          _showError = true;
        });
      }
    }

    if (_hasExactAlarmPermission) {
      // Check permission status again
      Future.delayed(const Duration(seconds: 2), () {
        _checkPermission();
      });
    }
  }

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid || !_isAndroid12OrHigher) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _showError = false;
      });
    }

    try {
      await platform.invokeMethod('openExactAlarmsSettings');

      // Give more time for the user to grant permission on Android 12+
      await Future.delayed(const Duration(seconds: 5));
      await _performThoroughPermissionCheck();

      // Sometimes the first check might not reflect the latest status
      // Wait a bit more and check again multiple times with increasing delays
      for (int i = 1; i <= 3; i++) {
        if (_hasExactAlarmPermission) break;
        await Future.delayed(Duration(seconds: i));
        await _checkPermission();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showError = true;
        });
      }
    }
  }

  Future<List<String>> _getInstructionSteps() async {
    final steps = <String>[];
    final appName = AppInfo.name;

    // First step always includes the app name
    steps.add(_translationService.translate(SettingsTranslationKeys.exactAlarmStep1, namedArgs: {'appName': appName}));

    // Get device info to check Android version
    final isAndroid12Plus = await _isDeviceAndroid12Plus();

    // Add specific steps based on Android version
    if (isAndroid12Plus) {
      steps.add(_translationService.translate(SettingsTranslationKeys.exactAlarmStepAndroid12Plus2));
      steps.add(_translationService.translate(SettingsTranslationKeys.exactAlarmStepAndroid12Plus3));
    } else {
      steps.add(_translationService.translate(SettingsTranslationKeys.exactAlarmStep2));
    }

    return steps;
  }

  Future<bool> _isDeviceAndroid12Plus() async {
    if (!Platform.isAndroid) return false;

    try {
      final androidInfo = await container.resolve<DeviceInfoPlugin>().androidInfo;
      return androidInfo.version.sdkInt >= 31; // Android 12 is API level 31
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on Android 12+
    if (!Platform.isAndroid || !_isAndroid12OrHigher) return const SizedBox.shrink();

    return FutureBuilder<List<String>>(
        future: _getInstructionSteps(),
        builder: (context, snapshot) {
          final instructionSteps = snapshot.data ??
              [
                _translationService
                    .translate(SettingsTranslationKeys.exactAlarmStep1, namedArgs: {'appName': AppInfo.name}),
                _translationService.translate(SettingsTranslationKeys.exactAlarmStep2),
              ];

          return PermissionCard(
            icon: Icons.alarm,
            title: _translationService.translate(SettingsTranslationKeys.exactAlarmTitle),
            description: _translationService.translate(SettingsTranslationKeys.exactAlarmDescription),
            isGranted: _hasExactAlarmPermission,
            isLoading: _isLoading,
            showError: _showError,
            onRequestPermission: _requestPermission,
            learnMoreDialogDescription: _translationService.translate(SettingsTranslationKeys.exactAlarmDescription),
            learnMoreDialogSteps: instructionSteps,
            notGrantedText:
                _showError ? _translationService.translate(SettingsTranslationKeys.exactAlarmNotGranted) : null,
          );
        });
  }
}
