import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/tasks/task_status.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';

void main() {
  group('TaskStatus', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      final created = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final modified = DateTime.utc(2026, 1, 3);
      final status = TaskStatus(
        id: 'status-1',
        createdDate: created,
        modifiedDate: modified,
        name: 'In Progress',
        color: '4CAF50',
        order: 2.5,
        isBuiltIn: false,
        isDoneStatus: false,
      );

      final restored = TaskStatus.fromJson(status.toJson());

      expect(restored.id, equals('status-1'));
      expect(restored.createdDate, equals(created));
      expect(restored.modifiedDate, equals(modified));
      expect(restored.name, equals('In Progress'));
      expect(restored.color, equals('4CAF50'));
      expect(restored.order, equals(2.5));
      expect(restored.isBuiltIn, isFalse);
      expect(restored.isDoneStatus, isFalse);
    });

    test('fromJson tolerates empty name and missing optional fields', () {
      final restored = TaskStatus.fromJson({
        'id': TaskStatusConstants.todoId,
        'createdDate': DateTime.utc(2026, 1, 1).toIso8601String(),
        'name': '',
      });

      expect(restored.name, isEmpty);
      expect(restored.color, isNull);
      expect(restored.order, equals(0.0));
      expect(restored.isBuiltIn, isFalse);
      expect(restored.isDoneStatus, isFalse);
    });

    test('isDoneStatusId recognizes only the built-in done id', () {
      expect(TaskStatusConstants.isDoneStatusId(TaskStatusConstants.doneId), isTrue);
      expect(TaskStatusConstants.isDoneStatusId(TaskStatusConstants.todoId), isFalse);
      expect(TaskStatusConstants.isDoneStatusId(null), isFalse);
      expect(TaskStatusConstants.isDoneStatusId('custom-id'), isFalse);
    });
  });
}
