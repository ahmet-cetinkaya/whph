import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';

void main() {
  group('GetListTaskStatusesQuery Tests', () {
    test('should create query with default values', () {
      // Act
      final query = const GetListTaskStatusesQuery();

      // Assert
      expect(query.pageIndex, 0);
      expect(query.pageSize, 100);
      expect(query.includeDeleted, isFalse);
    });

    test('should create query with pagination', () {
      // Arrange
      const pageIndex = 2;
      const pageSize = 50;

      // Act
      final query = GetListTaskStatusesQuery(
        pageIndex: pageIndex,
        pageSize: pageSize,
      );

      // Assert
      expect(query.pageIndex, pageIndex);
      expect(query.pageSize, pageSize);
      expect(query.includeDeleted, isFalse);
    });

    test('should create query with includeDeleted flag', () {
      // Act
      final query = GetListTaskStatusesQuery(includeDeleted: true);

      // Assert
      expect(query.pageIndex, 0);
      expect(query.pageSize, 100);
      expect(query.includeDeleted, isTrue);
    });

    test('should create query with all parameters', () {
      // Arrange
      const pageIndex = 1;
      const pageSize = 25;
      const includeDeleted = true;

      // Act
      final query = GetListTaskStatusesQuery(
        pageIndex: pageIndex,
        pageSize: pageSize,
        includeDeleted: includeDeleted,
      );

      // Assert
      expect(query.pageIndex, pageIndex);
      expect(query.pageSize, pageSize);
      expect(query.includeDeleted, includeDeleted);
    });
  });

  group('GetListTaskStatusesQueryResponse Tests', () {
    test('should create response with items', () {
      // Arrange
      final items = [
        TaskStatusListItem(
          id: 'status-1',
          name: 'Todo',
          color: 'FF5722',
          order: 1.0,
          isBuiltIn: true,
          isDoneStatus: false,
        ),
        TaskStatusListItem(
          id: 'status-2',
          name: 'Done',
          color: '4CAF50',
          order: 2.0,
          isBuiltIn: true,
          isDoneStatus: true,
        ),
      ];
      const totalCount = 2;

      // Act
      final response = GetListTaskStatusesQueryResponse(
        items: items,
        totalItemCount: totalCount,
        pageIndex: 0,
        pageSize: 100,
      );

      // Assert
      expect(response.items, items);
      expect(response.items.length, 2);
      expect(response.totalItemCount, totalCount);
    });

    test('should create empty response', () {
      // Act
      final response = GetListTaskStatusesQueryResponse(
        items: const [],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 100,
      );

      // Assert
      expect(response.items, isEmpty);
      expect(response.totalItemCount, 0);
    });

    test('TaskStatusListItem should hold all properties', () {
      // Arrange & Act
      final item = TaskStatusListItem(
        id: 'test-id',
        name: 'In Progress',
        color: '2196F3',
        order: 3.5,
        isBuiltIn: false,
        isDoneStatus: false,
      );

      // Assert
      expect(item.id, 'test-id');
      expect(item.name, 'In Progress');
      expect(item.color, '2196F3');
      expect(item.order, 3.5);
      expect(item.isBuiltIn, isFalse);
      expect(item.isDoneStatus, isFalse);
    });

    test('TaskStatusListItem should accept empty name', () {
      // Arrange & Act
      final item = TaskStatusListItem(
        id: 'builtin-id',
        name: '',
        color: 'FF5722',
        order: 1.0,
        isBuiltIn: true,
        isDoneStatus: false,
      );

      // Assert
      expect(item.name, isEmpty);
      expect(item.isBuiltIn, isTrue);
    });

    test('TaskStatusListItem should accept null color', () {
      // Arrange & Act
      final item = TaskStatusListItem(
        id: 'test-id',
        name: 'Custom',
        color: null,
        order: 1.0,
        isBuiltIn: false,
        isDoneStatus: false,
      );

      // Assert
      expect(item.color, isNull);
    });
  });
}
