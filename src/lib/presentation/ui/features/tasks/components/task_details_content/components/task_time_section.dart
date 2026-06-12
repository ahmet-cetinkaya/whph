import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/components/estimated_time_input.dart';
import 'package:whph/presentation/ui/shared/components/time_display.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Builds the time sections (elapsed and estimated) for task details.
class TaskTimeSection {
  final ITranslationService translationService;

  const TaskTimeSection({required this.translationService});

  /// Builds the estimated time section.
  DetailTableRowData buildEstimatedTime({
    required int? estimatedTime,
    required void Function(int) onEstimatedTimeChanged,
  }) =>
      DetailTableRowData(
        label: translationService.translate(SharedTranslationKeys.timeDisplayEstimated),
        icon: TaskUiConstants.estimatedTimeIcon,
        widget: EstimatedTimeInput(
          totalMinutes: estimatedTime ?? 0,
          onValueChanged: onEstimatedTimeChanged,
        ),
      );

  /// Builds the elapsed time section.
  DetailTableRowData buildElapsedTime({
    required int totalDuration,
    required VoidCallback onTap,
  }) =>
      DetailTableRowData(
        label: translationService.translate(SharedTranslationKeys.timeDisplayElapsed),
        icon: TaskUiConstants.timerIcon,
        widget: Padding(
          padding: const EdgeInsets.only(top: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall, left: AppTheme.sizeSmall),
          child: TimeDisplay(
            totalSeconds: totalDuration,
            onTap: onTap,
          ),
        ),
      );
}
