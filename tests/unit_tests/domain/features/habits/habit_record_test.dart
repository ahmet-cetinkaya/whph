import 'package:flutter_test/flutter_test.dart';
import 'package:domain/features/habits/habit_record.dart';
import 'package:domain/features/habits/habit_record_status.dart';

void main() {
  group('HabitRecord.fromJson', () {
    group('status field deserialization', () {
      test('should handle String status values (from JSON serialization)', () {
        // Test that fromString path works correctly
        final jsonComplete = {
          'id': 'test-1',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-1',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': 'complete',
        };

        final jsonNotDone = {
          'id': 'test-2',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-1',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': 'not_done',
        };

        final jsonSkipped = {
          'id': 'test-3',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-1',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': 'skipped',
        };

        final resultComplete = HabitRecord.fromJson(jsonComplete);
        final resultNotDone = HabitRecord.fromJson(jsonNotDone);
        final resultSkipped = HabitRecord.fromJson(jsonSkipped);

        expect(resultComplete.status, HabitRecordStatus.complete);
        expect(resultNotDone.status, HabitRecordStatus.notDone);
        expect(resultSkipped.status, HabitRecordStatus.skipped);
      });

      test('should handle int status values (from database with EnumIndexConverter)', () {
        // Test that int path works correctly
        // EnumIndexConverter stores: 0=complete, 1=notDone, 2=skipped
        final jsonInt0 = {
          'id': 'test-1',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-1',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': 0, // int from database
        };

        final jsonInt1 = {
          'id': 'test-2',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-1',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': 1,
        };

        final jsonInt2 = {
          'id': 'test-3',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-1',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': 2,
        };

        final resultInt0 = HabitRecord.fromJson(jsonInt0);
        final resultInt1 = HabitRecord.fromJson(jsonInt1);
        final resultInt2 = HabitRecord.fromJson(jsonInt2);

        expect(resultInt0.status, HabitRecordStatus.complete);
        expect(resultInt1.status, HabitRecordStatus.notDone);
        expect(resultInt2.status, HabitRecordStatus.skipped);
      });

      test('should handle null status with default complete', () {
        final jsonNullStatus = {
          'id': 'test-1',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-1',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': null,
        };

        final result = HabitRecord.fromJson(jsonNullStatus);

        expect(result.status, HabitRecordStatus.complete);
      });

      test('should handle out-of-bounds int status gracefully', () {
        // Test invalid int index
        final jsonInvalidIndex = {
          'id': 'test-1',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-1',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': 99, // Invalid index
        };

        final result = HabitRecord.fromJson(jsonInvalidIndex);

        // Should fallback to default (complete) for invalid index
        expect(result.status, HabitRecordStatus.complete);
      });

      test('should handle unknown String status with fallback to skipped', () {
        // Test unknown String value (fromString falls back to skipped)
        final jsonUnknownString = {
          'id': 'test-1',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-1',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': 'unknown',
        };

        final result = HabitRecord.fromJson(jsonUnknownString);

        // fromString returns 'skipped' as fallback
        expect(result.status, HabitRecordStatus.skipped);
      });

      test('should handle invalid type gracefully with default complete', () {
        // Test invalid type (neither int nor String)
        final jsonInvalidType = {
          'id': 'test-1',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-1',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': true, // bool - invalid type
        };

        final result = HabitRecord.fromJson(jsonInvalidType);

        // Should fallback to default (complete)
        expect(result.status, HabitRecordStatus.complete);
      });
    });

    group('complete round-trip serialization', () {
      test('should serialize and deserialize correctly with String status', () {
        final original = HabitRecord(
          id: 'test-1',
          createdDate: DateTime.parse('2026-01-13T00:00:00.000Z'),
          habitId: 'habit-1',
          occurredAt: DateTime.parse('2026-01-13T00:00:00.000Z'),
          status: HabitRecordStatus.notDone,
        );

        final json = original.toJson();

        // toJson() should always serialize status as String value
        expect(json['status'], 'not_done');

        final deserialized = HabitRecord.fromJson(json);

        expect(deserialized.id, original.id);
        expect(deserialized.habitId, original.habitId);
        expect(deserialized.status, original.status);
      });

      test('should serialize status as String value', () {
        final habitComplete = HabitRecord(
          id: 'test-1',
          createdDate: DateTime.parse('2026-01-13T00:00:00.000Z'),
          habitId: 'habit-1',
          occurredAt: DateTime.parse('2026-01-13T00:00:00.000Z'),
          status: HabitRecordStatus.complete,
        );

        final json = habitComplete.toJson();

        // toJson() should always serialize status as String value
        expect(json['status'], 'complete');
      });
    });

    group('sync compatibility scenarios', () {
      test('should handle database int values during sync (V29->V30 migration scenario)', () {
        // Simulate data coming from database after V29->V30 migration
        // where status is stored as int 0 (complete)
        final dbJson = {
          'id': 'migration-test',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-migration',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': 0, // int from EnumIndexConverter
        };

        final record = HabitRecord.fromJson(dbJson);

        expect(record.status, HabitRecordStatus.complete);
        expect(record.id, 'migration-test');
      });

      test('should handle JSON String values during sync (normal scenario)', () {
        // Simulate data coming from JSON API
        final apiJson = {
          'id': 'api-test',
          'createdDate': '2026-01-13T00:00:00.000Z',
          'habitId': 'habit-api',
          'occurredAt': '2026-01-13T00:00:00.000Z',
          'status': 'skipped', // String from JSON
        };

        final record = HabitRecord.fromJson(apiJson);

        expect(record.status, HabitRecordStatus.skipped);
        expect(record.id, 'api-test');
      });
    });

    group('edge cases', () {
      test('should handle all three enum values correctly as int', () {
        for (var i = 0; i < HabitRecordStatus.values.length; i++) {
          final json = {
            'id': 'test-$i',
            'createdDate': '2026-01-13T00:00:00.000Z',
            'habitId': 'habit-$i',
            'occurredAt': '2026-01-13T00:00:00.000Z',
            'status': i,
          };

          final result = HabitRecord.fromJson(json);
          expect(result.status, HabitRecordStatus.values[i], reason: 'Enum index $i should map to correct status');
        }
      });

      test('should handle all three enum values correctly as String', () {
        final statusStrings = ['complete', 'not_done', 'skipped'];

        for (var i = 0; i < statusStrings.length; i++) {
          final json = {
            'id': 'test-$i',
            'createdDate': '2026-01-13T00:00:00.000Z',
            'habitId': 'habit-$i',
            'occurredAt': '2026-01-13T00:00:00.000Z',
            'status': statusStrings[i],
          };

          final result = HabitRecord.fromJson(json);
          expect(result.status, HabitRecordStatus.values[i],
              reason: 'String "${statusStrings[i]}" should map to correct status');
        }
      });
    });
  });

  group('HabitRecord.recordDate', () {
    test('should return date part without time', () {
      final record = HabitRecord(
        id: 'test-1',
        createdDate: DateTime.parse('2026-01-13T14:30:45.000Z'),
        habitId: 'habit-1',
        occurredAt: DateTime.parse('2026-01-13T10:30:45.000Z'),
        status: HabitRecordStatus.complete,
      );

      expect(record.recordDate, DateTime(2026, 1, 13));
    });
  });
}
