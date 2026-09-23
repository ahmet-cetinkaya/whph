import 'package:flutter/material.dart';
import 'package:acore/utils/utils.dart' show PlatformUtils;
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/services/mcp_runtime_service.dart';

/// Service responsible for managing app lifecycle events
class AppLifecycleService with WidgetsBindingObserver {
  final ISystemTrayService _systemTrayService;
  final McpRuntimeService _mcpRuntimeService;
  final bool _isMobile;
  bool _isDisposed = false;
  Future<void> _lifecycleQueue = Future.value();

  AppLifecycleService(
    this._systemTrayService,
    this._mcpRuntimeService, {
    bool? isMobile,
  }) : _isMobile = isMobile ?? PlatformUtils.isMobile;

  /// Initialize the lifecycle service
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    final currentState = WidgetsBinding.instance.lifecycleState;
    if (currentState != null) didChangeAppLifecycleState(currentState);
  }

  /// Clean up the lifecycle service
  void dispose() {
    if (_isDisposed) return;
    WidgetsBinding.instance.removeObserver(this);
    _cleanupSystemTray();
    _isDisposed = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!_isMobile) return;

    _lifecycleQueue = _lifecycleQueue.then((_) => handleLifecycleState(state)).catchError((error, stackTrace) {
      Logger.error(
        'Error applying app lifecycle state',
        component: 'AppLifecycleService',
        stackTrace: stackTrace,
      );
    });
  }

  Future<void> handleLifecycleState(AppLifecycleState state) async {
    if (!_isMobile) return;

    switch (state) {
      case AppLifecycleState.detached:
        await _mcpRuntimeService.leaveForeground();
        _cleanupSystemTray();
        break;
      case AppLifecycleState.resumed:
        await _systemTrayService.cancelTrayNotification();
        await _mcpRuntimeService.enterForeground();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        await _mcpRuntimeService.leaveForeground();
        break;
    }
  }

  Future<void> waitForPendingTransitions() => _lifecycleQueue;

  /// Clean up system tray notifications
  void _cleanupSystemTray() {
    if (_isDisposed) return;
    if (!_isMobile) return;

    _systemTrayService.destroy().catchError((error) {
      Logger.error('Error cleaning up system tray: $error', component: 'AppLifecycleService');
    });
  }
}
