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
  final DateTime? currentPlannedDate;

  const ScheduleButton({
    super.key,
    required this.translationService,
    required this.onScheduleSelected,
    this.isDense = false,
    this.currentPlannedDate,
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

    // Determine the time to use - convert to local if needed
    final timeToUse = _getTimeToUse();

    switch (option) {
      case ScheduleOption.today:
        return DateTime(today.year, today.month, today.day, timeToUse.hour, timeToUse.minute);
      case ScheduleOption.tomorrow:
        final tomorrow = today.add(const Duration(days: 1));
        return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, timeToUse.hour, timeToUse.minute);
    }
  }

  /// Gets the time to use for scheduling
  /// If currentPlannedDate exists, use its time (convert from UTC to local)
  /// Otherwise, use 9:00 AM as default
  DateTime _getTimeToUse() {
    if (currentPlannedDate != null) {
      // Convert UTC to local time to preserve the user's intended time
      final localPlannedDate = currentPlannedDate!.toLocal();
      return localPlannedDate;
    }
    // Default to 9:00 AM
    return DateTime(0, 1, 1, 9, 0);
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
