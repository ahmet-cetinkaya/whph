import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class HabitArchiveFilter extends StatelessWidget {
  final bool showArchived;
  final ValueChanged<bool> onToggleArchived;

  const HabitArchiveFilter({
    super.key,
    required this.showArchived,
    required this.onToggleArchived,
  });

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return FilterChip(
      label: Text(
        translationService.translate(
          showArchived ? HabitTranslationKeys.hideArchived : HabitTranslationKeys.showArchived,
        ),
      ),
      selected: showArchived,
      onSelected: onToggleArchived,
      avatar: Icon(
        showArchived ? Icons.check_box : Icons.check_box_outline_blank,
        color: showArchived ? AppTheme.primaryColor : AppTheme.textColor,
        size: AppTheme.iconSizeSmall,
      ),
      backgroundColor: AppTheme.surface2,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryColor,
    );
  }
}
