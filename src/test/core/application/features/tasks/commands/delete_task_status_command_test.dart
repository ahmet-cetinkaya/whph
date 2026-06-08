import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/commands/delete_task_status_command.dart';

void main() {
  group('DeleteTaskStatusCommand Tests', () {
    test('should create command with required id', () {
      // Arrange
      const id = 'test-status-id';

      // Act
      final command = DeleteTaskStatusCommand(id: id);

      // Assert
      expect(command.id, id);
    });

    test('should create response', () {
      // Act
      final response = DeleteTaskStatusCommandResponse();

      // Assert
      expect(response, isNotNull);
    });
  });

  group('DeleteTaskStatusCommand Built-in Protection Tests', () {
    test('should allow deleting todo status ID', () {
      // This tests that the command itself accepts any ID
      // Validation happens in the handler
      final command = DeleteTaskStatusCommand(id: 'task-status-builtin-todo');

      expect(command.id, 'task-status-builtin-todo');
    });

    test('should allow deleting done status ID', () {
      final command = DeleteTaskStatusCommand(id: 'task-status-builtin-done');

      expect(command.id, 'task-status-builtin-done');
    });

    test('should allow deleting custom status ID', () {
      final command = DeleteTaskStatusCommand(id: 'custom-status-123');

      expect(command.id, 'custom-status-123');
    });
  });
}
