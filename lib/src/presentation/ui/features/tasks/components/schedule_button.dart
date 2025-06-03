import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Options for scheduling a task
enum ScheduleOption {
  today,
  tomorrow,
}

/// A dropdown button component for scheduling tasks
class ScheduleButton extends StatelessWidget {
  final ITranslationService translationService;
  final Function(DateTime date) onScheduleSelected;
  final bool isDense;

  const ScheduleButton({
    super.key,
    required this.translationService,
    required this.onScheduleSelected,
    this.isDense = false,
  });

  String _getScheduleOptionLabel(ScheduleOption option) {
    switch (option) {
      case ScheduleOption.today:
        return translationService.translate(TaskTranslationKeys.taskScheduleToday);
      case ScheduleOption.tomorrow:
        return translationService.translate(TaskTranslationKeys.taskScheduleTomorrow);
    }
  }

  DateTime _getDateForOption(ScheduleOption option) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (option) {
      case ScheduleOption.today:
        return today;
      case ScheduleOption.tomorrow:
        return today.add(const Duration(days: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ScheduleOption>(
      icon: Icon(
        Icons.schedule,
        color: Colors.grey,
        size: isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium,
      ),
      tooltip: translationService.translate(TaskTranslationKeys.taskScheduleTooltip),
      onSelected: (ScheduleOption option) {
        final date = _getDateForOption(option);
        onScheduleSelected(date);
      },
      itemBuilder: (BuildContext context) => ScheduleOption.values.map((option) {
        return PopupMenuItem<ScheduleOption>(
          value: option,
          child: Row(
            children: [
              Icon(
                option == ScheduleOption.today ? Icons.today : Icons.event,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(_getScheduleOptionLabel(option)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
