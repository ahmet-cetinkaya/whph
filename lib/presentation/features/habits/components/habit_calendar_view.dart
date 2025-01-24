import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class HabitCalendarView extends StatelessWidget {
  final DateTime currentMonth;
  final List<HabitRecordListItem> records;
  final Function(String) onDeleteRecord;
  final Function(String, DateTime) onCreateRecord;
  final Function() onPreviousMonth;
  final Function() onNextMonth;
  final String habitId;

  const HabitCalendarView({
    super.key,
    required this.currentMonth,
    required this.records,
    required this.onDeleteRecord,
    required this.onCreateRecord,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.habitId,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 600,
        child: Column(
          children: [
            _buildMonthNavigation(),
            const SizedBox(height: 8.0),
            _buildWeekdayLabels(),
            const SizedBox(height: 4.0),
            _buildMonthlyCalendar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onPreviousMonth,
        ),
        Text(
          DateFormat.yMMMM().format(currentMonth),
          style: AppTheme.bodyLarge,
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: onNextMonth,
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels() {
    const List<String> daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: daysOfWeek
          .map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMonthlyCalendar() {
    // Calculate the days of the month
    int daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    int firstWeekdayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1).weekday;
    int previousMonthDays = firstWeekdayOfMonth - 1;

    // Calculate the days of the previous month
    DateTime firstDayOfPreviousMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    int daysInPreviousMonth = DateTime(firstDayOfPreviousMonth.year, firstDayOfPreviousMonth.month + 1, 0).day;

    // Calculate the days of the next month
    int lastWeekdayOfMonth = DateTime(currentMonth.year, currentMonth.month, daysInMonth).weekday;
    int nextMonthDays = 7 - lastWeekdayOfMonth;

    List<DateTime> days = List.generate(daysInMonth + previousMonthDays + nextMonthDays, (index) {
      if (index < previousMonthDays) {
        return DateTime(firstDayOfPreviousMonth.year, firstDayOfPreviousMonth.month,
            daysInPreviousMonth - previousMonthDays + index + 1);
      } else if (index >= previousMonthDays + daysInMonth) {
        return DateTime(currentMonth.year, currentMonth.month + 1, index - (previousMonthDays + daysInMonth) + 1);
      } else {
        return DateTime(currentMonth.year, currentMonth.month, index - previousMonthDays + 1);
      }
    });

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: days.map((date) {
        bool hasRecord = records.any((record) => _isSameDay(record.date, date));
        bool isFutureDate = date.isAfter(DateTime.now());

        HabitRecordListItem? recordForDay;
        if (hasRecord) {
          recordForDay = records.firstWhere((record) => _isSameDay(record.date, date));
        }

        return ElevatedButton(
          onPressed: isFutureDate
              ? null
              : () async {
                  if (hasRecord) {
                    await onDeleteRecord(recordForDay!.id);
                  } else {
                    await onCreateRecord(habitId, date);
                  }
                },
          style: ElevatedButton.styleFrom(
            foregroundColor: AppTheme.textColor,
            disabledBackgroundColor: AppTheme.surface2,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            side: BorderSide(color: AppTheme.surface1),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${date.day}',
                  style: AppTheme.bodySmall,
                ),
                if (date.isAfter(DateTime.now()))
                  const Icon(Icons.lock, size: 12, color: Colors.grey)
                else
                  Icon(
                    hasRecord ? Icons.link : Icons.close,
                    color: hasRecord ? Colors.green : Colors.red,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
}
