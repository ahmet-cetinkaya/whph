import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class TimeChartFilters extends StatefulWidget {
  final DateTime selectedStartDate;
  final DateTime selectedEndDate;
  final Function(DateTime, DateTime) onDateFilterChange;

  const TimeChartFilters({
    super.key,
    required this.selectedStartDate,
    required this.selectedEndDate,
    required this.onDateFilterChange,
  });

  @override
  State<TimeChartFilters> createState() => _TimeChartFiltersState();
}

class _TimeChartFiltersState extends State<TimeChartFilters> {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DateRangeFilter(
              selectedStartDate: widget.selectedStartDate,
              selectedEndDate: widget.selectedEndDate,
              onDateFilterChange: (start, end) {
                if (start != null && end != null) {
                  end = DateTime(end.year, end.month, end.day, 23, 59, 59);
                  widget.onDateFilterChange(start, end);
                }
              },
              iconSize: AppTheme.iconSizeSmall,
              iconColor: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
