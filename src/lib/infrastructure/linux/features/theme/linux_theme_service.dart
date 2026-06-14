import 'dart:async';
import 'package:flutter/services.dart';

import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';

import 'package:whph/infrastructure/linux/constants/linux_app_constants.dart';
import 'package:whph/presentation/ui/shared/services/theme_service/theme_service.dart';

class LinuxThemeService extends ThemeService {
  static final _windowManagementChannel = MethodChannel(LinuxAppConstants.channels.windowManagement);

  Timer? _linuxThemePollingTimer;

  LinuxThemeService({required super.mediator, required super.logger});

  @override
  Future<void> initialize() async {
    await super.initialize();

    // Initial sync with Linux window is safe immediately after initialization
    notifyThemeChanged();

    // Poll for theme changes on Linux since WidgetsBindingObserver might not fire
    _linuxThemePollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (isPollingLinuxTheme) return;
      isPollingLinuxTheme = true;
      try {
        bool changed = false;

        if (currentThemeMode == AppThemeMode.auto) {
          final newBrightness = await getSystemBrightness();
          final currentBrightness = currentThemeMode == AppThemeMode.light ? Brightness.light : Brightness.dark;
          if (currentBrightness != newBrightness) {
            await updateActualThemeMode();
            changed = true;
          }
        }

        if (storedUiDensity == domain.UiDensity.system) {
          final oldMultiplier = effectiveDensityMultiplier;
          resolveEffectiveDensityMultiplier();
          if (oldMultiplier != effectiveDensityMultiplier) changed = true;
        }

        if (changed) notifyThemeChanged();
      } finally {
        isPollingLinuxTheme = false;
      }
    });
  }

  @override
  void notifyThemeChanged() {
    super.notifyThemeChanged();

    // Sync theme with Linux window (GTK)
    try {
      // Use themeData.brightness as proxy since _currentThemeMode is private in ThemeService
      final brightness = themeData.brightness;
      final isDarkMode = brightness == Brightness.dark;

      _windowManagementChannel.invokeMethod('setTheme', isDarkMode ? 'dark' : 'light');
    } catch (e) {
      logger.error('Failed to sync theme with Linux window', e);
    }
  }

  @override
  void dispose() {
    _linuxThemePollingTimer?.cancel();
    super.dispose();
  }
}
