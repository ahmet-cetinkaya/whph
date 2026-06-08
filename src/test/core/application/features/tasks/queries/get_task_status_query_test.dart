import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_status_query.dart';

void main() {
  group('GetTaskStatusQuery Tests', () {
    test('should create query with required id', () {
      // Arrange
      const id = 'test-status-id';

      // Act
      final query = GetTaskStatusQuery(id: id);

      // Assert
      expect(query.id, id);
    });

    test('should reject empty id', () {
      // Arrange & Act
      final query = GetTaskStatusQuery(id: '');

      // Assert - empty id is invalid
      expect(query.id, isEmpty);
    });
  });

  group('GetTaskStatusQueryResponse Tests', () {
    test('should create response with all properties', () {
      // Arrange
      const id = 'status-1';
      final createdDate = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final modifiedDate = DateTime.utc(2026, 1, 3);
      const name = 'In Progress';
      const color = '4CAF50';
      const order = 2.5;
      const isBuiltIn = false;
      const isDoneStatus = false;

      // Act
      final response = GetTaskStatusQueryResponse(
        id: id,
        createdDate: createdDate,
        modifiedDate: modifiedDate,
        name: name,
        color: color,
        order: order,
        isBuiltIn: isBuiltIn,
        isDoneStatus: isDoneStatus,
      );

      // Assert
      expect(response.id, id);
      expect(response.createdDate, createdDate);
      expect(response.modifiedDate, modifiedDate);
      expect(response.name, name);
      expect(response.color, color);
      expect(response.order, order);
      expect(response.isBuiltIn, isBuiltIn);
      expect(response.isDoneStatus, isDoneStatus);
    });

    test('should create response with optional null fields', () {
      // Arrange
      const id = 'status-2';
      final createdDate = DateTime.utc(2026, 1, 1);
      final modifiedDate = DateTime.utc(2026, 1, 1);
      const name = 'Done';

      // Act
      final response = GetTaskStatusQueryResponse(
        id: id,
        createdDate: createdDate,
        modifiedDate: modifiedDate,
        name: name,
        color: null,
        order: 1.0,
        isBuiltIn: true,
        isDoneStatus: true,
      );

      // Assert
      expect(response.id, id);
      expect(response.name, name);
      expect(response.color, isNull);
      expect(response.isBuiltIn, isTrue);
      expect(response.isDoneStatus, isTrue);
    });

    test('should create response with empty name for built-in status', () {
      // Arrange
      const id = 'task-status-builtin-todo';
      final createdDate = DateTime.utc(2026, 1, 1);
      final modifiedDate = DateTime.utc(2026, 1, 1);

      // Act
      final response = GetTaskStatusQueryResponse(
        id: id,
        createdDate: createdDate,
        modifiedDate: modifiedDate,
        name: '',
        color: 'FF5722',
        order: 1.0,
        isBuiltIn: true,
        isDoneStatus: false,
      );

      // Assert
      expect(response.id, id);
      expect(response.name, isEmpty);
      expect(response.isBuiltIn, isTrue);
    });
  });
}
