import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/settings/components/permission_card.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

/// Component to display and manage startup/auto-start permission settings on Android
class StartupPermission extends StatefulWidget {
  const StartupPermission({super.key});

  @override
  State<StartupPermission> createState() => _StartupPermissionState();
}

class _StartupPermissionState extends State<StartupPermission> {
  final IStartupSettingsService _startupService = container.resolve<IStartupSettingsService>();
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  bool _hasStartupPermission = false;
  bool _isLoading = true;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (!Platform.isAndroid) {
      setState(() {
        _hasStartupPermission = true;
        _isLoading = false;
        _showError = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final hasPermission = await _startupService.isEnabledAtStartup();

      setState(() {
        _hasStartupPermission = hasPermission;
        _isLoading = false;
        _showError = !hasPermission;
      });
    } catch (e) {
      setState(() {
        _hasStartupPermission = false;
        _isLoading = false;
        _showError = true;
      });
    }

    // Periodic check for permission status updates
    if (!_hasStartupPermission) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_hasStartupPermission) {
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

    try {
      // This will open the system settings for auto-start
      await _startupService.enableStartAtStartup();

      // Give time for the user to enable the setting and return
      await Future.delayed(const Duration(seconds: 3));
      await _checkPermission();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showError = true;
      });
    }
  }

  List<String> _getInstructionSteps() {
    final steps = <String>[];

    // Android-specific instructions
    steps.add(_translationService.translate(SettingsTranslationKeys.startupStep1));
    steps.add(_translationService.translate(SettingsTranslationKeys.startupStep2));
    steps.add(_translationService.translate(SettingsTranslationKeys.startupStep3));

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    // Only show on Android
    if (!Platform.isAndroid) return const SizedBox.shrink();

    final instructionSteps = _getInstructionSteps();

    return PermissionCard(
      icon: Icons.launch,
      title: _translationService.translate(SettingsTranslationKeys.startupPermissionTitle),
      description: _translationService.translate(SettingsTranslationKeys.startupDescription),
      isGranted: _hasStartupPermission,
      isLoading: _isLoading,
      showError: _showError,
      onRequestPermission: _requestPermission,
      // Dialog parameters
      learnMoreDialogDescription: _translationService.translate(SettingsTranslationKeys.startupDescription),
      learnMoreDialogSteps: instructionSteps,
      learnMoreDialogInfoText: _translationService.translate(SettingsTranslationKeys.startupImportance),
      notGrantedText: _showError ? _translationService.translate(SettingsTranslationKeys.startupNotGranted) : null,
    );
  }
}
