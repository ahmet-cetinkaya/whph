import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import '../constants/shared_translation_keys.dart';

class DateRangeFilter extends StatelessWidget {
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final Function(DateTime?, DateTime?) onDateFilterChange;
  final double iconSize;
  final Color? iconColor;

  final _translationService = container.resolve<ITranslationService>();

  DateRangeFilter({
    super.key,
    this.selectedStartDate,
    this.selectedEndDate,
    required this.onDateFilterChange,
    this.iconSize = 20,
    this.iconColor,
  });

  String _getDateRangeText() {
    if (selectedStartDate == null || selectedEndDate == null) return '';
    return '${selectedStartDate!.day}/${selectedStartDate!.month} - ${selectedEndDate!.day}/${selectedEndDate!.month}';
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final translationService = container.resolve<ITranslationService>();

    final result = await showModalBottomSheet<List<DateTime?>>(
      context: context,
      backgroundColor: AppTheme.surface1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          translationService.translate(SharedTranslationKeys.dateRangeTitle),
                          style: AppTheme.headlineSmall,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  CalendarDatePicker2(
                    config: CalendarDatePicker2Config(
                      calendarType: CalendarDatePicker2Type.range,
                      selectedDayHighlightColor: Theme.of(context).primaryColor,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2050),
                    ),
                    value: selectedStartDate != null && selectedEndDate != null
                        ? [selectedStartDate, selectedEndDate]
                        : [],
                    onValueChanged: (dates) {
                      // Only pop when we have a valid range (both dates selected)
                      if (dates.length == 2) {
                        Navigator.pop(context, dates);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.length == 2 && result[0] != null && result[1] != null) {
      // Ensure dates are properly set to start and end of day
      final startDate = DateTime(
        result[0]!.year,
        result[0]!.month,
        result[0]!.day,
      );

      final endDate = DateTime(
        result[1]!.year,
        result[1]!.month,
        result[1]!.day,
        23,
        59,
        59,
      );

      // Immediately trigger the callback with the formatted dates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onDateFilterChange(startDate, endDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final hasDateFilter = selectedStartDate != null && selectedEndDate != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterIconButton(
          icon: Icons.calendar_today,
          iconSize: iconSize,
          color: hasDateFilter ? primaryColor : iconColor,
          tooltip: _translationService.translate(SharedTranslationKeys.dateFilterTooltip),
          onPressed: () => _showDatePicker(context),
        ),
        if (hasDateFilter) ...[
          const SizedBox(width: 4),
          Text(
            _getDateRangeText(),
            style: AppTheme.bodySmall.copyWith(
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 4),
          FilterIconButton(
            icon: Icons.close,
            iconSize: AppTheme.iconSizeSmall,
            onPressed: () => onDateFilterChange(null, null),
            tooltip: _translationService.translate(SharedTranslationKeys.clearDateFilterTooltip),
          ),
        ],
      ],
    );
  }
}
