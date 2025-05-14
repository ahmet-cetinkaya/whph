import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/material.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class Habit extends BaseEntity<String> {
  String name;
  String description;
  int? estimatedTime;

  // Reminder settings
  bool hasReminder = false;
  String? reminderTime; // Stored as "HH:mm" format
  String reminderDays = ''; // Stored as comma-separated values (e.g. "1,2,3,4,5,6,7")

  Habit({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.name,
    required this.description,
    this.estimatedTime,
    this.hasReminder = false,
    this.reminderTime,
    String reminderDays = "",
  });

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
}
