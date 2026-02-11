import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/demo/constants/demo_translation_keys.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';

/// Demo habit data generator
class DemoHabits {
  /// Demo habits using translation function
  static List<Habit> getHabits(String Function(String) translate) => [
        Habit(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.habitMeditationName),
          description: translate(DemoTranslationKeys.habitMeditationDescription),
          hasReminder: true,
          reminderTime: '07:00',
          reminderDays: '1,2,3,4,5,6,7',
          hasGoal: true,
          targetFrequency: 5,
          periodDays: 7,
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        Habit(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.habitReadName),
          description: translate(DemoTranslationKeys.habitReadDescription),
          hasReminder: true,
          reminderTime: '20:00',
          reminderDays: '1,2,3,4,5,6,7',
          hasGoal: true,
          targetFrequency: 6,
          periodDays: 7,
          createdDate: DateTime.now().subtract(const Duration(days: 14)),
        ),
        Habit(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.habitExerciseName),
          description: translate(DemoTranslationKeys.habitExerciseDescription),
          hasReminder: true,
          reminderTime: '18:00',
          reminderDays: '1,3,5',
          hasGoal: true,
          targetFrequency: 3,
          periodDays: 7,
          createdDate: DateTime.now().subtract(const Duration(days: 10)),
        ),
        Habit(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.habitDrinkWaterName),
          description: translate(DemoTranslationKeys.habitDrinkWaterDescription),
          hasReminder: true,
          reminderTime: '09:00',
          reminderDays: '1,2,3,4,5,6,7',
          hasGoal: false,
          targetFrequency: 0,
          periodDays: 0,
          createdDate: DateTime.now().subtract(const Duration(days: 5)),
        ),
        Habit(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.habitVitaminsName),
          description: translate(DemoTranslationKeys.habitVitaminsDescription),
          hasReminder: true,
          reminderTime: '08:00',
          reminderDays: '1,2,3,4,5,6,7',
          hasGoal: false,
          targetFrequency: 0,
          periodDays: 0,
          createdDate: DateTime.now().subtract(const Duration(days: 3)),
        ),
        Habit(
          id: KeyHelper.generateStringId(),
          name: translate(DemoTranslationKeys.habitJournalName),
          description: translate(DemoTranslationKeys.habitJournalDescription),
          hasReminder: true,
          reminderTime: '21:00',
          reminderDays: '1,2,3,4,5,6,7',
          hasGoal: true,
          targetFrequency: 5,
          periodDays: 7,
          createdDate: DateTime.now().subtract(const Duration(days: 8)),
        ),
      ];

  /// Generates habit records with realistic progress patterns
  static List<HabitRecord> generateRecords(List<Habit> habits) {
    final records = <HabitRecord>[];
    final now = DateTime.now();

    // Generate records for meditation habit (first habit) - NOT completed today
    if (habits.isNotEmpty) {
      _generateMeditationRecords(habits[0], records, now);
    }

    // Generate records for reading habit (second habit) - completed today
    if (habits.length > 1) {
      _generateReadingRecords(habits[1], records, now);
    }

    // Generate records for exercise habit (third habit) - completed today
    if (habits.length > 2) {
      _generateExerciseRecords(habits[2], records, now);
    }

    // Generate records for water habit (fourth habit) - completed today
    if (habits.length > 3) {
      _generateDailyHabitRecords(habits[3], records, now, completionRate: 0.95);
    }

    // Generate records for vitamins habit (fifth habit) - NOT completed today
    if (habits.length > 4) {
      _generateDailyHabitRecords(habits[4], records, now, completionRate: 0.85, skipToday: true);
    }

    // Generate records for journal habit (sixth habit) - completed today
    if (habits.length > 5) {
      _generateDailyHabitRecords(habits[5], records, now, completionRate: 0.75);
    }

    return records;
  }

  static void _generateMeditationRecords(Habit habit, List<HabitRecord> records, DateTime now) {
    for (int i = 1; i < 365; i++) {
      final recordDate = now.subtract(Duration(days: i));
      bool shouldComplete = false;

      if (i >= 335) {
        shouldComplete = i % 10 != 0 && i % 7 != 6;
      } else if (i >= 280) {
        shouldComplete = i % 7 != 0 && i % 5 != 1 && i % 11 != 0;
      } else if (i >= 210) {
        shouldComplete = i % 6 != 0 && i % 9 != 1;
      } else if (i >= 140) {
        shouldComplete = i % 8 != 0 && i % 13 != 2;
      } else if (i >= 70) {
        shouldComplete = i % 7 != 0 && i % 12 != 0;
      } else if (i >= 35) {
        shouldComplete = i % 5 != 0 && i % 3 != 1 && i % 8 != 2;
      } else {
        shouldComplete = i % 6 != 0 && i % 13 != 0;
      }

      if (shouldComplete) {
        records.add(HabitRecord(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          occurredAt: recordDate,
          createdDate: recordDate,
          status: HabitRecordStatus.complete,
        ));
      } else if (i % 5 == 0) {
        records.add(HabitRecord(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          occurredAt: recordDate,
          createdDate: recordDate,
          status: HabitRecordStatus.notDone,
        ));
      }
    }
  }

  static void _generateReadingRecords(Habit habit, List<HabitRecord> records, DateTime now) {
    for (int i = 0; i < 365; i++) {
      final recordDate = now.subtract(Duration(days: i));
      bool shouldComplete = false;

      if (i < 7) {
        shouldComplete = i % 4 != 3;
      } else if (i >= 28 && i < 35) {
        shouldComplete = false;
      } else if (i >= 90 && i < 104) {
        shouldComplete = i % 7 == 0;
      } else if (i >= 200 && i < 207) {
        shouldComplete = false;
      } else if (i >= 300 && i < 314) {
        shouldComplete = i % 5 == 0;
      } else {
        shouldComplete = i % 10 != 0;
      }

      if (shouldComplete) {
        records.add(HabitRecord(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          occurredAt: recordDate,
          createdDate: recordDate,
          status: HabitRecordStatus.complete,
        ));
      } else if (i % 14 == 0) {
        records.add(HabitRecord(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          occurredAt: recordDate,
          createdDate: recordDate,
          status: HabitRecordStatus.notDone,
        ));
      }
    }
  }

  static void _generateExerciseRecords(Habit habit, List<HabitRecord> records, DateTime now) {
    for (int i = 0; i < 365; i++) {
      final recordDate = now.subtract(Duration(days: i));
      final weekday = recordDate.weekday;

      bool shouldComplete = false;

      if (weekday == 1 || weekday == 3 || weekday == 5) {
        if (i == 0) {
          shouldComplete = true;
        } else if (i < 14) {
          shouldComplete = i % 7 != 0;
        } else if (i >= 60 && i < 74) {
          shouldComplete = i % 3 == 0;
        } else if (i >= 180 && i < 194) {
          shouldComplete = false;
        } else {
          shouldComplete = i % 8 != 0;
        }
      }

      if (shouldComplete) {
        records.add(HabitRecord(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          occurredAt: recordDate,
          createdDate: recordDate,
          status: HabitRecordStatus.complete,
        ));
      } else if (weekday == 1 || weekday == 3 || weekday == 5) {
        if (i % 4 == 0) {
          records.add(HabitRecord(
            id: KeyHelper.generateStringId(),
            habitId: habit.id,
            occurredAt: recordDate,
            createdDate: recordDate,
            status: HabitRecordStatus.notDone,
          ));
        }
      }
    }
  }

  static void _generateDailyHabitRecords(
    Habit habit,
    List<HabitRecord> records,
    DateTime now, {
    required double completionRate,
    bool skipToday = false,
  }) {
    final skipInterval = (1 / (1 - completionRate)).round();

    for (int i = skipToday ? 1 : 0; i < 60; i++) {
      final recordDate = now.subtract(Duration(days: i));

      if (i % skipInterval != 0) {
        records.add(HabitRecord(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          occurredAt: recordDate,
          createdDate: recordDate,
          status: HabitRecordStatus.complete,
        ));
      } else if (i % (skipInterval * 2) == 0) {
        // Every other skipped day is marked as Not Done
        records.add(HabitRecord(
          id: KeyHelper.generateStringId(),
          habitId: habit.id,
          occurredAt: recordDate,
          createdDate: recordDate,
          status: HabitRecordStatus.notDone,
        ));
      }
    }
  }
}
