import 'package:flutter/material.dart';
import 'package:acore/time/week_days.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';

/// A widget for selecting weekdays in recurrence configuration
class RecurrenceWeekdaySelector extends StatelessWidget {
  final List<WeekDays>? selectedDays;
  final ValueChanged<List<WeekDays>> onDaysChanged;
  final ITranslationService translationService;

  const RecurrenceWeekdaySelector({
    super.key,
    required this.selectedDays,
    required this.onDaysChanged,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppTheme.sizeSmall,
      runSpacing: AppTheme.sizeSmall,
      alignment: WrapAlignment.start,
      children: WeekDays.values.map((day) {
        final isSelected = selectedDays?.contains(day) ?? false;
        return InkWell(
          onTap: () {
            // Create a new list instead of mutating the existing one
            List<WeekDays> currentDays;
            if (isSelected) {
              if (selectedDays != null || selectedDays!.length > 1) {
                currentDays = selectedDays!.where((d) => d != day).toList();
              } else {
                currentDays = [];
              }
            } else {
              currentDays = [...(selectedDays ?? []), day];
            }
            onDaysChanged(currentDays);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : AppTheme.borderColor,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              _getWeekDayLabel(day).substring(0, 1),
              style: TextStyle(
                color: isSelected ? theme.colorScheme.onPrimary : AppTheme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
