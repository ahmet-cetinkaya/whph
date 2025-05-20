import 'package:flutter/material.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TaskUiConstants {
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

  // Pomodoro Icons
  static const IconData pomodoroPlayIcon = Icons.play_arrow;
  static const IconData pomodoroStopIcon = Icons.stop;
  static const IconData pomodoroNextIcon = Icons.arrow_forward;

  // Task-specific Colors
  static const Color estimatedTimeColor = Colors.blue;
  static const Color plannedDateColor = Colors.green;
  static const Color deadlineDateColor = Colors.orange;
  static const Color tagsColor = Colors.grey;
  static const Color tagColor = AppTheme.primaryColor;

  // Time options
  static const List<int> defaultEstimatedTimeOptions = [10, 30, 50, 90, 120];

  // Priority Colors & Tooltips
  static Color getPriorityColor(EisenhowerPriority? priority) {
    switch (priority) {
      case EisenhowerPriority.urgentImportant:
        return AppTheme.errorColor;
      case EisenhowerPriority.notUrgentImportant:
        return AppTheme.successColor;
      case EisenhowerPriority.urgentNotImportant:
        return AppTheme.infoColor;
      case EisenhowerPriority.notUrgentNotImportant:
        return AppTheme.disabledColor;
      default:
        return Colors.white;
    }
  }

  static String getPriorityTooltip(EisenhowerPriority? priority, ITranslationService translationService) {
    return switch (priority) {
      EisenhowerPriority.urgentImportant =>
        translationService.translate(TaskTranslationKeys.priorityUrgentImportantTooltip),
      EisenhowerPriority.notUrgentImportant =>
        translationService.translate(TaskTranslationKeys.priorityNotUrgentImportantTooltip),
      EisenhowerPriority.urgentNotImportant =>
        translationService.translate(TaskTranslationKeys.priorityUrgentNotImportantTooltip),
      EisenhowerPriority.notUrgentNotImportant =>
        translationService.translate(TaskTranslationKeys.priorityNotUrgentNotImportantTooltip),
      _ => translationService.translate(TaskTranslationKeys.priorityNoneTooltip),
    };
  }
}
