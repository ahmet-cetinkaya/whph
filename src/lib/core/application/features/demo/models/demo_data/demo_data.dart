import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';

import 'generators/generators.dart';

/// Contains all demo data that will be populated into the database.
///
/// This class aggregates domain-specific generators for tags, habits,
/// tasks, notes, and app usages.
class DemoData {
  static List<Tag> get tags => DemoTags.tags;
  static List<Habit> get habits => DemoHabits.habits;
  static List<Task> get tasks => DemoTasks.tasks;
  static List<Note> get notes => DemoNotes.notes;
  static List<AppUsage> get appUsages => DemoAppUsages.appUsages;
  static List<HabitRecord> generateHabitRecords(List<Habit> habits) => DemoHabits.generateRecords(habits);
  static List<TaskTimeRecord> generateTaskTimeRecords(List<Task> tasks) => DemoTasks.generateTimeRecords(tasks);
  static List<AppUsageTimeRecord> generateAppUsageTimeRecords(List<AppUsage> appUsages) =>
      DemoAppUsages.generateTimeRecords(appUsages);
}
