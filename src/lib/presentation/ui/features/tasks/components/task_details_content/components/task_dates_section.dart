import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_date_picker_field.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Builds the date sections (planned and deadline) for task details.
class TaskDatesSection {
  final ITranslationService translationService;

  const TaskDatesSection({required this.translationService});

  /// Builds the planned date section.
  DetailTableRowData buildPlannedDate({
    required String taskId,
    required TextEditingController controller,
    required FocusNode focusNode,
    required BuildContext context,
    required ReminderTime reminderValue,
    required int? reminderCustomOffset,
    required void Function(DateTime?) onDateChanged,
    required void Function(ReminderTime, int?) onReminderChanged,
  }) =>
      DetailTableRowData(
        label: translationService.translate(TaskTranslationKeys.plannedDateLabel),
        icon: TaskUiConstants.plannedDateIcon,
        widget: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeSmall),
          child: TaskDatePickerField(
            key: ValueKey('planned_date_$taskId'),
            controller: controller,
            hintText: '',
            minDateTime: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
            onDateChanged: onDateChanged,
            onReminderChanged: onReminderChanged,
            reminderValue: reminderValue,
            reminderCustomOffset: reminderCustomOffset,
            translationService: translationService,
            reminderLabelPrefix: 'tasks.reminder.planned',
            dateIcon: TaskUiConstants.plannedDateIcon,
            focusNode: focusNode,
            context: context,
          ),
        ),
      );

  /// Builds the deadline date section.
  DetailTableRowData buildDeadlineDate({
    required String taskId,
    required TextEditingController controller,
    required FocusNode focusNode,
    required BuildContext context,
    required DateTime minDateTime,
    required DateTime? plannedDateTime,
    required ReminderTime reminderValue,
    required int? reminderCustomOffset,
    required void Function(DateTime?) onDateChanged,
    required void Function(ReminderTime, int?) onReminderChanged,
  }) =>
      DetailTableRowData(
        label: translationService.translate(TaskTranslationKeys.deadlineDateLabel),
        icon: TaskUiConstants.deadlineDateIcon,
        widget: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeSmall),
          child: TaskDatePickerField(
            key: ValueKey('deadline_date_$taskId'),
            controller: controller,
            hintText: '',
            minDateTime: minDateTime,
            plannedDateTime: plannedDateTime,
            onDateChanged: onDateChanged,
            onReminderChanged: onReminderChanged,
            reminderValue: reminderValue,
            reminderCustomOffset: reminderCustomOffset,
            translationService: translationService,
            reminderLabelPrefix: 'tasks.reminder.deadline',
            dateIcon: TaskUiConstants.deadlineDateIcon,
            focusNode: focusNode,
            context: context,
          ),
        ),
      );
}
