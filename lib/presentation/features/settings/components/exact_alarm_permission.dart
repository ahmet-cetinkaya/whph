import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiwi/kiwi.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/main.dart';
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
  bool _showInstructions = false;
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
      setState(() {
        _isAndroid12OrHigher = false;
        _hasExactAlarmPermission = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final androidInfo = await KiwiContainer().resolve<DeviceInfoPlugin>().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // Android 12 is API level 31
      final isAndroid12OrHigher = sdkInt >= 31;
      if (isAndroid12OrHigher) {
        setState(() {
          _isAndroid12OrHigher = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasExactAlarmPermission = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      // If we can't determine the version, assume it's needed
      setState(() {
        _isAndroid12OrHigher = true;
      });
    }
  }

  Future<void> _checkPermission() async {
    // This is now just a wrapper for _performThoroughPermissionCheck
    await _performThoroughPermissionCheck();
  }

  Future<void> _performThoroughPermissionCheck() async {
    if (!Platform.isAndroid) {
      setState(() {
        _hasExactAlarmPermission = true;
        _isLoading = false;
      });
      return;
    }

    if (!_isAndroid12OrHigher) {
      setState(() {
        _hasExactAlarmPermission = true;
        _isLoading = false;
      });
      return;
    }

    try {
      // Get Android version
      final androidInfo = await KiwiContainer().resolve<DeviceInfoPlugin>().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      final isAndroid12Plus = sdkInt >= 31; // Android 12 is API level 31

      // For Android 12+, we need to perform a thorough check
      if (isAndroid12Plus) {
        // First, check using the standard method

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
          // This is a more lenient approach to avoid false negatives
          actualPermissionStatus = canSchedule || hasDirectPermission;

          // Update UI based on the actual permission status
          setState(() {
            _hasExactAlarmPermission = actualPermissionStatus;
            _isLoading = false;
            _showInstructions = !actualPermissionStatus; // Show instructions if permission not granted
          });
        } catch (e) {
          // If we can't check, assume permission is not granted and show instructions
          setState(() {
            _hasExactAlarmPermission = false;
            _isLoading = false;
            _showInstructions = true;
          });
        }
      } else {
        // For Android 12-14, use the standard permission check
        final bool hasPermission = await platform.invokeMethod('canScheduleExactAlarms');

        setState(() {
          _hasExactAlarmPermission = hasPermission;
          _isLoading = false;
          _showInstructions = !hasPermission; // Show instructions if permission not granted
        });
      }
    } catch (e) {
      // If we can't check, assume we don't have permission
      setState(() {
        _hasExactAlarmPermission = false;
        _isLoading = false;
        _showInstructions = true;
      });
    }
  }

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid || !_isAndroid12OrHigher) return;

    setState(() {
      _isLoading = true;
      _showInstructions = true;
    });

    try {
      await platform.invokeMethod('openExactAlarmsSettings');

      // Give more time for the user to grant permission on Android 12+
      final waitTime = 5; // Use a consistent wait time for all Android 12+ devices
      await Future.delayed(Duration(seconds: waitTime));

      // Perform the thorough permission check
      await _performThoroughPermissionCheck();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showInstructions = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on Android 12+
    if (!Platform.isAndroid || !_isAndroid12OrHigher) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.alarm, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _translationService.translate(SettingsTranslationKeys.exactAlarmTitle),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<AndroidDeviceInfo>(
              future: KiwiContainer().resolve<DeviceInfoPlugin>().androidInfo,
              builder: (context, snapshot) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translationService.translate(SettingsTranslationKeys.exactAlarmDescription),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
              },
            ),
            if (_showInstructions) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translationService.translate(SettingsTranslationKeys.exactAlarmInstructions),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<AndroidDeviceInfo>(
                      future: KiwiContainer().resolve<DeviceInfoPlugin>().androidInfo,
                      builder: (context, snapshot) {
                        final isAndroid12Plus =
                            snapshot.hasData && snapshot.data!.version.sdkInt >= 31; // Android 12 is API level 31

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _translationService
                                  .translate(SettingsTranslationKeys.exactAlarmStep1)
                                  .replaceAll('WHPH', AppInfo.name),
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                            if (isAndroid12Plus) ...[
                              Text(
                                _translationService.translate(SettingsTranslationKeys.exactAlarmStepAndroid12Plus2),
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                              Text(
                                _translationService.translate(SettingsTranslationKeys.exactAlarmStepAndroid12Plus3),
                                style:
                                    const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
                              ),
                            ] else ...[
                              Text(
                                _translationService.translate(SettingsTranslationKeys.exactAlarmStep2),
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    if (!_hasExactAlarmPermission && !_isLoading)
                      Text(
                        _translationService.translate(SettingsTranslationKeys.exactAlarmNotGranted),
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FutureBuilder<AndroidDeviceInfo>(
              future: KiwiContainer().resolve<DeviceInfoPlugin>().androidInfo,
              builder: (context, snapshot) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Show "Open Settings" button when permission is not granted
                    if (!_hasExactAlarmPermission && !_isLoading)
                      ElevatedButton.icon(
                        onPressed: _requestPermission,
                        icon: const Icon(Icons.settings),
                        label:
                            Text(_translationService.translate(SettingsTranslationKeys.exactAlarmButtonOpenSettings)),
                      ),
                    // Show "Permission Granted" when permission is granted
                    if (_hasExactAlarmPermission && !_isLoading)
                      Row(
                        children: [
                          Chip(
                            label: Text(_translationService.translate(SettingsTranslationKeys.exactAlarmStatusGranted)),
                            backgroundColor: Colors.green,
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          // Add a "Verify" button to recheck permission
                          TextButton.icon(
                            onPressed: () async {
                              setState(() {
                                _isLoading = true;
                              });
                              await _checkPermission();
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: Text(_translationService.translate(SettingsTranslationKeys.exactAlarmButtonVerify)),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
