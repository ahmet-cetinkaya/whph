import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_status_command.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';

void main() {
  group('SaveTaskStatusCommand Tests', () {
    test('should create command with all properties', () {
      // Arrange
      const id = 'test-id';
      const name = 'In Progress';
      const color = '4CAF50';
      const order = 2.5;

      // Act
      final command = SaveTaskStatusCommand(
        id: id,
        name: name,
        color: color,
        order: order,
      );

      // Assert
      expect(command.id, id);
      expect(command.name, name);
      expect(command.color, color);
      expect(command.order, order);
    });

    test('should create command with null id for new status', () {
      // Arrange
      const name = 'New Status';
      const color = 'FF5722';

      // Act
      final command = SaveTaskStatusCommand(
        id: null,
        name: name,
        color: color,
      );

      // Assert
      expect(command.id, isNull);
      expect(command.name, name);
      expect(command.color, color);
      expect(command.order, isNull);
    });

    test('should create response with generated ID', () {
      // Arrange
      const id = 'generated-id';
      final createdDate = DateTime.utc(2026, 1, 15, 14, 30);

      // Act
      final response = SaveTaskStatusCommandResponse(
        id: id,
        createdDate: createdDate,
      );

      // Assert
      expect(response.id, id);
      expect(response.createdDate, createdDate);
      expect(response.modifiedDate, isNull);
    });
  });

  group('SaveTaskStatusCommand Validation Tests', () {
    test('should allow empty name for builtin todo status', () {
      // Arrange - builtin statuses have empty stored names (localized at display time)
      final command = SaveTaskStatusCommand(
        id: TaskStatusConstants.todoId,
        name: '',
        color: 'FF5722',
      );

      // Assert - builtin todo status id is recognized
      expect(TaskStatusConstants.isTodoStatusId(command.id), isTrue);
      expect(command.name.isEmpty, isTrue);
    });

    test('should allow empty name for builtin done status', () {
      // Arrange - builtin done status
      final command = SaveTaskStatusCommand(
        id: TaskStatusConstants.doneId,
        name: '',
        color: '4CAF50',
      );

      // Assert - builtin done status id is recognized
      expect(TaskStatusConstants.isDoneStatusId(command.id), isTrue);
      expect(command.name.isEmpty, isTrue);
    });

    test('should identify builtin status ids correctly', () {
      // Assert
      expect(TaskStatusConstants.isBuiltinStatusId(TaskStatusConstants.todoId), isTrue);
      expect(TaskStatusConstants.isBuiltinStatusId(TaskStatusConstants.doneId), isTrue);
      expect(TaskStatusConstants.isBuiltinStatusId('custom-id'), isFalse);
    });
  });
}
