import 'package:flutter/material.dart';
import 'package:acore/components/numeric_input/numeric_input.dart';
import 'package:acore/components/numeric_input/numeric_input_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
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
        widget: Padding(
          padding: const EdgeInsets.only(
              top: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall, left: AppTheme.sizeSmall + AppTheme.sizeMedium),
          child: NumericInput(
            initialValue: estimatedTime ?? 0,
            minValue: 0,
            incrementValue: 5,
            decrementValue: 5,
            onValueChanged: onEstimatedTimeChanged,
            iconColor: AppTheme.secondaryTextColor,
            iconSize: AppTheme.iconSizeSmall,
            valueSuffix: translationService.translate(SharedTranslationKeys.minutesShort),
            translations: _getNumericInputTranslations(),
          ),
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

  Map<NumericInputTranslationKey, String> _getNumericInputTranslations() {
    return NumericInputTranslationKey.values.asMap().map(
          (key, value) =>
              MapEntry(value, translationService.translate(SharedTranslationKeys.mapNumericInputKey(value))),
        );
  }
}
