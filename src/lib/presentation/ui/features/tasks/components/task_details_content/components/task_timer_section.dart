import 'package:flutter/material.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Builds the timer section for task details.
class TaskTimerSection {
  final String taskId;
  final ITranslationService translationService;

  const TaskTimerSection({
    required this.taskId,
    required this.translationService,
  });

  DetailTableRowData build() => DetailTableRowData(
        label: translationService.translate(SharedTranslationKeys.timerLabel),
        icon: TaskUiConstants.timerIcon,
        widget: Padding(
          padding: const EdgeInsets.only(
              top: AppTheme.sizeSmall,
              bottom: AppTheme.sizeSmall,
              left: AppTheme.sizeSmall),
          child: AppTimer(
            sessionId: 'task:$taskId',
            sessionOwner: TimerSessionOwner.task(taskId),
            isMiniLayout: true,
          ),
        ),
      );
}
