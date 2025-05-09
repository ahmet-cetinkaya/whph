import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:whph/application/features/app_usages/services/abstraction/base_app_usage_service.dart';

abstract class BaseDesktopAppUsageService extends BaseAppUsageService {
  String _activeDesktopWindowOutput = '';
  int _activeDesktopWindowTime = 0;
  Timer? _intervalTimer;

  BaseDesktopAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
    super.settingRepository,
  );

  @protected
  Future<String?> getActiveWindow();

  @override
  void startTracking() {
    _intervalTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      String? currentWindow = await getActiveWindow();
      if (currentWindow == null) return;

      if (currentWindow != _activeDesktopWindowOutput) {
        if (_activeDesktopWindowOutput.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('[BaseDesktopAppUsageService]: $_activeDesktopWindowOutput: $_activeDesktopWindowTime seconds');
          }

          List<String> activeWindowOutputSections = _activeDesktopWindowOutput.split(',');
          String appName = activeWindowOutputSections[1].isNotEmpty
              ? activeWindowOutputSections[1]
              : activeWindowOutputSections[0].isNotEmpty
                  ? activeWindowOutputSections[0]
                  : 'Unknown';

          await saveTimeRecord(appName, _activeDesktopWindowTime);
        }

        _activeDesktopWindowOutput = currentWindow;
        _activeDesktopWindowTime = 0;
      }

      _activeDesktopWindowTime += 1;
    });
  }

  @override
  void stopTracking() {
    _intervalTimer?.cancel();
    super.stopTracking();
  }
}
