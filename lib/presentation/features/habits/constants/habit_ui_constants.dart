import 'package:flutter/material.dart';

class HabitUiConstants {
  // Icons
  static const IconData habitIcon = Icons.refresh;
  static const IconData tagsIcon = Icons.label;
  static const IconData descriptionIcon = Icons.description;
  static const IconData calendarIcon = Icons.calendar_today;
  static const IconData statisticsIcon = Icons.analytics;
  static const IconData recordIcon = Icons.link;
  static const IconData noRecordIcon = Icons.close;
  static const IconData previousIcon = Icons.arrow_back;
  static const IconData nextIcon = Icons.arrow_forward;
  static const IconData lockIcon = Icons.lock;
  static const IconData estimatedTimeIcon = Icons.timer_outlined;

  // Colors
  static const Color completedColor = Colors.green;
  static const Color incompletedColor = Colors.red;

  // Labels
  static const String tagsLabel = 'Tags';
  static const String descriptionLabel = 'Description';
  static const String statisticsLabel = 'Statistics';
  static const String recordsLabel = 'Records';
  static const String overallLabel = 'Overall';
  static const String monthlyLabel = 'Monthly';
  static const String yearlyLabel = 'Yearly';
  static const String recordsCountLabel = 'Records';
  static const String scoreTrendsLabel = 'Score Trends';
  static const String topStreaksLabel = 'Top Streaks';
  static const String estimatedTimeLabel = 'Estimated Time';

  // Messages
  static const String noHabitsFoundMessage = 'No habits found';
  static const String selectTagsHint = 'Select tags to associate';

  static const String deleteHabitConfirmTitle = 'Confirm Delete';
  static const String deleteHabitConfirmMessage = 'Are you sure you want to delete this habit?';

  // Error Messages
  static const String errorLoadingHabit = 'Failed to load habit';
  static const String errorSavingHabit = 'Failed to save habit';
  static const String errorLoadingRecords = 'Failed to load habit records';
  static const String errorCreatingRecord = 'Failed to create habit record';
  static const String errorDeletingRecord = 'Failed to delete habit record';

  // Formatting
  static String formatScore(double score) => '${(score * 100).toStringAsFixed(0)}%';
  static String formatRecordCount(int count) => count.toString();
  static String formatDayCount(int days) => '${days}d';

  // Date formatting
  static const List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Dimensions
  static const double calendarDaySize = 46.0;
  static const double calendarIconSize = 16.0;
  static const double maxCalendarWidth = 600.0;
  static const double streakBarHeight = 24.0;
  static const double gridSpacing = 4.0;

  // Options
  static const List<int> defaultEstimatedTimeOptions = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120, 180, 240];
}
