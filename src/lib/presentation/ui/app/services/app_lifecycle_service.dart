import 'package:flutter/material.dart';
import 'package:acore/utils/utils.dart' show PlatformUtils;
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Service responsible for managing app lifecycle events
class AppLifecycleService with WidgetsBindingObserver {
  final ISystemTrayService _systemTrayService;

  AppLifecycleService(this._systemTrayService);

  /// Initialize the lifecycle service
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Clean up the lifecycle service
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupSystemTray();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!PlatformUtils.isMobile) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _cleanupSystemTray();
        break;
      case AppLifecycleState.resumed:
        _systemTrayService.cancelNotification().catchError((error) {
          Logger.error('Error canceling system tray notification: $error', component: 'AppLifecycleService');
        });
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Clean up system tray notifications
  void _cleanupSystemTray() {
    if (!PlatformUtils.isMobile) return;

    _systemTrayService.destroy().catchError((error) {
      Logger.error('Error cleaning up system tray: $error', component: 'AppLifecycleService');
    });
  }
}
