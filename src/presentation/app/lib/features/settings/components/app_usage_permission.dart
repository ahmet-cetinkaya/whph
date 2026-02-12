import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show PlatformUtils;
import 'package:application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:domain/shared/constants/app_info.dart';
import 'package:whph/main.dart';
import 'package:whph/features/settings/components/permission_card.dart';
import 'package:whph/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';

/// Component to display and manage app usage permission settings
class AppUsagePermission extends StatefulWidget {
  final VoidCallback? onPermissionGranted;

  const AppUsagePermission({super.key, this.onPermissionGranted});

  @override
  State<AppUsagePermission> createState() => _AppUsagePermissionState();
}

class _AppUsagePermissionState extends State<AppUsagePermission> {
  final _translationService = container.resolve<ITranslationService>();
  final _appUsageService = container.resolve<IAppUsageService>();

  bool _hasAppUsagePermission = false;
  bool _isLoading = true;
  bool _showError = false;
  bool _isInitialCheck = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (!PlatformUtils.isMobile) {
      if (mounted) {
        setState(() {
          _hasAppUsagePermission = true;
          _isLoading = false;
          _showError = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _showError = false;
      });
    }

    try {
      final hasPermission = await _appUsageService.checkUsageStatsPermission();
      final wasPermissionGranted = !_hasAppUsagePermission && hasPermission;

      if (mounted) {
        setState(() {
          _hasAppUsagePermission = hasPermission;
          _isLoading = false;
          _showError = !hasPermission && !_isInitialCheck;
        });
      }

      // If permission was just granted, collect initial data and start tracking
      if (wasPermissionGranted) {
        try {
          await _appUsageService.startTracking();
          widget.onPermissionGranted?.call();
        } catch (e) {
          if (kDebugMode) print('Error during initial setup after permission granted: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasAppUsagePermission = false;
          _isLoading = false;
          _showError = !_isInitialCheck;
        });
      }
    }

    // Mark initial check as complete
    if (mounted && _isInitialCheck) {
      setState(() {
        _isInitialCheck = false;
      });
    }

    if (!_hasAppUsagePermission && !_isInitialCheck) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_hasAppUsagePermission && !_isInitialCheck) {
          _checkPermission();
        }
      });
    }
  }

  Future<void> _requestPermission() async {
    if (!PlatformUtils.isMobile) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _showError = false;
        _isInitialCheck = false;
      });
    }

    try {
      await _appUsageService.requestUsageStatsPermission();
      await Future.delayed(const Duration(seconds: 3));
      await _checkPermission();
      if (_hasAppUsagePermission) {
        await _appUsageService.startTracking();
        widget.onPermissionGranted?.call();
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

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isMobile) return const SizedBox.shrink();

    return PermissionCard(
      icon: Icons.data_usage,
      title: _translationService.translate(SettingsTranslationKeys.appUsageTitle),
      description: _translationService.translate(SettingsTranslationKeys.appUsageDescription),
      isGranted: _hasAppUsagePermission,
      isLoading: _isLoading,
      showError: _showError,
      onRequestPermission: _requestPermission,
      // Dialog parameters
      learnMoreDialogDescription: _translationService.translate(SettingsTranslationKeys.appUsageDescription),
      learnMoreDialogSteps: [
        _translationService.translate(SettingsTranslationKeys.appUsageStep1),
        _translationService.translate(SettingsTranslationKeys.appUsageStep2, namedArgs: {'appName': AppInfo.name}),
        _translationService.translate(SettingsTranslationKeys.appUsageStep3, namedArgs: {'appName': AppInfo.name}),
        _translationService.translate(SettingsTranslationKeys.appUsageStep4),
      ],
    );
  }
}
