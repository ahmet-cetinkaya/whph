import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';

void main() {
  group('Habit serialization', () {
    test(
      'Given an existing payload when round-tripped then its fields are unchanged',
      () {
        final payload = <String, dynamic>{
          'id': 'habit-1',
          'createdDate': '2024-01-15T09:30:00.000Z',
          'modifiedDate': '2024-01-16T09:30:00.000Z',
          'deletedDate': null,
          'name': 'Read',
          'description': 'Read a chapter',
          'estimatedTime': 30,
          'archivedDate': null,
          'hasReminder': true,
          'reminderTime': '09:30',
          'reminderDays': '1,2,3',
          'hasGoal': true,
          'targetFrequency': 2,
          'periodDays': 7,
          'dailyTarget': 1,
          'order': 'U',
        };

        final serializedHabit = Habit.fromJson(payload).toJson();

        expect(serializedHabit, {...payload, 'type': 'good'});
      },
    );

    test('Given a bad JSON type when round-tripped then it stays bad', () {
      final payload = {..._legacyPayload(), 'type': 'bad'};

      final serializedHabit = Habit.fromJson(payload).toJson();

      expect(serializedHabit, payload);
    });

    test(
      'Given a payload without a type when deserialized then it defaults to good',
      () {
        final habit = Habit.fromJson(_legacyPayload());

        expect(habit.type, HabitType.good);
      },
    );

    test('Given a null type when deserialized then it defaults to good', () {
      final habit = Habit.fromJson({..._legacyPayload(), 'type': null});

      expect(habit.type, HabitType.good);
    });

    test(
      'Given a non-string type when deserialized then it defaults to good',
      () {
        final habit = Habit.fromJson({..._legacyPayload(), 'type': 1});

        expect(habit.type, HabitType.good);
      },
    );

    test(
      'Given an unknown type when deserialized then it defaults to good',
      () {
        final habit = Habit.fromJson({..._legacyPayload(), 'type': 'unknown'});

        expect(habit.type, HabitType.good);
      },
    );
  });
}

Map<String, dynamic> _legacyPayload() => {
      'id': 'habit-1',
      'createdDate': '2024-01-15T09:30:00.000Z',
      'modifiedDate': null,
      'deletedDate': null,
      'name': 'Read',
      'description': 'Read a chapter',
      'estimatedTime': null,
      'archivedDate': null,
      'hasReminder': false,
      'reminderTime': null,
      'reminderDays': '',
      'hasGoal': false,
      'targetFrequency': 1,
      'periodDays': 1,
      'dailyTarget': null,
      'order': 'U',
    };
