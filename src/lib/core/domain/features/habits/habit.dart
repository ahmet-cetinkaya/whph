import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/material.dart';
import 'package:acore/acore.dart';

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
  int targetFrequency = 1;
  int periodDays = 1; // Over how many days (e.g., 1 time in 1 day)

  // Daily target settings for multiple occurrences per day
  int? dailyTarget; // How many times per day (null = 1 for backward compatibility)

  // Custom order for sorting
  double order = 0.0;

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
    this.periodDays = 1,
    this.dailyTarget,
    this.order = 0.0,
  });

  // REMINDER RELATED METHODS

  // Allows the UI to show no days selected, which is a valid state
  List<int> getReminderDaysAsList() {
    if (!hasReminder) {
      return [];
    }

    if (reminderDays.isEmpty) {
      return [];
    }

    try {
      final result = reminderDays.split(',').where((s) => s.isNotEmpty).map((s) {
        final trimmed = s.trim();
        return int.parse(trimmed);
      }).toList();

      return result;
    } catch (e) {
      return [];
    }
  }

  void setReminderDaysFromList(List<int> days) {
    final newValue = days.isEmpty ? '' : days.join(',');
    reminderDays = newValue;
  }

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

  void setReminderTimeOfDay(TimeOfDay time) {
    final formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    reminderTime = formattedTime;
  }

  // GOAL RELATED METHODS

  bool hasActiveGoal() {
    return hasGoal;
  }

  Map<String, int> getGoalDescriptionParams() {
    if (!hasGoal) {
      return {};
    }
    return {'targetFrequency': targetFrequency, 'periodDays': periodDays};
  }

  bool isGoalMet(int completedCount) {
    if (!hasGoal) {
      return true; // No goal means always met
    }
    return completedCount >= targetFrequency;
  }

  double getGoalCompletionPercentage(int completedCount) {
    if (!hasGoal || targetFrequency <= 0) {
      return 1.0; // No goal or invalid target means 100% completion
    }

    final percentage = completedCount / targetFrequency;
    return percentage > 1.0 ? 1.0 : percentage; // Cap at 100% even if overachieved
  }

  // DAILY TARGET RELATED METHODS

  int getDailyTarget() {
    return dailyTarget ?? 1;
  }

  bool isDailyTargetMet(int dailyCount) {
    return dailyCount >= getDailyTarget();
  }

  double getDailyCompletionPercentage(int dailyCount) {
    final target = getDailyTarget();
    if (target <= 0) {
      return 1.0; // No target means 100% completion
    }

    final percentage = dailyCount / target;
    return percentage > 1.0 ? 1.0 : percentage; // Cap at 100% even if overachieved
  }

  // ARCHIVE RELATED METHODS

  bool get isArchived => archivedDate != null;

  void setArchived() {
    archivedDate = DateTime.now().toUtc();
  }

  void setUnarchived() {
    archivedDate = null;
  }

  DateTime? getLocalArchivedDate() {
    return archivedDate != null ? DateTimeHelper.toLocalDateTime(archivedDate!) : null;
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'name': name,
        'description': description,
        'estimatedTime': estimatedTime,
        'archivedDate': archivedDate?.toIso8601String(),
        'hasReminder': hasReminder,
        'reminderTime': reminderTime,
        'reminderDays': reminderDays,
        'hasGoal': hasGoal,
        'targetFrequency': targetFrequency,
        'periodDays': periodDays,
        'dailyTarget': dailyTarget,
        'order': order,
      };

  factory Habit.fromJson(Map<String, dynamic> json) {
    int? estimatedTime;
    final estimatedTimeValue = json['estimatedTime'];
    if (estimatedTimeValue is num) {
      estimatedTime = estimatedTimeValue.toInt();
    }

    int targetFrequency = 1;
    final targetFrequencyValue = json['targetFrequency'];
    if (targetFrequencyValue is num) {
      targetFrequency = targetFrequencyValue.toInt();
    }

    int periodDays = 1;
    final periodDaysValue = json['periodDays'];
    if (periodDaysValue is num) {
      periodDays = periodDaysValue.toInt();
    }

    double order = 0.0;
    final orderValue = json['order'];
    if (orderValue is num) {
      order = orderValue.toDouble();
    }

    int? dailyTarget;
    final dailyTargetValue = json['dailyTarget'];
    if (dailyTargetValue is num) {
      dailyTarget = dailyTargetValue.toInt();
    }

    return Habit(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      name: json['name'] as String,
      description: json['description'] as String,
      estimatedTime: estimatedTime,
      archivedDate: json['archivedDate'] != null ? DateTime.parse(json['archivedDate'] as String) : null,
      hasReminder: json['hasReminder'] as bool? ?? false,
      reminderTime: json['reminderTime'] as String?,
      reminderDays: json['reminderDays'] as String? ?? '',
      hasGoal: json['hasGoal'] as bool? ?? false,
      targetFrequency: targetFrequency,
      periodDays: periodDays,
      dailyTarget: dailyTarget,
      order: order,
    );
  }
}
