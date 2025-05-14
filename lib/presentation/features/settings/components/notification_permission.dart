import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

/// Component to display and manage notification permission settings
class NotificationPermission extends StatefulWidget {
  const NotificationPermission({super.key});

  @override
  State<NotificationPermission> createState() => _NotificationPermissionState();
}

class _NotificationPermissionState extends State<NotificationPermission> {
  final INotificationService _notificationService = container.resolve<INotificationService>();
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  bool _hasNotificationPermission = false;
  bool _isLoading = true;
  bool _showInstructions = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() {
      _isLoading = true;
    });

    // Use the new checkPermissionStatus method
    final hasPermission = await _notificationService.checkPermissionStatus();

    setState(() {
      _hasNotificationPermission = hasPermission;
      _isLoading = false;
    });
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the new requestPermission method
      final permissionGranted = await _notificationService.requestPermission();

      setState(() {
        _hasNotificationPermission = permissionGranted;
        // Only show instructions if permission wasn't automatically granted
        _showInstructions = !permissionGranted && (Platform.isAndroid || Platform.isIOS);
      });

      // If permission wasn't granted, show a dialog with manual instructions
      if (!permissionGranted && (Platform.isAndroid || Platform.isIOS)) {
        _showManualInstructionsDialog();
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showManualInstructionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(SettingsTranslationKeys.notificationPermissionAlertTitle)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Platform.isAndroid
                    ? _translationService.translate(SettingsTranslationKeys.notificationPermissionDescription)
                    : _translationService.translate(SettingsTranslationKeys.notificationPermissionDescription),
              ),
              const SizedBox(height: 8),
              Text(
                _translationService.translate(SettingsTranslationKeys.notificationPermissionInstructions),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (Platform.isAndroid) ...[
                Text(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepAndroid1)),
                Text(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepAndroid2)),
              ] else if (Platform.isIOS) ...[
                Text(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepIOS1)),
                Text(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepIOS2)),
              ],
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
                        _translationService.translate(SettingsTranslationKeys.notificationPermissionImportance),
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
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
            },
            child: Text(_translationService.translate(SettingsTranslationKeys.batteryOptimizationButtonCancel)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Future.delayed(const Duration(seconds: 3));
              await _checkPermission();
            },
            child: Text(_translationService.translate(SettingsTranslationKeys.notificationPermissionButtonManual)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show on mobile platforms
    if (!Platform.isAndroid && !Platform.isIOS) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications),
                const SizedBox(width: 8),
                Text(
                  _translationService.translate(SettingsTranslationKeys.notificationPermissionTitle),
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
                    _hasNotificationPermission ? Icons.check_circle : Icons.error,
                    color: _hasNotificationPermission ? Colors.green : Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _translationService.translate(SettingsTranslationKeys.notificationPermissionDescription),
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
                      _translationService.translate(SettingsTranslationKeys.notificationPermissionInstructions),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    if (Platform.isAndroid) ...[
                      Text(
                        _translationService.translate(SettingsTranslationKeys.notificationPermissionStepAndroid1),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      Text(
                        _translationService.translate(SettingsTranslationKeys.notificationPermissionStepAndroid2),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ] else if (Platform.isIOS) ...[
                      Text(
                        _translationService.translate(SettingsTranslationKeys.notificationPermissionStepIOS1),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      Text(
                        _translationService.translate(SettingsTranslationKeys.notificationPermissionStepIOS2),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                    Text(
                      _translationService.translate(SettingsTranslationKeys.notificationPermissionStep3),
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    if (!_hasNotificationPermission && !_isLoading)
                      Text(
                        _translationService.translate(SettingsTranslationKeys.notificationPermissionNotGranted),
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
                if (!_hasNotificationPermission && !_isLoading)
                  ElevatedButton.icon(
                    onPressed: _requestPermission,
                    icon: const Icon(Icons.settings),
                    label:
                        Text(_translationService.translate(SettingsTranslationKeys.notificationPermissionButtonGrant)),
                  ),
                if (_hasNotificationPermission && !_isLoading)
                  Chip(
                    label: Text(
                        _translationService.translate(SettingsTranslationKeys.notificationPermissionStatusGranted)),
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
