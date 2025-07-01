import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/settings/components/permission_card.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

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
  bool _isInitialCheck = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() {
      _isLoading = true;
      _showError = false;
    });

    final hasPermission = await _notificationService.checkPermissionStatus();

    setState(() {
      _hasNotificationPermission = hasPermission;
      _isLoading = false;
      _showError = !hasPermission && !_isInitialCheck;
    });

    // Mark initial check as complete
    if (_isInitialCheck) {
      setState(() {
        _isInitialCheck = false;
      });
    }

    if (!_hasNotificationPermission && !_isInitialCheck) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_hasNotificationPermission && !_isInitialCheck) {
          _checkPermission();
        }
      });
    }
  }

  List<String> _getInstructionSteps() {
    final steps = <String>[];

    if (PlatformUtils.isMobile) {
      steps.add(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepAndroid1));
      steps.add(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepAndroid2));
    } else if (Platform.isIOS) {
      steps.add(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepIOS1));
      steps.add(_translationService.translate(SettingsTranslationKeys.notificationPermissionStepIOS2));
    }

    return steps;
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
      _isInitialCheck = false; // No longer initial check after user interaction
    });

    try {
      final permissionGranted = await _notificationService.requestPermission();

      if (mounted) {
        setState(() {
          _hasNotificationPermission = permissionGranted;
          _showError = !permissionGranted && (PlatformUtils.isMobile);
        });
      }

      // Allow time for the system to process the permission change
      await Future.delayed(const Duration(seconds: 3));
      await _checkPermission();
    } catch (e) {
      Logger.error('Error requesting notification permission: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on mobile platforms
    if (!PlatformUtils.isMobile && !Platform.isIOS) return const SizedBox.shrink();

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
    );
  }
}
