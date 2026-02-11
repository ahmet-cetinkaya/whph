import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/tag_list_widget.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/utils/tag_display_utils.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class HabitCardMetadata extends StatelessWidget {
  final HabitListItem habit;
  final bool isDense;
  final ITranslationService translationService;
  final bool mini;

  const HabitCardMetadata({
    super.key,
    required this.habit,
    required this.isDense,
    required this.translationService,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = isDense ? AppTheme.size2XSmall : AppTheme.sizeSmall;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing / 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Tags section
        if (habit.tags.isNotEmpty) _buildTagsWidget(),

        // Estimated Time
        if (habit.estimatedTime != null || habit.actualTime != null) _buildEstimatedTimeWidget(),
      ],
    );
  }

  Widget _buildTagsWidget() {
    final items = TagDisplayUtils.objectsToDisplayItems(habit.tags, translationService);
    return TagListWidget(items: items, mini: mini);
  }

  Widget _buildEstimatedTimeWidget() {
    // Use actual time if available, otherwise fall back to estimated time
    final timeToDisplay = habit.actualTime ?? habit.estimatedTime;
    final isActualTime = habit.actualTime != null;

    if (timeToDisplay == null || timeToDisplay == 0) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          HabitUiConstants.estimatedTimeIcon,
          size: AppTheme.iconSizeSmall,
          color: isActualTime ? Colors.green : HabitUiConstants.estimatedTimeColor,
        ),
        Text(
          SharedUiConstants.formatMinutes(timeToDisplay),
          style: AppTheme.bodySmall.copyWith(
            color: isActualTime ? Colors.green : HabitUiConstants.estimatedTimeColor,
          ),
        ),
      ],
    );
  }
}
