import 'package:flutter/material.dart';
import 'package:whph/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/shared_ui_constants.dart';
import 'package:whph/shared/enums/timer_mode.dart';
import 'package:whph/shared/utils/app_theme_helper.dart';

/// Helper class for timer UI formatting and colors.
class TimerUiHelpers {
  const TimerUiHelpers._();

  /// Format duration for display based on screen size
  static String getDisplayTime({
    required BuildContext context,
    required TimerMode timerMode,
    required Duration elapsedTime,
    required Duration remainingTime,
  }) {
    final timeToDisplay = timerMode == TimerMode.stopwatch ? elapsedTime : remainingTime;

    if (AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenSmall)) {
      final minutes = timeToDisplay.inMinutes;
      return '${minutes}m';
    }

    return SharedUiConstants.formatDuration(timeToDisplay);
  }

  /// Get background color based on timer state
  static Color getBackgroundColor({
    required TimerMode timerMode,
    required bool isRunning,
    required bool isAlarmPlaying,
    required bool isWorking,
    required bool isLongBreak,
  }) {
    final normalColor = AppTheme.surface2;
    final stopwatchColor = AppTheme.infoColor.withAlpha((255 * 0.8).toInt());
    final breakColor = AppTheme.successColor.withAlpha((255 * 1).toInt());
    final longBreakColor = AppTheme.infoColor.withAlpha((255 * 1).toInt());
    final workEndColor = AppTheme.successColor.withAlpha((255 * 1).toInt());
    final breakEndColor = AppTheme.errorColor.withAlpha((255 * 1).toInt());
    final longBreakEndColor = AppTheme.infoColor.withAlpha((255 * 1).toInt());

    if (timerMode == TimerMode.stopwatch) {
      return isRunning ? stopwatchColor : normalColor;
    }

    if (timerMode == TimerMode.normal) {
      if (isAlarmPlaying) return workEndColor;
      return normalColor;
    }

    // Pomodoro mode logic
    if (isAlarmPlaying) {
      if (isWorking) return workEndColor;
      return isLongBreak ? longBreakEndColor : breakEndColor;
    }
    if (!isRunning) return normalColor;
    return isWorking ? normalColor : (isLongBreak ? longBreakColor : breakColor);
  }

  /// Get progress bar color based on timer state
  static Color getProgressBarColor({
    required TimerMode timerMode,
    required bool isRunning,
    required bool isAlarmPlaying,
    required bool isWorking,
    required bool isLongBreak,
  }) {
    if (isRunning || isAlarmPlaying) {
      if (timerMode == TimerMode.stopwatch) {
        return AppTheme.infoColor.withValues(alpha: 0.3);
      }

      if (timerMode == TimerMode.normal) {
        return AppTheme.successColor.withValues(alpha: 0.3);
      }

      // Pomodoro mode logic
      if (isWorking) {
        return AppTheme.successColor.withValues(alpha: 0.3);
      } else if (isLongBreak) {
        return AppTheme.infoColor.withValues(alpha: 0.3);
      } else {
        return AppTheme.errorColor.withValues(alpha: 0.6);
      }
    }

    return Colors.transparent;
  }

  /// Get button icon based on timer state
  static IconData getButtonIcon({
    required TimerMode timerMode,
    required bool isAlarmPlaying,
    required bool isRunning,
  }) {
    if (isAlarmPlaying) {
      if (timerMode == TimerMode.stopwatch || timerMode == TimerMode.normal) {
        return TaskUiConstants.pomodoroStopIcon;
      }
      return TaskUiConstants.pomodoroNextIcon;
    }
    if (isRunning) return TaskUiConstants.pomodoroStopIcon;
    return TaskUiConstants.pomodoroPlayIcon;
  }

  /// Calculate progress value for progress bar
  static double calculateProgress({
    required TimerMode timerMode,
    required bool isRunning,
    required bool isAlarmPlaying,
    required Duration remainingTime,
    required int totalDurationInSeconds,
  }) {
    if (timerMode == TimerMode.stopwatch) {
      return 0.0;
    }
    return isRunning || isAlarmPlaying ? 1.0 - (remainingTime.inSeconds / totalDurationInSeconds) : 0.0;
  }
}
