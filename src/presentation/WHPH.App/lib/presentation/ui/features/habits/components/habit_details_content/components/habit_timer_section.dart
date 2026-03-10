import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';

/// Builds the timer section for habit details.
class HabitTimerSection {
  static DetailTableRowData build({
    required BuildContext context,
    required ITranslationService translationService,
    required Function(Duration) onTimerStop,
  }) {
    return DetailTableRowData(
      label: translationService.translate(SharedTranslationKeys.timerLabel),
      icon: Icons.timer,
      widget: Container(
        constraints: BoxConstraints(
          maxHeight: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium) ? 200 : 300,
        ),
        child: AppTimer(
          onTimerStop: onTimerStop,
          isMiniLayout: true,
        ),
      ),
    );
  }
}
