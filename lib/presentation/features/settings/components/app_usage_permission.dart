import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/settings/components/permission_card.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

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

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (!Platform.isAndroid) {
      setState(() {
        _hasAppUsagePermission = true;
        _isLoading = false;
        _showError = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final hasPermission = await _appUsageService.checkUsageStatsPermission();

      setState(() {
        _hasAppUsagePermission = hasPermission;
        _isLoading = false;
        _showError = !hasPermission;
      });
    } catch (e) {
      debugPrint('Error checking app usage permission: $e');
      setState(() {
        _hasAppUsagePermission = false;
        _isLoading = false;
        _showError = true;
      });
    }

    if (!_hasAppUsagePermission) {
      Future.delayed(const Duration(seconds: 2), () {
        _checkPermission();
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
      await _appUsageService.requestUsageStatsPermission();
      await Future.delayed(const Duration(seconds: 3));
      await _checkPermission();
      if (_hasAppUsagePermission) {
        await _appUsageService.startTracking();
        widget.onPermissionGranted?.call();
      }
    } catch (e) {
      debugPrint('Error requesting app usage permission: $e');
      setState(() {
        _isLoading = false;
        _showError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();

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
        _translationService.translate(SettingsTranslationKeys.appUsageStep2),
        _translationService.translate(SettingsTranslationKeys.appUsageStep3, namedArgs: {'appName': AppInfo.shortName}),
      ],
      notGrantedText: _showError ? _translationService.translate(SettingsTranslationKeys.appUsageNotGranted) : null,
    );
  }
}
