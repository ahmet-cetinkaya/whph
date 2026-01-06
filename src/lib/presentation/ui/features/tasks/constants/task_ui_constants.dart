import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/tasks/task.dart';

import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart' as application;
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';

class TaskUiConstants {
  // Date filter constants
  static final DateTime minFilterDate = DateTime(2000);
  static final DateTime maxFilterDate = DateTime(2050);

  // Task-specific Icons
  static const IconData priorityIcon = Icons.flag;
  static const IconData priorityOutlinedIcon = Icons.flag_outlined;
  static const IconData estimatedTimeIcon = Icons.timer;
  static const IconData estimatedTimeOutlinedIcon = Icons.timer_outlined;
  static const IconData plannedDateIcon = Icons.event;
  static const IconData plannedDateOutlinedIcon = Icons.event_outlined;
  static const IconData deadlineDateIcon = Icons.alarm;
  static const IconData deadlineDateOutlinedIcon = Icons.alarm_outlined;
  static const IconData descriptionIcon = Icons.description;
  static const IconData timerIcon = Icons.timelapse_outlined;
  static const IconData totalElapsedTimeIcon = Icons.timer;
  static const IconData parentTaskIcon = Icons.account_tree;

  // Pomodoro Icons
  static const IconData pomodoroPlayIcon = Icons.play_arrow;
  static const IconData pomodoroStopIcon = Icons.stop;
  static const IconData pomodoroNextIcon = Icons.arrow_forward;

  // Task-specific Colors
  static const Color estimatedTimeColor = Colors.blue;
  static const Color plannedDateColor = Colors.green;
  static const Color deadlineDateColor = Colors.orange;
  static const Color tagsColor = Colors.grey;
  static Color getTagColor(IThemeService themeService) => themeService.primaryColor;
  static const Color totalElapsedTimeColor = Colors.purple;

  // Time options
  static const int defaultEstimatedTime = 10;
  static const List<int> defaultEstimatedTimeOptions = [defaultEstimatedTime, 30, 50, 90, 120];

  // Timer auto-save interval
  static const int kPeriodicSaveIntervalSeconds = 10;

  // Priority Colors & Tooltips
  static Color getPriorityColor(EisenhowerPriority? priority) {
    switch (priority) {
      case EisenhowerPriority.urgentImportant:
        return AppTheme.errorColor;
      case EisenhowerPriority.notUrgentImportant:
        return AppTheme.successColor;
      case EisenhowerPriority.urgentNotImportant:
        return AppTheme.warningColor;
      case EisenhowerPriority.notUrgentNotImportant:
        return AppTheme.infoColor;
      default:
        return AppTheme.secondaryTextColor;
    }
  }

  static String getPriorityTooltip(EisenhowerPriority? priority, ITranslationService translationService) {
    return switch (priority) {
      EisenhowerPriority.urgentImportant =>
        translationService.translate(application.TaskTranslationKeys.priorityUrgentImportantTooltip),
      EisenhowerPriority.notUrgentImportant =>
        translationService.translate(application.TaskTranslationKeys.priorityNotUrgentImportantTooltip),
      EisenhowerPriority.urgentNotImportant =>
        translationService.translate(application.TaskTranslationKeys.priorityUrgentNotImportantTooltip),
      EisenhowerPriority.notUrgentNotImportant =>
        translationService.translate(application.TaskTranslationKeys.priorityNotUrgentNotImportantTooltip),
      _ => translationService.translate(application.TaskTranslationKeys.priorityNoneTooltip),
    };
  }
}
