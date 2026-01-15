import 'package:flutter/material.dart';
import 'package:acore/time/week_days.dart';
import 'package:whph/core/application/features/tasks/utils/date_helper.dart';
import 'package:whph/core/domain/features/tasks/models/recurrence_configuration.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

/// A widget for selecting specific times for selected days in weekly recurrence.
class RecurrenceWeeklyTimeSelector extends StatelessWidget {
  final List<WeekDays> selectedDays;
  final List<WeeklySchedule>? schedule;
  final ValueChanged<List<WeeklySchedule>> onScheduleChanged;
  final ITranslationService translationService;

  const RecurrenceWeeklyTimeSelector({
    super.key,
    required this.selectedDays,
    required this.schedule,
    required this.onScheduleChanged,
    required this.translationService,
  });

  String _getWeekDayLabel(WeekDays day) {
    switch (day) {
      case WeekDays.monday:
        return translationService.translate(SharedTranslationKeys.monday);
      case WeekDays.tuesday:
        return translationService.translate(SharedTranslationKeys.tuesday);
      case WeekDays.wednesday:
        return translationService.translate(SharedTranslationKeys.wednesday);
      case WeekDays.thursday:
        return translationService.translate(SharedTranslationKeys.thursday);
      case WeekDays.friday:
        return translationService.translate(SharedTranslationKeys.friday);
      case WeekDays.saturday:
        return translationService.translate(SharedTranslationKeys.saturday);
      case WeekDays.sunday:
        return translationService.translate(SharedTranslationKeys.sunday);
    }
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    return time.format(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sort days to match week order
    final sortedDays = List<WeekDays>.from(selectedDays)..sort((a, b) => a.index.compareTo(b.index));

    if (sortedDays.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: sortedDays.map((day) {
        final dayNumber = DateHelper.weekDayToNumber(day);
        final currentSchedule = schedule?.firstWhere(
              (s) => s.dayOfWeek == dayNumber,
              orElse: () => WeeklySchedule(dayOfWeek: dayNumber, hour: 9, minute: 0),
            ) ??
            WeeklySchedule(dayOfWeek: dayNumber, hour: 9, minute: 0);

        final time = TimeOfDay(hour: currentSchedule.hour, minute: currentSchedule.minute);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _getWeekDayLabel(day),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              InkWell(
                onTap: () => _selectTime(context, dayNumber, time),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.sizeMedium,
                    vertical: AppTheme.sizeSmall,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppTheme.sizeSmall),
                      Text(
                        _formatTime(context, time),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _selectTime(BuildContext context, int dayNumber, TimeOfDay initialTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final newSchedule = List<WeeklySchedule>.from(schedule ?? []);

      // Remove existing schedule for this day
      newSchedule.removeWhere((s) => s.dayOfWeek == dayNumber);

      // Add new schedule
      newSchedule.add(WeeklySchedule(
        dayOfWeek: dayNumber,
        hour: picked.hour,
        minute: picked.minute,
      ));

      onScheduleChanged(newSchedule);
    }
  }
}
