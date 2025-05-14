import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/main.dart';
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
  bool _showInstructions = false;

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
        // Retry attempt
      }

      try {
        // We'll use a method channel to check battery optimization status
        final platform = MethodChannel(AndroidAppConstants.channels.batteryOptimization);
        try {
          // Call native method to check battery optimization status
          final result = await platform.invokeMethod<bool>('isIgnoringBatteryOptimizations');
          isIgnoring = result ?? false;
          // Got status from platform channel
          success = true;
          break; // Exit the retry loop if successful
        } catch (e) {
          // Failed to get status from platform channel

          // Fallback: Try to check using the package name
          try {
            final checkIntent = AndroidIntent(
              action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
              data: 'package:${AndroidAppConstants.packageName}',
            );

            // We can't directly check, so we'll use a heuristic approach
            // If the intent can be resolved, it means the app is not ignoring battery optimizations
            // (because the intent is used to request ignoring battery optimizations)
            final canResolve = await checkIntent.canResolveActivity();
            isIgnoring = canResolve != null ? !canResolve : false; // If we can't resolve, it might be already ignoring
            // Got status from intent resolution
            success = true;
            break; // Exit the retry loop if successful
          } catch (e2) {
            // Error checking with intent
            // Continue to the next retry attempt
          }
        }
      } catch (e) {
        // Error checking battery optimization status
        // Continue to the next retry attempt
      }
    }

    if (!success) {
      // All attempts to check battery optimization status failed
      isIgnoring = false;
    }

    // Final result obtained

    // Update UI
    if (mounted) {
      setState(() {
        _isIgnoringBatteryOptimizations = isIgnoring;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid) return;

    setState(() {
      _isLoading = true;
      _showInstructions = true;
    });

    // Requesting permission

    // Show a dialog to explain what the user needs to do
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap a button to dismiss
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(SettingsTranslationKeys.batteryOptimizationAlertTitle)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _translationService.translate(SettingsTranslationKeys.batteryOptimizationAlertDescription),
              ),
              const SizedBox(height: 8),
              Text(
                _translationService.translate(SettingsTranslationKeys.batteryOptimizationInstructions),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_translationService.translate(SettingsTranslationKeys.batteryOptimizationStep1)),
              Text(_translationService.translate(SettingsTranslationKeys.batteryOptimizationStep2)),
              Text(_translationService.translate(SettingsTranslationKeys.batteryOptimizationStep3)),
              Text(_translationService.translate(SettingsTranslationKeys.batteryOptimizationStep4)),
              Text(_translationService.translate(SettingsTranslationKeys.batteryOptimizationStep5)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.black87),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _translationService.translate(SettingsTranslationKeys.batteryOptimizationLocationNote),
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isLoading = false;
              });
            },
            child: Text(_translationService.translate(SettingsTranslationKeys.batteryOptimizationButtonCancel)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Try to open battery optimization settings directly using Android Intent
              try {
                // First try: Direct battery optimization settings
                try {
                  final intent = AndroidIntent(
                    action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
                  );
                  await intent.launch();
                  // Opened battery optimization settings
                } catch (e) {
                  // Error opening battery optimization settings

                  // Second try: App-specific battery optimization settings
                  try {
                    final appIntent = AndroidIntent(
                      action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
                      data: 'package:${AndroidAppConstants.packageName}',
                    );
                    await appIntent.launch();
                    // Opened app-specific battery optimization settings
                  } catch (e2) {
                    // Error opening app-specific battery optimization settings

                    // Third try: Battery settings
                    try {
                      final batteryIntent = AndroidIntent(
                        action: 'android.settings.BATTERY_SAVER_SETTINGS',
                      );
                      await batteryIntent.launch();
                      // Opened battery saver settings
                    } catch (e3) {
                      // Error opening battery saver settings

                      // Fourth try: App details
                      try {
                        final appDetailsIntent = AndroidIntent(
                          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
                          data: 'package:${AndroidAppConstants.packageName}',
                        );
                        await appDetailsIntent.launch();
                        // Opened app details settings
                      } catch (e4) {
                        // Error opening app details
                      }
                    }
                  }
                }
              } catch (e) {
                // Error with AndroidIntent

                // Fallback to URL launcher if AndroidIntent fails
                try {
                  // Try to open app settings as fallback
                  final Uri appSettingsUri = Uri.parse('package:${AndroidAppConstants.packageName}');
                  if (await canLaunchUrl(appSettingsUri)) {
                    await launchUrl(appSettingsUri);
                    // Opened app settings via URL launcher
                  }
                } catch (urlError) {
                  // Error opening settings via URL launcher
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
                // Additional check after settings
                await _checkPermission();

                // If we've detected that battery optimization is disabled, we can stop checking
                if (_isIgnoringBatteryOptimizations) {
                  // Battery optimization is now disabled, stopping additional checks
                  break;
                }
              }
            },
            child: Text(_translationService.translate(SettingsTranslationKeys.batteryOptimizationButtonOpenSettings)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show on Android
    if (!Platform.isAndroid) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.battery_alert),
                const SizedBox(width: 8),
                Text(
                  _translationService.translate(SettingsTranslationKeys.batteryOptimizationTitle),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(
                    _isIgnoringBatteryOptimizations ? Icons.check_circle : Icons.error,
                    color: _isIgnoringBatteryOptimizations ? Colors.green : Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _translationService.translate(SettingsTranslationKeys.batteryOptimizationDescription),
              style: const TextStyle(fontSize: 14),
            ),
            if (_showInstructions) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translationService.translate(SettingsTranslationKeys.batteryOptimizationInstructions),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep1),
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    Text(
                      _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep2),
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    Text(
                      _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep3),
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    Text(
                      _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep4),
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    Text(
                      _translationService.translate(SettingsTranslationKeys.batteryOptimizationStep5),
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    if (!_isIgnoringBatteryOptimizations && !_isLoading)
                      Text(
                        _translationService.translate(SettingsTranslationKeys.batteryOptimizationNotDisabled),
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isIgnoringBatteryOptimizations && !_isLoading)
                  ElevatedButton.icon(
                    onPressed: _requestPermission,
                    icon: const Icon(Icons.settings),
                    label:
                        Text(_translationService.translate(SettingsTranslationKeys.batteryOptimizationButtonDisable)),
                  ),
                if (_isIgnoringBatteryOptimizations && !_isLoading)
                  Chip(
                    label:
                        Text(_translationService.translate(SettingsTranslationKeys.batteryOptimizationStatusDisabled)),
                    backgroundColor: Colors.green,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
