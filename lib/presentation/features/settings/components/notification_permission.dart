import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/settings/components/permission_card.dart';
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
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() {
      _isLoading = true;
    });

    final hasPermission = await _notificationService.checkPermissionStatus();

    setState(() {
      _hasNotificationPermission = hasPermission;
      _isLoading = false;
      _showError = !hasPermission;
    });

    if (!_hasNotificationPermission) {
      Future.delayed(const Duration(seconds: 2), () {
        _checkPermission();
      });
    }
  }

  List<String> _getInstructionSteps() {
    final steps = <String>[];

    if (Platform.isAndroid) {
      steps.add(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepAndroid1));
      steps.add(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepAndroid2));
    } else if (Platform.isIOS) {
      steps.add(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepIOS1));
      steps.add(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepIOS2));
    }

    steps.add(_translationService.translate(SettingsTranslationKeys.notificationPermissionStep3));

    return steps;
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final permissionGranted = await _notificationService.requestPermission();

      setState(() {
        _hasNotificationPermission = permissionGranted;
        _showError = !permissionGranted && (Platform.isAndroid || Platform.isIOS);
      });

      // Allow time for the system to process the permission change
      await Future.delayed(const Duration(seconds: 3));
      await _checkPermission();
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on mobile platforms
    if (!Platform.isAndroid && !Platform.isIOS) return const SizedBox.shrink();

    final instructionSteps = _getInstructionSteps();

    return PermissionCard(
      icon: Icons.notifications,
      title: _translationService.translate(SettingsTranslationKeys.notificationPermissionTitle),
      description: _translationService.translate(SettingsTranslationKeys.notificationPermissionDescription),
      isGranted: _hasNotificationPermission,
      isLoading: _isLoading,
      showError: _showError,
      onRequestPermission: _requestPermission,
      // Dialog parameters
      learnMoreDialogDescription:
          _translationService.translate(SettingsTranslationKeys.notificationPermissionDescription),
      learnMoreDialogSteps: instructionSteps,
      learnMoreDialogInfoText: _translationService.translate(SettingsTranslationKeys.notificationPermissionImportance),
      notGrantedText:
          _showError ? _translationService.translate(SettingsTranslationKeys.notificationPermissionNotGranted) : null,
    );
  }
}
