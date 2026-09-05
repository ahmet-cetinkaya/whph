import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/habits/services/habit_day_state_resolver.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';

void main() {
  const resolver = HabitDayStateResolver();
  final now = DateTime(2026, 4, 15, 12);

  Habit habit({
    HabitType type = HabitType.good,
    DateTime? archivedDate,
    int? dailyTarget,
  }) =>
      Habit(
        id: 'habit-id',
        createdDate: DateTime(2026, 4, 10),
        name: 'Read',
        description: '',
        type: type,
        archivedDate: archivedDate,
        dailyTarget: dailyTarget,
      );

  HabitRecord record({
    required String id,
    required DateTime occurredAt,
    HabitRecordStatus status = HabitRecordStatus.complete,
    DateTime? deletedDate,
    String habitId = 'habit-id',
  }) =>
      HabitRecord(
        id: id,
        createdDate: occurredAt,
        habitId: habitId,
        occurredAt: occurredAt,
        status: status,
        deletedDate: deletedDate,
      );

  group('HabitDayStateResolver good habits', () {
    test('Given completions meet the daily target When resolving a day Then it is successful', () {
      final source = resolver.createSource(
        habit: habit(dailyTarget: 2),
        records: [
          record(id: 'first', occurredAt: DateTime(2026, 4, 12, 8)),
          record(id: 'second', occurredAt: DateTime(2026, 4, 12, 20)),
        ],
        now: now,
      );

      expect(source.resolve(DateTime(2026, 4, 12)), HabitDayState.successful);
    });

    test('Given one completion below the daily target When resolving a day Then it is partial', () {
      final source = resolver.createSource(
        habit: habit(dailyTarget: 2),
        records: [record(id: 'complete', occurredAt: DateTime(2026, 4, 12, 8))],
        now: now,
      );

      expect(source.resolve(DateTime(2026, 4, 12)), HabitDayState.partial);
    });

    test('Given an explicit not-done record When resolving a day Then it is failed', () {
      final source = resolver.createSource(
        habit: habit(),
        records: [
          record(
            id: 'not-done',
            occurredAt: DateTime(2026, 4, 12, 8),
            status: HabitRecordStatus.notDone,
          ),
        ],
        now: now,
      );

      expect(source.resolve(DateTime(2026, 4, 12)), HabitDayState.failed);
    });

    test('Given skipped or absent records When resolving a day Then it is incomplete', () {
      final source = resolver.createSource(
        habit: habit(),
        records: [
          record(
            id: 'skipped',
            occurredAt: DateTime(2026, 4, 12, 8),
            status: HabitRecordStatus.skipped,
          ),
        ],
        now: now,
      );

      expect(source.resolve(DateTime(2026, 4, 12)), HabitDayState.incomplete);
      expect(source.resolve(DateTime(2026, 4, 13)), HabitDayState.incomplete);
    });
  });

  group('HabitDayStateResolver bad habits', () {
    test('Given no same-local-day not-done record When resolving an applicable day Then it is successful', () {
      final source = resolver.createSource(
        habit: habit(type: HabitType.bad),
        records: [record(id: 'complete', occurredAt: DateTime(2026, 4, 12, 8))],
        now: now,
      );

      expect(source.resolve(DateTime(2026, 4, 12)), HabitDayState.successful);
    });

    test('Given a same-local-day not-done record When resolving an applicable day Then it is failed', () {
      final source = resolver.createSource(
        habit: habit(type: HabitType.bad),
        records: [
          record(
            id: 'not-done',
            occurredAt: DateTime(2026, 4, 12, 8),
            status: HabitRecordStatus.notDone,
          ),
          record(id: 'complete', occurredAt: DateTime(2026, 4, 12, 20)),
        ],
        now: now,
      );

      expect(source.resolve(DateTime(2026, 4, 12)), HabitDayState.failed);
    });

    test('Given a deleted not-done record When resolving an applicable day Then it is successful', () {
      final source = resolver.createSource(
        habit: habit(type: HabitType.bad),
        records: [
          record(
            id: 'deleted-not-done',
            occurredAt: DateTime(2026, 4, 12, 8),
            status: HabitRecordStatus.notDone,
            deletedDate: DateTime(2026, 4, 13),
          ),
        ],
        now: now,
      );

      expect(source.resolve(DateTime(2026, 4, 12)), HabitDayState.successful);
    });

    test('Given a day before creation, after archive, or after today When resolving Then it is not applicable', () {
      final source = resolver.createSource(
        habit: habit(type: HabitType.bad, archivedDate: DateTime(2026, 4, 13, 20)),
        records: const [],
        now: now,
      );

      expect(source.resolve(DateTime(2026, 4, 9)), HabitDayState.notApplicable);
      expect(source.resolve(DateTime(2026, 4, 14)), HabitDayState.notApplicable);
      expect(source.resolve(DateTime(2026, 4, 16)), HabitDayState.notApplicable);
    });

    test('Given records for another habit or local day When resolving Then they are ignored', () {
      final source = resolver.createSource(
        habit: habit(type: HabitType.bad),
        records: [
          record(
            id: 'other-habit',
            habitId: 'other-id',
            occurredAt: DateTime(2026, 4, 12, 8),
            status: HabitRecordStatus.notDone,
          ),
          record(
            id: 'other-day',
            occurredAt: DateTime(2026, 4, 13, 8),
            status: HabitRecordStatus.notDone,
          ),
        ],
        now: now,
      );

      expect(source.resolve(DateTime(2026, 4, 12)), HabitDayState.successful);
    });

    test('Given a UTC record When resolving its local day Then it is failed', () {
      final occurredAt = DateTime.utc(2026, 4, 13, 0, 30);
      final source = resolver.createSource(
        habit: habit(type: HabitType.bad),
        records: [
          record(
            id: 'utc-not-done',
            occurredAt: occurredAt,
            status: HabitRecordStatus.notDone,
          ),
        ],
        now: DateTime.utc(2026, 4, 14),
      );

      expect(source.resolve(occurredAt.toLocal()), HabitDayState.failed);
    });

    test('Given a source has been created When the input list changes Then its state remains a snapshot', () {
      final records = <HabitRecord>[];
      final source = resolver.createSource(
        habit: habit(type: HabitType.bad),
        records: records,
        now: now,
      );
      records.add(
        record(
          id: 'late-not-done',
          occurredAt: DateTime(2026, 4, 12, 8),
          status: HabitRecordStatus.notDone,
        ),
      );

      expect(source.resolve(DateTime(2026, 4, 12)), HabitDayState.successful);
    });

    test('Given a source has been created When the habit changes Then its state remains a snapshot', () {
      final badHabit = habit(type: HabitType.bad);
      final source = resolver.createSource(
        habit: badHabit,
        records: const [],
        now: now,
      );
      badHabit.type = HabitType.good;

      expect(source.resolve(DateTime(2026, 4, 12)), HabitDayState.successful);
    });
  });
}
