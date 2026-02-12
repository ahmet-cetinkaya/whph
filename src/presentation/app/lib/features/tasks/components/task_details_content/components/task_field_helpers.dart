import 'package:flutter/material.dart';
import 'package:whph/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/features/tasks/components/task_details_content/controllers/task_details_controller.dart';
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';

/// Helper class for field labels and icons.
class TaskFieldHelpers {
  final ITranslationService translationService;

  const TaskFieldHelpers({required this.translationService});

  /// Gets the label for a field key.
  String getFieldLabel(String fieldKey) {
    switch (fieldKey) {
      case TaskDetailsController.keyTags:
        return translationService.translate(TaskTranslationKeys.tagsLabel);
      case TaskDetailsController.keyPriority:
        return translationService.translate(TaskTranslationKeys.priorityLabel);
      case TaskDetailsController.keyEstimatedTime:
        return translationService.translate(SharedTranslationKeys.timeDisplayEstimated);
      case TaskDetailsController.keyElapsedTime:
        return translationService.translate(SharedTranslationKeys.timeDisplayElapsed);
      case TaskDetailsController.keyTimer:
        return translationService.translate(SharedTranslationKeys.timerLabel);
      case TaskDetailsController.keyPlannedDate:
        return translationService.translate(TaskTranslationKeys.plannedDateLabel);
      case TaskDetailsController.keyDeadlineDate:
        return translationService.translate(TaskTranslationKeys.deadlineDateLabel);
      case TaskDetailsController.keyDescription:
        return translationService.translate(TaskTranslationKeys.descriptionLabel);
      case TaskDetailsController.keyPlannedDateReminder:
        return translationService.translate(TaskTranslationKeys.reminderDateLabel);
      case TaskDetailsController.keyDeadlineDateReminder:
        return translationService.translate(TaskTranslationKeys.reminderDeadlineLabel);
      case TaskDetailsController.keyRecurrence:
        return translationService.translate(TaskTranslationKeys.recurrenceLabel);
      case TaskDetailsController.keyParentTask:
        return translationService.translate(TaskTranslationKeys.parentTaskLabel);
      default:
        return '';
    }
  }

  /// Gets the icon for a field key.
  IconData getFieldIcon(String fieldKey) {
    switch (fieldKey) {
      case TaskDetailsController.keyTags:
        return TagUiConstants.tagIcon;
      case TaskDetailsController.keyPriority:
        return TaskUiConstants.priorityIcon;
      case TaskDetailsController.keyEstimatedTime:
        return TaskUiConstants.estimatedTimeIcon;
      case TaskDetailsController.keyElapsedTime:
        return TaskUiConstants.timerIcon;
      case TaskDetailsController.keyTimer:
        return TaskUiConstants.timerIcon;
      case TaskDetailsController.keyPlannedDate:
        return TaskUiConstants.plannedDateIcon;
      case TaskDetailsController.keyDeadlineDate:
        return TaskUiConstants.deadlineDateIcon;
      case TaskDetailsController.keyDescription:
        return TaskUiConstants.descriptionIcon;
      case TaskDetailsController.keyPlannedDateReminder:
        return Icons.notifications;
      case TaskDetailsController.keyDeadlineDateReminder:
        return Icons.notifications;
      case TaskDetailsController.keyRecurrence:
        return Icons.repeat;
      case TaskDetailsController.keyParentTask:
        return TaskUiConstants.parentTaskIcon;
      default:
        return Icons.add;
    }
  }
}
