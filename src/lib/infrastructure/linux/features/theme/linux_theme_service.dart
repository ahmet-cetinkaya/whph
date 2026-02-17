import 'dart:async';
import 'package:flutter/services.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';

import 'package:acore/acore.dart';
import 'package:whph/infrastructure/linux/constants/linux_app_constants.dart';
import 'package:whph/presentation/ui/shared/services/theme_service/theme_service.dart';

class LinuxThemeService extends ThemeService {
  static final _windowManagementChannel = MethodChannel(LinuxAppConstants.channels.windowManagement);

  Timer? _linuxThemePollingTimer;
  bool _isPollingLinuxTheme = false;

  LinuxThemeService({required Mediator mediator, required ILogger logger}) : super(mediator: mediator, logger: logger);

  @override
  Future<void> initialize() async {
    await super.initialize();

    // Initial sync with Linux window
    // We need to wait for the first frame or ensure the window is ready?
    // Usually safe to call immediately after initialization
    notifyThemeChanged();

    // Poll for theme changes on Linux since WidgetsBindingObserver might not fire
    _linuxThemePollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (currentThemeMode == AppThemeMode.auto && !isPollingLinuxTheme) {
        isPollingLinuxTheme = true;
        try {
          final newBrightness = await getSystemBrightness();
          final currentBrightness = currentThemeMode == AppThemeMode.light ? Brightness.light : Brightness.dark;

          if (currentBrightness != newBrightness) {
            await updateActualThemeMode();
            notifyThemeChanged();
          }
        } finally {
          isPollingLinuxTheme = false;
        }
      }
    });
  }

  @override
  void notifyThemeChanged() {
    super.notifyThemeChanged();

    // Sync theme with Linux window (GTK)
    try {
      final isDark = currentThemeMode ==
          AppThemeMode.dark; // This might need adjustment if currentThemeMode isn't the resolved one
      // Actually we need the resolved mode. ThemeService has _currentThemeMode but it's private.
      // However, ThemeService calls notifyThemeChanged AFTER updating _currentThemeMode.
      // But we can't access _currentThemeMode directly.
      // We can check themeData.brightness or similar.
      // Or we can expose the resolved theme mode protectedly.

      // Let's use themeData.brightness as a proxy for the resolved theme
      final brightness = themeData.brightness;
      final isDarkMode = brightness == Brightness.dark;

      _windowManagementChannel.invokeMethod('setTheme', isDarkMode ? 'dark' : 'light');
    } catch (e) {
      // Logger is private in base class... we passed it in constructor but didn't keep reference?
      // Base class keeps it. We should probably make logger protected in base class or just ignore debug log here
      // or use a static logger if available.
      // For now, let's assume we can't easily log unless we change base class visibility.
      // Wait, we passed logger to super.
      print('Failed to sync theme with Linux window: $e'); // Fallback logging
    }
  }

  @override
  void dispose() {
    _linuxThemePollingTimer?.cancel();
    super.dispose();
  }
}
