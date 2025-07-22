import 'dart:async';
import 'package:flutter/widgets.dart';
import 'widget_service.dart';

class WidgetUpdateService {
  final WidgetService _widgetService;
  Timer? _updateTimer;
  
  WidgetUpdateService({required WidgetService widgetService}) 
      : _widgetService = widgetService;

  void startPeriodicUpdates() {
    // Update widget every 15 minutes
    _updateTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _widgetService.updateWidget();
    });
  }

  void stopPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  Future<void> triggerUpdate() async {
    await _widgetService.updateWidget();
  }

  void setupAppLifecycleListener() {
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(_widgetService));
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final WidgetService _widgetService;

  _AppLifecycleObserver(this._widgetService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // Update widget when app comes to foreground
        _widgetService.updateWidget();
        break;
      case AppLifecycleState.paused:
        // Update widget when app goes to background
        _widgetService.updateWidget();
        break;
      default:
        break;
    }
  }
}