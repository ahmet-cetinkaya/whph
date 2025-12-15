import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Builds the timer section for task details.
class TaskTimerSection {
  final ITranslationService translationService;
  final void Function(Duration) onTick;
  final void Function(Duration) onTimerStop;
  final void Function(Duration) onWorkSessionComplete;

  const TaskTimerSection({
    required this.translationService,
    required this.onTick,
    required this.onTimerStop,
    required this.onWorkSessionComplete,
  });

  DetailTableRowData build() => DetailTableRowData(
        label: translationService.translate(SharedTranslationKeys.timerLabel),
        icon: TaskUiConstants.timerIcon,
        widget: Padding(
          padding: const EdgeInsets.only(top: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall, left: AppTheme.sizeSmall),
          child: AppTimer(
            isMiniLayout: true,
            onTick: onTick,
            onTimerStop: onTimerStop,
            onWorkSessionComplete: onWorkSessionComplete,
          ),
        ),
      );
}
