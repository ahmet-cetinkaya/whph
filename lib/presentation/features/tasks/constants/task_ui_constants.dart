import 'package:flutter/material.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

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
  static const IconData tagsIcon = Icons.label;
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

  // Time options
  static const List<int> defaultEstimatedTimeOptions = [10, 30, 50, 90, 120];

  // Task property labels
  static const String priorityLabel = 'Priority';
  static const String tagsLabel = 'Tags';
  static const String estimatedTimeLabel = 'Estimated Time';
  static const String elapsedTimeLabel = 'Elapsed Time';
  static const String plannedDateLabel = 'Planned Date';
  static const String deadlineDateLabel = 'Deadline Date';
  static const String descriptionLabel = 'Description';

  // Pomodoro Labels
  static const String pomodoroWorkLabel = 'Work Time';
  static const String pomodoroBreakLabel = 'Break Time';
  static const String pomodoroSettingsLabel = 'Settings';
  static const String pomodoroTimerSettingsLabel = 'Default timer settings (in minutes):';
  static const String pomodoroStopTimerLabel = 'Stop Timer';

  // Pomodoro Notifications
  static const String pomodoroNotificationTitle = 'Pomodoro Timer';
  static const String pomodoroWorkSessionCompleted = 'Work session completed!';
  static const String pomodoroBreakSessionCompleted = 'Break session completed!';

  // Task-specific Messages
  static const String noTasksFoundMessage = 'No tasks found';
  static const String taskCreatedMessage = 'Task created successfully';
  static const String taskUpdatedMessage = 'Task updated successfully';
  static const String taskDeletedMessage = 'Task deleted successfully';

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

  static String getPriorityTooltip(EisenhowerPriority? priority) {
    switch (priority) {
      case EisenhowerPriority.urgentImportant:
        return 'Urgent & Important';
      case EisenhowerPriority.notUrgentImportant:
        return 'Not Urgent & Important';
      case EisenhowerPriority.urgentNotImportant:
        return 'Urgent & Not Important';
      case EisenhowerPriority.notUrgentNotImportant:
        return 'Not Urgent & Not Important';
      default:
        return 'No Priority';
    }
  }
}
