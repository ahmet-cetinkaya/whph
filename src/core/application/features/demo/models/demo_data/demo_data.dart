import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/habits/habit.dart';
import 'package:domain/features/tags/tag.dart';
import 'package:domain/features/notes/note.dart';
import 'package:domain/features/habits/habit_record.dart';
import 'package:domain/features/tasks/task_time_record.dart';
import 'package:domain/features/app_usages/app_usage.dart';
import 'package:domain/features/app_usages/app_usage_time_record.dart';

import 'generators/generators.dart';
import '../../translations/demo_translations_registry.dart';

/// Contains all demo data that will be populated into the database.
///
/// This class aggregates domain-specific generators for tags, habits,
/// tasks, notes, and app usages. Use [forLocale] to get translated demo data.
class DemoData {
  /// Get demo data for a specific locale.
  /// Falls back to English if locale is not supported.
  static DemoDataForLocale forLocale(String locale) {
    return DemoDataForLocale(locale);
  }

  // Legacy static getters for backward compatibility (default to English)
  static List<Tag> get tags => DemoTags.getTags((key) => DemoTranslationsRegistry.translate(key, 'en'));
  static List<Habit> get habits => DemoHabits.getHabits((key) => DemoTranslationsRegistry.translate(key, 'en'));
  static List<Task> get tasks => DemoTasks.getTasks((key) => DemoTranslationsRegistry.translate(key, 'en'));
  static List<Note> get notes => DemoNotes.getNotes((key) => DemoTranslationsRegistry.translate(key, 'en'));
  static List<AppUsage> get appUsages => DemoAppUsages.appUsages;
  static List<HabitRecord> generateHabitRecords(List<Habit> habits) => DemoHabits.generateRecords(habits);
  static List<TaskTimeRecord> generateTaskTimeRecords(List<Task> tasks) => DemoTasks.generateTimeRecords(tasks);
  static List<AppUsageTimeRecord> generateAppUsageTimeRecords(List<AppUsage> appUsages) =>
      DemoAppUsages.generateTimeRecords(appUsages);
}

/// Demo data container for a specific locale.
class DemoDataForLocale {
  final String locale;

  DemoDataForLocale(this.locale);

  String _translate(String key) => DemoTranslationsRegistry.translate(key, locale);

  List<Tag> get tags => DemoTags.getTags(_translate);
  List<Habit> get habits => DemoHabits.getHabits(_translate);
  List<Task> get tasks => DemoTasks.getTasks(_translate);
  List<Note> get notes => DemoNotes.getNotes(_translate);
  List<AppUsage> get appUsages => DemoAppUsages.appUsages;
  List<HabitRecord> generateHabitRecords(List<Habit> habits) => DemoHabits.generateRecords(habits);
  List<TaskTimeRecord> generateTaskTimeRecords(List<Task> tasks) => DemoTasks.generateTimeRecords(tasks);
  List<AppUsageTimeRecord> generateAppUsageTimeRecords(List<AppUsage> appUsages) =>
      DemoAppUsages.generateTimeRecords(appUsages);
}
