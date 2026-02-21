import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show NumericInput;
import 'package:acore/components/numeric_input/numeric_input_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/components/time_display.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Builds estimated and elapsed time sections for habit details.
class HabitTimeSection {
  static DetailTableRowData buildEstimatedTime({
    required int? estimatedTime,
    required ITranslationService translationService,
    required Function(int) onValueChanged,
    required Map<NumericInputTranslationKey, String> translations,
  }) {
    return DetailTableRowData(
      label: translationService.translate(SharedTranslationKeys.timeDisplayEstimated),
      icon: HabitUiConstants.estimatedTimeIcon,
      widget: NumericInput(
        initialValue: estimatedTime ?? HabitUiConstants.defaultEstimatedTimeOptions.first,
        minValue: 0,
        incrementValue: 10,
        decrementValue: 10,
        onValueChanged: onValueChanged,
        iconColor: AppTheme.secondaryTextColor,
        iconSize: AppTheme.iconSizeSmall,
        valueSuffix: translationService.translate(SharedTranslationKeys.minutesShort),
        translations: translations,
      ),
    );
  }

  static DetailTableRowData buildElapsedTime({
    required int totalDuration,
    required ITranslationService translationService,
    required VoidCallback onTap,
  }) {
    return DetailTableRowData(
      label: translationService.translate(SharedTranslationKeys.timeDisplayElapsed),
      icon: HabitUiConstants.estimatedTimeIcon,
      widget: TimeDisplay(
        totalSeconds: totalDuration,
        onTap: onTap,
      ),
    );
  }

  static Map<NumericInputTranslationKey, String> getNumericInputTranslations(ITranslationService translationService) {
    return NumericInputTranslationKey.values.asMap().map(
          (key, value) =>
              MapEntry(value, translationService.translate(SharedTranslationKeys.mapNumericInputKey(value))),
        );
  }
}
