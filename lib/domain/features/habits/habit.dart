import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/material.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';

@jsonSerializable
class Habit extends BaseEntity<String> {
  String name;
  String description;
  int? estimatedTime;
  DateTime? archivedDate;

  // Reminder settings
  bool hasReminder = false;
  String? reminderTime; // Stored as "HH:mm" format
  String reminderDays = ''; // Stored as comma-separated values (e.g. "1,2,3,4,5,6,7")

  // Goal settings
  bool hasGoal = false;
  int targetFrequency = 1; // How many times the habit should be performed
  int periodDays = 7; // Over how many days (e.g., 3 times in 7 days)

  Habit({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.name,
    required this.description,
    this.estimatedTime,
    this.archivedDate,
    this.hasReminder = false,
    this.reminderTime,
    String reminderDays = "",
    this.hasGoal = false,
    this.targetFrequency = 1,
    this.periodDays = 7,
  });

  // REMINDER RELATED METHODS

  // Getter to convert reminderDays string to List<int>
  List<int> getReminderDaysAsList() {
    // If reminder is not enabled, return empty list
    if (!hasReminder) {
      return [];
    }

    // If reminderDays is empty but reminder is enabled, return empty list
    // This allows the UI to show no days selected, which is a valid state
    if (reminderDays.isEmpty) {
      return [];
    }

    try {
      // Split by comma and parse each value as int
      final result = reminderDays.split(',').where((s) => s.isNotEmpty).map((s) {
        final trimmed = s.trim();
        return int.parse(trimmed);
      }).toList();

      // Return the parsed result, even if empty
      // This allows the UI to show no days selected, which is a valid state
      return result;
    } catch (e) {
      // Log parsing errors and return empty list
      return [];
    }
  }

  // Helper method to set reminderDays from a List<int>
  void setReminderDaysFromList(List<int> days) {
    // Always use the provided days list, even if it's empty
    // This allows the UI to show no days selected, which is a valid state
    final newValue = days.isEmpty ? '' : days.join(',');
    reminderDays = newValue;
  }

  // Helper method to get the reminder time as TimeOfDay
  TimeOfDay? getReminderTimeOfDay() {
    if (reminderTime == null) {
      return null;
    }

    final parts = reminderTime!.split(':');
    if (parts.length != 2) {
      return null;
    }

    try {
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  // Helper method to set the reminder time from TimeOfDay
  void setReminderTimeOfDay(TimeOfDay time) {
    final formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    reminderTime = formattedTime;
  }

  // GOAL RELATED METHODS

  /// Checks if the habit has an active goal
  bool hasActiveGoal() {
    return hasGoal;
  }

  /// Returns the goal description parameters
  Map<String, int> getGoalDescriptionParams() {
    if (!hasGoal) {
      return {};
    }
    return {'targetFrequency': targetFrequency, 'periodDays': periodDays};
  }

  /// Checks if the goal has been met based on the provided completed count
  bool isGoalMet(int completedCount) {
    if (!hasGoal) {
      return true; // No goal means always met
    }
    return completedCount >= targetFrequency;
  }

  /// Calculates the percentage of goal completion (0.0 to 1.0)
  double getGoalCompletionPercentage(int completedCount) {
    if (!hasGoal || targetFrequency <= 0) {
      return 1.0; // No goal or invalid target means 100% completion
    }

    final percentage = completedCount / targetFrequency;
    // Cap at 100% even if overachieved
    return percentage > 1.0 ? 1.0 : percentage;
  }

  // ARCHIVE RELATED METHODS

  /// Checks if the habit is archived
  bool get isArchived => archivedDate != null;

  /// Archives the habit by setting archivedDate to current DateTime
  void setArchived() {
    archivedDate = DateTimeHelper.toUtcDateTime(DateTime.now());
  }

  /// Unarchives the habit by setting archivedDate to null
  void setUnarchived() {
    archivedDate = null;
  }

  /// Returns the archivedDate value from entity in local time zone
  DateTime? getLocalArchivedDate() {
    return archivedDate != null ? DateTimeHelper.toLocalDateTime(archivedDate!) : null;
  }
}
