import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acore/acore.dart' show PlatformUtils;
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/components/permission_card.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

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
  bool _isInitialCheck = true;

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

    // Mark initial check as complete
    if (mounted) {
      setState(() {
        _isInitialCheck = false;
      });
    }
  }

  Future<void> _checkAndroidVersion() async {
    if (!PlatformUtils.isMobile) {
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
            // Keep loading state until permission check is complete
            _isLoading = true;
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
          _isLoading = true;
        });
      }
    }
  }

  Future<void> _checkPermission() async {
    // This is now just a wrapper for _performThoroughPermissionCheck
    await _performThoroughPermissionCheck();
  }

  Future<void> _performThoroughPermissionCheck() async {
    if (!PlatformUtils.isMobile) {
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

    // Ensure we're in loading state during permission check
    if (mounted && _isInitialCheck) {
      setState(() {
        _isLoading = true;
        _showError = false;
      });
    }

    try {
      // Get Android version
      final androidInfo = await container.resolve<DeviceInfoPlugin>().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      final isAndroid12Plus = sdkInt >= 31; // Android 12 is API level 31

      // For Android 12+, only use the reliable AlarmManager API check
      if (isAndroid12Plus) {
        try {
          // The only reliable way to check exact alarm permission is through AlarmManager API
          final bool canSchedule = await platform.invokeMethod('canScheduleExactAlarms');

          // Update UI based on the permission status
          if (mounted) {
            setState(() {
              _hasExactAlarmPermission = canSchedule;
              _isLoading = false;
              _showError = !canSchedule && !_isInitialCheck;
            });
          }
        } catch (e) {
          // If we can't check, assume permission is not granted
          if (mounted) {
            setState(() {
              _hasExactAlarmPermission = false;
              _isLoading = false;
              _showError = !_isInitialCheck;
            });
          }
        }
      } else {
        // For older Android versions, use the standard permission check
        final bool hasPermission = await platform.invokeMethod('canScheduleExactAlarms');

        if (mounted) {
          setState(() {
            _hasExactAlarmPermission = hasPermission;
            _isLoading = false;
            _showError = !hasPermission && !_isInitialCheck;
          });
        }
      }
    } catch (e) {
      // If we can't check, assume we don't have permission
      if (mounted) {
        setState(() {
          _hasExactAlarmPermission = false;
          _isLoading = false;
          _showError = !_isInitialCheck;
        });
      }
    }

    if (!_hasExactAlarmPermission && !_isInitialCheck) {
      // Check permission status again after a delay only if permission is not granted and not initial check
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_hasExactAlarmPermission && !_isInitialCheck) {
          _checkPermission();
        }
      });
    }
  }

  Future<void> _requestPermission() async {
    if (!PlatformUtils.isMobile || !_isAndroid12OrHigher) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _showError = false;
        _isInitialCheck = false; // No longer initial check after user interaction
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

    steps.add(_translationService.translate(SettingsTranslationKeys.exactAlarmStep1, namedArgs: {'appName': appName}));
    steps.add(_translationService.translate(SettingsTranslationKeys.exactAlarmStep2, namedArgs: {'appName': appName}));

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    // Only show on Android 12+ and only after version check is complete
    if (!PlatformUtils.isMobile || (!_isAndroid12OrHigher && !_isLoading)) {
      return const SizedBox.shrink();
    }

    // If still checking Android version, don't show anything yet
    if (_isInitialCheck && _isLoading && !_isAndroid12OrHigher) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<String>>(
        future: _getInstructionSteps(),
        builder: (context, snapshot) {
          final instructionSteps = snapshot.data ??
              [
                _translationService
                    .translate(SettingsTranslationKeys.exactAlarmStep1, namedArgs: {'appName': AppInfo.name}),
                _translationService
                    .translate(SettingsTranslationKeys.exactAlarmStep2, namedArgs: {'appName': AppInfo.name}),
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
          );
        });
  }
}
