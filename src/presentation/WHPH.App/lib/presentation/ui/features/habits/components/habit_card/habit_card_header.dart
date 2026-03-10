import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_card_metadata.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_card/habit_card_title.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class HabitCardHeader extends StatelessWidget {
  final HabitListItem habit;
  final bool isDense;
  final HabitListStyle style;
  final ITranslationService translationService;

  const HabitCardHeader({
    super.key,
    required this.habit,
    required this.isDense,
    required this.style,
    required this.translationService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        HabitCardTitle(
          habit: habit,
          isDense: isDense,
          translationService: translationService,
        ),
        if (style != HabitListStyle.grid) ...[
          if (isDense) const SizedBox(height: 1) else const SizedBox(height: 2),
          HabitCardMetadata(
            habit: habit,
            isDense: isDense,
            translationService: translationService,
            mini: true,
          ),
        ],
      ],
    );
  }
}
