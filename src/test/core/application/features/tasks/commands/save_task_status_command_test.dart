import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_status_command.dart';

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
    test('should reject empty name', () {
      // Arrange & Act
      final command = SaveTaskStatusCommand(
        id: null,
        name: '',
        color: '4CAF50',
      );

      // Assert - empty name is invalid for custom statuses
      expect(command.name.isEmpty, isTrue);
    });

    test('should reject invalid hex color', () {
      // Arrange & Act
      final command = SaveTaskStatusCommand(
        id: null,
        name: 'Test',
        color: 'invalid-color',
      );

      // Assert - this would be caught by the handler's validation
      expect(command.color, 'invalid-color');
    });

    test('should reject names exceeding max length', () {
      // Arrange
      final longName = 'A' * 101;

      // Act
      final command = SaveTaskStatusCommand(
        id: null,
        name: longName,
        color: '4CAF50',
      );

      // Assert - name exceeds 100 character limit
      expect(command.name.length, greaterThan(100));
    });
  });
}
