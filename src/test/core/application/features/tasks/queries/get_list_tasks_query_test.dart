import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_status_repository.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/application/features/tasks/models/task_query_filter.dart';

import 'get_list_tasks_query_test.mocks.dart';

@GenerateMocks([
  ITaskRepository,
  ITaskStatusRepository,
])
void main() {
  group('GetListTasksQuery Tests', () {
    late MockITaskRepository taskRepository;
    late MockITaskStatusRepository taskStatusRepository;
    late GetListTasksQueryHandler handler;

    setUp(() {
      taskRepository = MockITaskRepository();
      taskStatusRepository = MockITaskStatusRepository();
      handler = GetListTasksQueryHandler(
        taskRepository: taskRepository,
        taskStatusRepository: taskStatusRepository,
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

      test('should propagate includeNullDates filter', () async {
        // Arrange
        when(taskRepository.getListWithDetails(
          pageIndex: anyNamed('pageIndex'),
          pageSize: anyNamed('pageSize'),
          filter: anyNamed('filter'),
          includeDeleted: anyNamed('includeDeleted'),
        )).thenAnswer((_) async => PaginatedList(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 10));

        // Act
        await handler(GetListTasksQuery(pageIndex: 0, pageSize: 10, includeNullDates: true));

        // Assert
        verify(taskRepository.getListWithDetails(
                pageIndex: 0,
                pageSize: 10,
                filter: argThat(predicate<TaskQueryFilter>((f) => f.includeNullDates == true), named: 'filter'),
                includeDeleted: false))
            .called(1);
      });

      group('custom sort ordering', () {
        /// Captures the CustomOrder list the handler hands to the repository,
        /// which is the only observable form the ordering decision takes.
        Future<List<String>> capturedOrderFields(GetListTasksQuery query) async {
          when(taskRepository.getListWithDetails(
            pageIndex: anyNamed('pageIndex'),
            pageSize: anyNamed('pageSize'),
            filter: anyNamed('filter'),
            includeDeleted: anyNamed('includeDeleted'),
          )).thenAnswer((_) async => PaginatedList(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 10));

          await handler(query);

          final captured = verify(taskRepository.getListWithDetails(
            pageIndex: anyNamed('pageIndex'),
            pageSize: anyNamed('pageSize'),
            filter: captureAnyNamed('filter'),
            includeDeleted: anyNamed('includeDeleted'),
          )).captured.single as TaskQueryFilter;

          return (captured.sortBy ?? const <CustomOrder>[]).map((order) => order.field).toList();
        }

        /// The two cases below differ only in `enableGrouping`, so the group
        /// field must be one that does not pull in status resolution.
        GetListTasksQuery customSortQuery({required bool enableGrouping}) => GetListTasksQuery(
              pageIndex: 0,
              pageSize: 10,
              sortByCustomSort: true,
              enableGrouping: enableGrouping,
              groupBy: SortOption(field: TaskSortFields.priority, direction: SortDirection.asc),
            );

        test('a stale groupBy does not prefix the order while grouping is disabled', () async {
          // Disabling grouping leaves groupBy in the saved settings. Prefixing
          // the manual ranks with it would rank items only within that dormant
          // group instead of globally.
          final fields = await capturedOrderFields(customSortQuery(enableGrouping: false));

          expect(fields, ['order', 'created_date', 'id']);
        });

        test('an active groupBy still prefixes the order', () async {
          final fields = await capturedOrderFields(customSortQuery(enableGrouping: true));

          expect(fields.first, isNot('order'), reason: 'grouping must still partition the custom order');
          expect(fields.sublist(fields.length - 3), ['order', 'created_date', 'id']);
        });
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
