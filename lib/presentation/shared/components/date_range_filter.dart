import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class DateRangeFilter extends StatelessWidget {
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final Function(DateTime?, DateTime?) onDateFilterChange;
  final double iconSize;
  final Color? iconColor;

  const DateRangeFilter({
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
                        const Text('Select Date Range', style: AppTheme.headlineSmall),
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
                    ),
                    value: selectedStartDate != null && selectedEndDate != null
                        ? [selectedStartDate, selectedEndDate]
                        : [],
                    onValueChanged: (dates) {
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

    if (result != null && result.length == 2) {
      // Set end date to end of day (23:59:59)
      final endDate = result[1]?.copyWith(hour: 23, minute: 59, second: 59);
      onDateFilterChange(result[0], endDate);
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
          tooltip: 'Filter by date',
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
            iconSize: 16,
            onPressed: () => onDateFilterChange(null, null),
            tooltip: 'Clear date filter',
          ),
        ],
      ],
    );
  }
}
