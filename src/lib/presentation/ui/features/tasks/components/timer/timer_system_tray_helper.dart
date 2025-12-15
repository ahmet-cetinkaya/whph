import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Helper class for system tray operations related to the timer.
/// Handles icon updates, menu items, and notification management.
class TimerSystemTrayHelper {
  final ISystemTrayService _systemTrayService;
  final ITranslationService _translationService;

  static const String _stopTimerMenuKey = 'stop_timer';
  static const String _pomodoroTimerSeparatorKey = 'pomodoro_timer_separator';

  bool _isTimerMenuAdded = false;

  TimerSystemTrayHelper({
    required ISystemTrayService systemTrayService,
    required ITranslationService translationService,
  })  : _systemTrayService = systemTrayService,
        _translationService = translationService;

  bool get isTimerMenuAdded => _isTimerMenuAdded;

  /// Update system tray with timer status and time display
  void updateTimerNotification({
    required bool isWorking,
    required bool isLongBreak,
    required String timeDisplay,
  }) {
    final status = isWorking
        ? _translationService.translate(TaskTranslationKeys.pomodoroWorkLabel)
        : (isLongBreak
            ? _translationService.translate(TaskTranslationKeys.pomodoroLongBreakLabel)
            : _translationService.translate(TaskTranslationKeys.pomodoroBreakLabel));

    _systemTrayService.setTitle('$status - $timeDisplay');
    _systemTrayService.setBody(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayTimerRunning));
  }

  /// Set system tray notification for timer completion
  void setCompletionNotification({
    required bool isWorking,
    required bool isLongBreak,
  }) {
    final completionMessage = isWorking
        ? _translationService.translate(TaskTranslationKeys.pomodoroWorkSessionCompleted)
        : _translationService.translate(isLongBreak
            ? TaskTranslationKeys.pomodoroLongBreakSessionCompleted
            : TaskTranslationKeys.pomodoroBreakSessionCompleted);

    _systemTrayService.setTitle(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayCompleteTitle));
    _systemTrayService.setBody(completionMessage);
  }

  /// Reset system tray to default state
  void resetToDefault() {
    _systemTrayService.setTitle(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayAppRunning));
    _systemTrayService.setBody(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayTapToOpen));
  }

  /// Set system tray icon based on working state
  void setIcon({required bool isWorking}) {
    _systemTrayService.setIcon(isWorking ? TrayIconType.play : TrayIconType.pause);
  }

  /// Reset system tray icon to default
  void resetIcon() {
    _systemTrayService.setIcon(TrayIconType.default_);
  }

  /// Add timer menu items to system tray
  void addMenuItems({required void Function() onStopTimer}) {
    if (_isTimerMenuAdded) return;

    final menuItems = [
      TrayMenuItem.separator(_pomodoroTimerSeparatorKey),
      TrayMenuItem(
        key: _stopTimerMenuKey,
        label: _translationService.translate(TaskTranslationKeys.pomodoroStopTimer),
        onClicked: onStopTimer,
      ),
    ];

    for (final item in menuItems) {
      _systemTrayService.insertMenuItem(item, index: 0);
    }
    _isTimerMenuAdded = true;
  }

  /// Remove timer menu items from system tray
  void removeMenuItems() {
    _systemTrayService.removeMenuItem(_stopTimerMenuKey);
    _systemTrayService.removeMenuItem(_pomodoroTimerSeparatorKey);
    _isTimerMenuAdded = false;
  }
}
