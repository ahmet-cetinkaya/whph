import 'package:acore/acore.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Helper class for system tray operations related to the timer.
/// Handles icon updates, menu items, and notification management.
class TimerSystemTrayHelper {
  final ISystemTrayService _systemTrayService;
  final ITranslationService _translationService;

  static final String _stopTimerMenuKey = AndroidAppConstants.intentActions.timerStop;
  static const String _pomodoroTimerSeparatorKey = 'pomodoro_timer_separator';

  bool _isTimerMenuAdded = false;

  TimerSystemTrayHelper({
    required ISystemTrayService systemTrayService,
    required ITranslationService translationService,
  })  : _systemTrayService = systemTrayService,
        _translationService = translationService;

  bool get isTimerMenuAdded => _isTimerMenuAdded;

  /// Update system tray with timer status and time display
  Future<void> updateTimerNotification({
    required bool isWorking,
    required bool isLongBreak,
    required String timeDisplay,
  }) async {
    final status = isWorking
        ? _translationService.translate(TaskTranslationKeys.pomodoroWorkLabel)
        : (isLongBreak
            ? _translationService.translate(TaskTranslationKeys.pomodoroLongBreakLabel)
            : _translationService.translate(TaskTranslationKeys.pomodoroBreakLabel));

    try {
      await _systemTrayService.setTitle('$status - $timeDisplay');
      await _systemTrayService
          .setBody(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayTimerRunning));
    } catch (e) {
      Logger.error('Failed to update timer notification', component: 'TimerSystemTrayHelper', error: e);
    }
  }

  /// Set system tray notification for timer completion
  Future<void> setCompletionNotification({
    required bool isWorking,
    required bool isLongBreak,
  }) async {
    final completionMessage = isWorking
        ? _translationService.translate(TaskTranslationKeys.pomodoroWorkSessionCompleted)
        : _translationService.translate(isLongBreak
            ? TaskTranslationKeys.pomodoroLongBreakSessionCompleted
            : TaskTranslationKeys.pomodoroBreakSessionCompleted);

    try {
      await _systemTrayService
          .setTitle(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayCompleteTitle));
      await _systemTrayService.setBody(completionMessage);
    } catch (e) {
      Logger.error('Failed to set completion notification', component: 'TimerSystemTrayHelper', error: e);
    }
  }

  /// Reset system tray to default state
  Future<void> resetToDefault() async {
    if (PlatformUtils.isMobile) {
      try {
        await _systemTrayService.reset();
      } catch (e) {
        Logger.error('Failed to reset system tray', component: 'TimerSystemTrayHelper', error: e);
      }
      return;
    }

    try {
      await _systemTrayService
          .setTitle(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayAppRunning));
      await _systemTrayService.setBody(_translationService.translate(TaskTranslationKeys.pomodoroSystemTrayTapToOpen));
    } catch (e) {
      Logger.error('Failed to reset system tray to default', component: 'TimerSystemTrayHelper', error: e);
    }
  }

  /// Set system tray icon based on working state
  Future<void> setIcon({required bool isWorking}) async {
    try {
      await _systemTrayService.setIcon(isWorking ? TrayIconType.play : TrayIconType.pause);
    } catch (e) {
      Logger.error('Failed to set system tray icon', component: 'TimerSystemTrayHelper', error: e);
    }
  }

  /// Reset system tray icon to default
  Future<void> resetIcon() async {
    try {
      await _systemTrayService.setIcon(TrayIconType.default_);
    } catch (e) {
      Logger.error('Failed to reset system tray icon', component: 'TimerSystemTrayHelper', error: e);
    }
  }

  /// Add timer menu items to system tray
  Future<void> addMenuItems({required void Function() onStopTimer}) async {
    if (_isTimerMenuAdded) return;

    final menuItems = [
      TrayMenuItem.separator(_pomodoroTimerSeparatorKey),
      TrayMenuItem(
        key: _stopTimerMenuKey,
        label: _translationService.translate(TaskTranslationKeys.pomodoroStopTimer),
        onClicked: onStopTimer,
      ),
    ];

    try {
      for (final item in menuItems) {
        await _systemTrayService.insertMenuItem(item, index: 0);
      }
      _isTimerMenuAdded = true;
    } catch (e) {
      Logger.error('Failed to add timer menu items', component: 'TimerSystemTrayHelper', error: e);
    }
  }

  /// Remove timer menu items from system tray
  Future<void> removeMenuItems() async {
    try {
      await _systemTrayService.removeMenuItem(_stopTimerMenuKey);
      await _systemTrayService.removeMenuItem(_pomodoroTimerSeparatorKey);
    } catch (e) {
      Logger.error('Failed to remove timer menu items', component: 'TimerSystemTrayHelper', error: e);
    }
    _isTimerMenuAdded = false;
  }
}
