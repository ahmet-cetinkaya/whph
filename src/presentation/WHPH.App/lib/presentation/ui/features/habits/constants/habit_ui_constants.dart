import 'package:flutter/material.dart';

class HabitUiConstants {
  // Icons
  static const IconData habitIcon = Icons.refresh;
  static const IconData descriptionIcon = Icons.description;
  static const IconData calendarIcon = Icons.calendar_today;
  static const IconData statisticsIcon = Icons.analytics;
  static const IconData recordIcon = Icons.link;
  static const IconData noRecordIcon = Icons.close;
  static const IconData previousIcon = Icons.arrow_back;
  static const IconData nextIcon = Icons.arrow_forward;
  static const IconData lockIcon = Icons.lock;
  static const IconData estimatedTimeIcon = Icons.timer_outlined;
  static const IconData dailyTargetIcon = Icons.my_location;

  // Colors
  static const Color completedColor = Colors.green;
  static const Color inCompletedColor = Colors.red;
  static Color get skippedColor => Colors.grey.withValues(alpha: 0.5);
  static const Color estimatedTimeColor = Colors.blue;

  // Dimensions
  static const double calendarDaySize = 46.0;
  static const double calendarIconSize = 16.0;
  static const double maxCalendarWidth = 600.0;
  static const double streakBarHeight = 24.0;
  static const double gridSpacing = 4.0;

  // Calendar Layout Constants (Shared between HabitCard and HabitsPage)
  static const double calendarPaddingMobile = 8.0;
  static const double calendarPaddingDesktop = 12.0;
  static const double calendarDaySpacing = 4.0;
  static const double calendarTrailingSpacer = 2.0; // Between days and drag handle
  static const double dragHandleSpacer = 8.0; // Between calendar and drag handle
  static const double dragHandlePadding = 4.0; // Padding inside drag handle area
  static const double dragHandleIconSize = 24.0; // Default material icon size

  // Total width added by the drag handle section relative to the calendar
  // Spacer(8) + Padding(right:4) + Icon(24) = 36.0
  static double get dragHandleTotalWidth => dragHandleSpacer + dragHandlePadding + dragHandleIconSize;

  // Options
  static const int defaultEstimatedTime = 20;
  static const List<int> defaultEstimatedTimeOptions = [10, defaultEstimatedTime, 30, 40, 50, 60, 90, 120, 180, 240];

  // Utility Methods
  static String formatRecordCount(int count) {
    return count.toString();
  }

  static String formatScore(double score) {
    return '${(score * 100).toStringAsFixed(1)}%';
  }
}
