import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/application/features/tasks/models/task_query_filter.dart';

import 'get_list_tasks_query_test.mocks.dart';

@GenerateMocks([
  ITaskRepository,
])
void main() {
  group('GetListTasksQuery Tests', () {
    late MockITaskRepository taskRepository;
    late GetListTasksQueryHandler handler;

    setUp(() {
      taskRepository = MockITaskRepository();
      handler = GetListTasksQueryHandler(
        taskRepository: taskRepository,
      );
    });

    group('Query Creation', () {
      test('should create query with required parameters', () {
        final query = GetListTasksQuery(
          pageIndex: 0,
          pageSize: 10,
        );

        expect(query.pageIndex, 0);
        expect(query.pageSize, 10);
      });
    });

    group('Handler Execution', () {
      test('should call getListWithDetails and return results', () async {
        // Arrange
        final mockItems = [
          TaskListItem(
              id: '1',
              title: 'Task 1',
              priority: EisenhowerPriority.urgentImportant,
              isCompleted: false,
              tags: [TagListItem(id: 't1', name: 'Tag 1')])
        ];

        when(taskRepository.getListWithDetails(
          pageIndex: anyNamed('pageIndex'),
          pageSize: anyNamed('pageSize'),
          filter: anyNamed('filter'),
          includeDeleted: anyNamed('includeDeleted'),
        )).thenAnswer((_) async => PaginatedList<TaskListItem>(
              items: mockItems,
              totalItemCount: 1,
              pageIndex: 0,
              pageSize: 10,
            ));

        // Act
        final result = await handler(GetListTasksQuery(pageIndex: 0, pageSize: 10));

        // Assert
        expect(result.items.length, 1);
        expect(result.items.first.title, 'Task 1');
        verify(taskRepository.getListWithDetails(
                pageIndex: 0, pageSize: 10, filter: anyNamed('filter'), includeDeleted: false))
            .called(1);
      });

      test('should propagate filters appropriately', () async {
        // Arrange
        final startDate = DateTime.utc(2024, 1, 1);
        when(taskRepository.getListWithDetails(
          pageIndex: anyNamed('pageIndex'),
          pageSize: anyNamed('pageSize'),
          filter: anyNamed('filter'),
          includeDeleted: anyNamed('includeDeleted'),
        )).thenAnswer((_) async => PaginatedList(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 10));

        // Act
        await handler(GetListTasksQuery(
            pageIndex: 0,
            pageSize: 10,
            filterByPlannedStartDate: startDate,
            filterBySearch: 'test',
            enableGrouping: true));

        // Assert
        verify(taskRepository.getListWithDetails(
                pageIndex: 0,
                pageSize: 10,
                filter: argThat(
                    predicate<TaskQueryFilter>(
                        (f) => f.plannedStartDate == startDate && f.search == 'test' && f.enableGrouping == true),
                    named: 'filter'),
                includeDeleted: false))
            .called(1);
      });

      test('should propagate errors', () async {
        // Arrange
        when(taskRepository.getListWithDetails(
                pageIndex: anyNamed('pageIndex'),
                pageSize: anyNamed('pageSize'),
                filter: anyNamed('filter'),
                includeDeleted: anyNamed('includeDeleted')))
            .thenThrow(Exception('DB Error'));

        // Act & Assert
        expect(() => handler(GetListTasksQuery(pageIndex: 0, pageSize: 10)), throwsException);
      });
    });
  });
}
