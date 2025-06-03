import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/base_app_usage_service.dart';

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
  Future<void> startTracking() async {
    _intervalTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      String? currentWindow = await getActiveWindow(); // <windowTitle>,<windowProcess>,<duration>

      if (currentWindow == null) return;

      if (currentWindow != _activeDesktopWindowOutput) {
        if (_activeDesktopWindowOutput.isNotEmpty) {
          List<String> activeWindowOutputSections = _activeDesktopWindowOutput.split(',');
          String windowTitle = activeWindowOutputSections[0];
          String windowProcess = activeWindowOutputSections[1];

          const unknownProcessName = 'unknown';
          String appName = windowProcess.isNotEmpty && windowProcess != unknownProcessName
              ? windowProcess
              : _extractAppNameFromTitle(windowTitle);

          await saveTimeRecord(appName, _activeDesktopWindowTime);
          if (kDebugMode) debugPrint('Saving time record for $appName: $_activeDesktopWindowTime seconds');
        }

        _activeDesktopWindowOutput = currentWindow;
        _activeDesktopWindowTime = 0;
      }

      _activeDesktopWindowTime += 1;
    });
  }

  String _extractAppNameFromTitle(String windowTitle) {
    final commonSeparators = [' - ', ' | ', ' :: ', ' • ', ' › ', ' » ', ' — ', ' – '];
    for (var separator in commonSeparators) {
      if (windowTitle.contains(separator)) {
        var parts = windowTitle.split(separator);
        var lastPart = parts.last.trim();
        return lastPart;
      }
    }

    return windowTitle;
  }

  @override
  Future<void> stopTracking() async {
    _intervalTimer?.cancel();
    super.stopTracking();
  }
}
