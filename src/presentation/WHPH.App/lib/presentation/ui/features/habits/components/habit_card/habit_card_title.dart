import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class HabitCardTitle extends StatelessWidget {
  final HabitListItem habit;
  final bool isDense;
  final ITranslationService translationService;
  final TextStyle? style;

  const HabitCardTitle({
    super.key,
    required this.habit,
    required this.isDense,
    required this.translationService,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      habit.name.isEmpty ? translationService.translate(SharedTranslationKeys.untitled) : habit.name,
      style: style ??
          (isDense ? AppTheme.bodySmall : AppTheme.bodyMedium).copyWith(
            fontWeight: FontWeight.bold,
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
