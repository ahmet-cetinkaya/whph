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
  static const Color estimatedTimeColor = Colors.blue;

  // Dimensions
  static const double calendarDaySize = 46.0;
  static const double calendarIconSize = 16.0;
  static const double maxCalendarWidth = 600.0;
  static const double streakBarHeight = 24.0;
  static const double gridSpacing = 4.0;

  // Options
  static const List<int> defaultEstimatedTimeOptions = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120, 180, 240];

  // Utility Methods
  static String formatRecordCount(int count) {
    return count.toString();
  }

  static String formatScore(double score) {
    return '${(score * 100).toStringAsFixed(1)}%';
  }
}
