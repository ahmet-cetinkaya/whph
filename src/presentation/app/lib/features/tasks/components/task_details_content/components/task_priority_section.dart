import 'package:flutter/material.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:whph/features/tasks/components/priority_select_field.dart';
import 'package:whph/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/shared/components/detail_table.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';

/// Builds the priority section for task details.
class TaskPrioritySection {
  final ITranslationService translationService;
  final EisenhowerPriority? priority;
  final void Function(EisenhowerPriority?) onPriorityChanged;

  const TaskPrioritySection({
    required this.translationService,
    required this.priority,
    required this.onPriorityChanged,
  });

  DetailTableRowData build() => DetailTableRowData(
        label: translationService.translate(TaskTranslationKeys.priorityLabel),
        icon: TaskUiConstants.priorityIcon,
        widget: Padding(
          padding: const EdgeInsets.only(top: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall, left: AppTheme.sizeSmall),
          child: PrioritySelectField(
            value: priority,
            onChanged: onPriorityChanged,
          ),
        ),
      );
}
