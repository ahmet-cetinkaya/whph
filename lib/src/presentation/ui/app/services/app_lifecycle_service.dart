import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';

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

    if (!_isMobilePlatform) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _cleanupSystemTray();
        break;
      case AppLifecycleState.resumed:
        _initializeSystemTray();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Clean up system tray notifications
  void _cleanupSystemTray() {
    if (!_isMobilePlatform) return;

    _systemTrayService.destroy().catchError((error) {
      if (kDebugMode) {
        debugPrint('Error cleaning up system tray: $error');
      }
    });
  }

  /// Initialize system tray
  void _initializeSystemTray() {
    if (!_isMobilePlatform) return;

    _systemTrayService.init().catchError((error) {
      if (kDebugMode) {
        debugPrint('Error initializing system tray: $error');
      }
    });
  }

  /// Check if current platform is mobile
  bool get _isMobilePlatform => Platform.isAndroid || Platform.isIOS;
}
