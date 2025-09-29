import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/models/task_with_total_duration.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:acore/acore.dart';

import 'get_list_tasks_query_test.mocks.dart';

@GenerateMocks([
  ITaskRepository,
  ITaskTagRepository,
  ITagRepository,
])
void main() {
  group('GetListTasksQuery Tests', () {
    late MockITaskRepository taskRepository;
    late MockITaskTagRepository taskTagRepository;
    late MockITagRepository tagRepository;
    late GetListTasksQueryHandler handler;

    setUp(() {
      taskRepository = MockITaskRepository();
      taskTagRepository = MockITaskTagRepository();
      tagRepository = MockITagRepository();
      handler = GetListTasksQueryHandler(
        taskRepository: taskRepository,
        taskTagRepository: taskTagRepository,
        tagRepository: tagRepository,
      );
    });

    group('Query Creation - Nominal Behavior', () {
      test('should create query with required parameters', () {
        // Arrange & Act
        final query = GetListTasksQuery(
          pageIndex: 0,
          pageSize: 10,
        );

        // Assert
        expect(query.pageIndex, 0);
        expect(query.pageSize, 10);
        expect(query.filterByPlannedStartDate, isNull);
        expect(query.filterByPlannedEndDate, isNull);
        expect(query.filterByCompleted, isNull);
      });

      test('should convert date parameters to UTC', () {
        // Arrange
        final localDate = DateTime(2024, 1, 15, 10, 30); // Local time

        // Act
        final query = GetListTasksQuery(
          pageIndex: 0,
          pageSize: 10,
          filterByPlannedStartDate: localDate,
          filterByDeadlineEndDate: localDate,
        );

        // Assert
        expect(query.filterByPlannedStartDate?.isUtc, isTrue);
        expect(query.filterByDeadlineEndDate?.isUtc, isTrue);
      });

      test('should create query with all optional parameters', () {
        // Arrange
        final startDate = DateTime.utc(2024, 1, 1);
        final endDate = DateTime.utc(2024, 12, 31);
        final sortOptions = [
          SortOption<TaskSortFields>(field: TaskSortFields.title, direction: SortDirection.asc),
          SortOption<TaskSortFields>(field: TaskSortFields.createdDate, direction: SortDirection.desc),
        ];

        // Act
        final query = GetListTasksQuery(
          pageIndex: 1,
          pageSize: 20,
          filterByPlannedStartDate: startDate,
          filterByPlannedEndDate: endDate,
          filterByCompleted: true,
          filterBySearch: 'test',
          filterByTags: ['tag1', 'tag2'],
          filterByParentTaskId: 'parent-123',
          sortBy: sortOptions,
          sortByCustomSort: true,
        );

        // Assert
        expect(query.pageIndex, 1);
        expect(query.pageSize, 20);
        expect(query.filterByPlannedStartDate, startDate);
        expect(query.filterByPlannedEndDate, endDate);
        expect(query.filterByCompleted, true);
        expect(query.filterBySearch, 'test');
        expect(query.filterByTags, ['tag1', 'tag2']);
        expect(query.filterByParentTaskId, 'parent-123');
        expect(query.sortBy, sortOptions);
        expect(query.sortByCustomSort, true);
      });
    });

    group('Factory Constructor - Nominal Behavior', () {
      test('should create query for search with subtasks included', () {
        // Arrange
        final sortOptions = [SortOption<TaskSortFields>(field: TaskSortFields.title, direction: SortDirection.asc)];

        // Act
        final query = GetListTasksQuery.forSearch(
          pageIndex: 0,
          pageSize: 10,
          filterByCompleted: false,
          filterBySearch: 'search term',
          sortBy: sortOptions,
        );

        // Assert
        expect(query.pageIndex, 0);
        expect(query.pageSize, 10);
        expect(query.filterByCompleted, false);
        expect(query.filterBySearch, 'search term');
        expect(query.sortBy, sortOptions);
        expect(query.areParentAndSubTasksIncluded, true);
        expect(query.filterByParentTaskId, isNull);
      });
    });

    group('Handler Execution - Nominal Behavior', () {
      test('should return paginated tasks with all properties', () async {
        // Arrange
        final mockTasks = [
          TaskWithTotalDuration(
            id: 'task-1',
            createdDate: DateTime.utc(2024, 1, 1),
            title: 'Task 1',
            totalDuration: 1800,
            priority: EisenhowerPriority.urgentImportant,
            plannedDate: DateTime.utc(2024, 1, 15),
            deadlineDate: DateTime.utc(2024, 1, 20),
            estimatedTime: 3600,
            parentTaskId: 'parent-1',
            order: 1000,
            plannedDateReminderTime: ReminderTime.fiveMinutesBefore,
            deadlineDateReminderTime: ReminderTime.oneHourBefore,
          ),
        ];

        when(taskRepository.getListWithOptions(
          pageIndex: 0,
          pageSize: 10,
          filterByTags: null,
          filterNoTags: false,
          filterByPlannedStartDate: null,
          filterByPlannedEndDate: null,
          filterByDeadlineStartDate: null,
          filterByDeadlineEndDate: null,
          filterDateOr: false,
          filterByCompleted: null,
          filterByCompletedStartDate: null,
          filterByCompletedEndDate: null,
          filterBySearch: null,
          filterByParentTaskId: null,
          areParentAndSubTasksIncluded: false,
          sortBy: [],
          sortByCustomSort: false,
          ignoreArchivedTagVisibility: false,
        )).thenAnswer((_) async => PaginatedList<TaskWithTotalDuration>(
              items: mockTasks,
              totalItemCount: 1,
              pageIndex: 0,
              pageSize: 10,
            ));

        when(taskTagRepository.getList(
          0,
          5,
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => PaginatedList<TaskTag>(
              items: [],
              totalItemCount: 0,
              pageIndex: 0,
              pageSize: 5,
            ));

        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);

        // Act
        final result = await handler(GetListTasksQuery(pageIndex: 0, pageSize: 10));

        // Assert
        expect(result.items.length, 1);
        expect(result.totalItemCount, 1);
        expect(result.pageIndex, 0);
        expect(result.pageSize, 10);

        final taskItem = result.items.first;
        expect(taskItem.id, 'task-1');
        expect(taskItem.title, 'Task 1');
        expect(taskItem.isCompleted, false);
        expect(taskItem.priority, EisenhowerPriority.urgentImportant);
        expect(taskItem.plannedDate, DateTime.utc(2024, 1, 15));
        expect(taskItem.deadlineDate, DateTime.utc(2024, 1, 20));
        expect(taskItem.estimatedTime, 3600);
        expect(taskItem.totalElapsedTime, 1800);
        expect(taskItem.parentTaskId, 'parent-1');
        expect(taskItem.order, 1000);
        expect(taskItem.plannedDateReminderTime, ReminderTime.fiveMinutesBefore);
        expect(taskItem.deadlineDateReminderTime, ReminderTime.oneHourBefore);
      });

      test('should fetch and map tags for each task', () async {
        // Arrange
        final mockTask = TaskWithTotalDuration(
          id: 'task-with-tags',
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Task with Tags',
          totalDuration: 0,
        );

        final mockTaskTags = [
          TaskTag(id: 'tasktag-1', taskId: 'task-with-tags', tagId: 'tag-1', createdDate: DateTime.utc(2024, 1, 1)),
          TaskTag(id: 'tasktag-2', taskId: 'task-with-tags', tagId: 'tag-2', createdDate: DateTime.utc(2024, 1, 1)),
        ];

        final mockTag = Tag(
          id: 'tag-1',
          createdDate: DateTime.utc(2024, 1, 1),
          name: 'Important',
          color: '#FF0000',
        );

        when(taskRepository.getListWithOptions(
          pageIndex: 0,
          pageSize: 10,
          filterByTags: null,
          filterNoTags: false,
          filterByPlannedStartDate: null,
          filterByPlannedEndDate: null,
          filterByDeadlineStartDate: null,
          filterByDeadlineEndDate: null,
          filterDateOr: false,
          filterByCompleted: null,
          filterByCompletedStartDate: null,
          filterByCompletedEndDate: null,
          filterBySearch: null,
          filterByParentTaskId: null,
          areParentAndSubTasksIncluded: false,
          sortBy: [],
          sortByCustomSort: false,
          ignoreArchivedTagVisibility: false,
        )).thenAnswer((_) async => PaginatedList<TaskWithTotalDuration>(
              items: [mockTask],
              totalItemCount: 1,
              pageIndex: 0,
              pageSize: 10,
            ));

        when(taskTagRepository.getList(
          0,
          5,
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => PaginatedList<TaskTag>(
              items: mockTaskTags,
              totalItemCount: 2,
              pageIndex: 0,
              pageSize: 5,
            ));

        when(tagRepository.getById('tag-1')).thenAnswer((_) async => mockTag);
        when(tagRepository.getById('tag-2')).thenAnswer((_) async => null); // Simulate missing tag

        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);

        // Act
        final result = await handler(GetListTasksQuery(pageIndex: 0, pageSize: 10));

        // Assert
        expect(result.items.length, 1);
        final taskItem = result.items.first;
        expect(taskItem.tags.length, 2);

        // First tag should be properly mapped
        expect(taskItem.tags[0].id, 'tag-1');
        expect(taskItem.tags[0].name, 'Important');
        expect(taskItem.tags[0].color, '#FF0000');

        // Second tag should have fallback values since it was null
        expect(taskItem.tags[1].id, 'tag-2');
        expect(taskItem.tags[1].name, 'Unknown Tag');
        expect(taskItem.tags[1].color, isNull);
      });

      test('should calculate subtasks completion percentage for each task', () async {
        // Arrange
        final mockTask = TaskWithTotalDuration(
          id: 'parent-task',
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Parent Task',
          totalDuration: 0,
        );

        final completedTask1 = Task(id: 'subtask-1', createdDate: DateTime.utc(2024, 1, 2), title: 'Subtask 1');
        completedTask1.markCompleted();
        final completedTask2 = Task(id: 'subtask-3', createdDate: DateTime.utc(2024, 1, 4), title: 'Subtask 3');
        completedTask2.markCompleted();

        final mockSubTasks = [
          completedTask1,
          Task(id: 'subtask-2', createdDate: DateTime.utc(2024, 1, 3), title: 'Subtask 2'),
          completedTask2,
          Task(id: 'subtask-4', createdDate: DateTime.utc(2024, 1, 5), title: 'Subtask 4'),
        ];

        when(taskRepository.getListWithOptions(
          pageIndex: 0,
          pageSize: 10,
          filterByTags: null,
          filterNoTags: false,
          filterByPlannedStartDate: null,
          filterByPlannedEndDate: null,
          filterByDeadlineStartDate: null,
          filterByDeadlineEndDate: null,
          filterDateOr: false,
          filterByCompleted: null,
          filterByCompletedStartDate: null,
          filterByCompletedEndDate: null,
          filterBySearch: null,
          filterByParentTaskId: null,
          areParentAndSubTasksIncluded: false,
          sortBy: [],
          sortByCustomSort: false,
          ignoreArchivedTagVisibility: false,
        )).thenAnswer((_) async => PaginatedList<TaskWithTotalDuration>(
              items: [mockTask],
              totalItemCount: 1,
              pageIndex: 0,
              pageSize: 10,
            ));

        when(taskTagRepository.getList(
          0,
          5,
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => PaginatedList<TaskTag>(
              items: [],
              totalItemCount: 0,
              pageIndex: 0,
              pageSize: 5,
            ));

        when(taskRepository.getAll(
          customWhereFilter: anyNamed('customWhereFilter'),
        )).thenAnswer((invocation) async {
          final filter = invocation.namedArguments[#customWhereFilter] as CustomWhereFilter?;
          if (filter != null && filter.query.contains('parent_task_id') && filter.variables.contains('parent-task')) {
            return mockSubTasks;
          }
          return [];
        });

        // Act
        final result = await handler(GetListTasksQuery(pageIndex: 0, pageSize: 10));

        // Assert
        expect(result.items.length, 1);
        final taskItem = result.items.first;
        expect(taskItem.subTasksCompletionPercentage, 50.0); // 2 out of 4 subtasks completed
        expect(taskItem.subTasks.length, 4);
      });

      test('should fix task orders when tasks have order value 0', () async {
        // Arrange
        final mockTasks = [
          TaskWithTotalDuration(
            id: 'task-1',
            createdDate: DateTime.utc(2024, 1, 1),
            title: 'Task 1',
            totalDuration: 0,
            order: 0, // This should be updated
          ),
          TaskWithTotalDuration(
            id: 'task-2',
            createdDate: DateTime.utc(2024, 1, 1),
            title: 'Task 2',
            totalDuration: 0,
            order: 2000, // This should remain unchanged
          ),
        ];

        when(taskRepository.getListWithOptions(
          pageIndex: 0,
          pageSize: 10,
          filterByTags: null,
          filterNoTags: false,
          filterByPlannedStartDate: null,
          filterByPlannedEndDate: null,
          filterByDeadlineStartDate: null,
          filterByDeadlineEndDate: null,
          filterDateOr: false,
          filterByCompleted: null,
          filterByCompletedStartDate: null,
          filterByCompletedEndDate: null,
          filterBySearch: null,
          filterByParentTaskId: null,
          areParentAndSubTasksIncluded: false,
          sortBy: [],
          sortByCustomSort: false,
          ignoreArchivedTagVisibility: false,
        )).thenAnswer((_) async => PaginatedList<TaskWithTotalDuration>(
              items: mockTasks,
              totalItemCount: 2,
              pageIndex: 0,
              pageSize: 10,
            ));

        when(taskTagRepository.getList(
          0,
          5,
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => PaginatedList<TaskTag>(
              items: [],
              totalItemCount: 0,
              pageIndex: 0,
              pageSize: 5,
            ));

        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);

        // Verify that update is called for the task with order 0
        when(taskRepository.update(any)).thenAnswer((_) async {});

        // Act
        await handler(GetListTasksQuery(pageIndex: 0, pageSize: 10));

        // Assert
        verify(taskRepository.update(argThat(
          predicate<TaskWithTotalDuration>(
              (task) => task.id == 'task-1' && task.order == 1000.0 && task.modifiedDate != null),
        ))).called(1);

        verifyNever(taskRepository.update(argThat(
          predicate<TaskWithTotalDuration>((task) => task.id == 'task-2'),
        )));
      });
    });

    group('Handler Execution - Edge Cases', () {
      test('should return empty list when no tasks exist', () async {
        // Arrange
        when(taskRepository.getListWithOptions(
          pageIndex: 0,
          pageSize: 10,
          filterByTags: null,
          filterNoTags: false,
          filterByPlannedStartDate: null,
          filterByPlannedEndDate: null,
          filterByDeadlineStartDate: null,
          filterByDeadlineEndDate: null,
          filterDateOr: false,
          filterByCompleted: null,
          filterByCompletedStartDate: null,
          filterByCompletedEndDate: null,
          filterBySearch: null,
          filterByParentTaskId: null,
          areParentAndSubTasksIncluded: false,
          sortBy: [],
          sortByCustomSort: false,
          ignoreArchivedTagVisibility: false,
        )).thenAnswer((_) async => PaginatedList<TaskWithTotalDuration>(
              items: [],
              totalItemCount: 0,
              pageIndex: 0,
              pageSize: 10,
            ));

        // Act
        final result = await handler(GetListTasksQuery(pageIndex: 0, pageSize: 10));

        // Assert
        expect(result.items, isEmpty);
        expect(result.totalItemCount, 0);
      });

      test('should handle tasks without any tags', () async {
        // Arrange
        final mockTask = TaskWithTotalDuration(
          id: 'task-no-tags',
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Task without tags',
          totalDuration: 0,
        );

        when(taskRepository.getListWithOptions(
          pageIndex: 0,
          pageSize: 10,
          filterByTags: null,
          filterNoTags: false,
          filterByPlannedStartDate: null,
          filterByPlannedEndDate: null,
          filterByDeadlineStartDate: null,
          filterByDeadlineEndDate: null,
          filterDateOr: false,
          filterByCompleted: null,
          filterByCompletedStartDate: null,
          filterByCompletedEndDate: null,
          filterBySearch: null,
          filterByParentTaskId: null,
          areParentAndSubTasksIncluded: false,
          sortBy: [],
          sortByCustomSort: false,
          ignoreArchivedTagVisibility: false,
        )).thenAnswer((_) async => PaginatedList<TaskWithTotalDuration>(
              items: [mockTask],
              totalItemCount: 1,
              pageIndex: 0,
              pageSize: 10,
            ));

        when(taskTagRepository.getList(
          0,
          5,
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => PaginatedList<TaskTag>(
              items: [],
              totalItemCount: 0,
              pageIndex: 0,
              pageSize: 5,
            ));

        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);

        // Act
        final result = await handler(GetListTasksQuery(pageIndex: 0, pageSize: 10));

        // Assert
        expect(result.items.length, 1);
        final taskItem = result.items.first;
        expect(taskItem.tags, isEmpty);
      });

      test('should handle tasks without subtasks', () async {
        // Arrange
        final mockTask = TaskWithTotalDuration(
          id: 'task-no-subtasks',
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Task without subtasks',
          totalDuration: 0,
        );

        when(taskRepository.getListWithOptions(
          pageIndex: 0,
          pageSize: 10,
          filterByTags: null,
          filterNoTags: false,
          filterByPlannedStartDate: null,
          filterByPlannedEndDate: null,
          filterByDeadlineStartDate: null,
          filterByDeadlineEndDate: null,
          filterDateOr: false,
          filterByCompleted: null,
          filterByCompletedStartDate: null,
          filterByCompletedEndDate: null,
          filterBySearch: null,
          filterByParentTaskId: null,
          areParentAndSubTasksIncluded: false,
          sortBy: [],
          sortByCustomSort: false,
          ignoreArchivedTagVisibility: false,
        )).thenAnswer((_) async => PaginatedList<TaskWithTotalDuration>(
              items: [mockTask],
              totalItemCount: 1,
              pageIndex: 0,
              pageSize: 10,
            ));

        when(taskTagRepository.getList(
          0,
          5,
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => PaginatedList<TaskTag>(
              items: [],
              totalItemCount: 0,
              pageIndex: 0,
              pageSize: 5,
            ));

        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);

        // Act
        final result = await handler(GetListTasksQuery(pageIndex: 0, pageSize: 10));

        // Assert
        expect(result.items.length, 1);
        final taskItem = result.items.first;
        expect(taskItem.subTasks, isEmpty);
        expect(taskItem.subTasksCompletionPercentage, 0);
      });
    });

    group('Handler Execution - Error Handling', () {
      test('should handle tag repository errors gracefully', () async {
        // Arrange
        final mockTask = TaskWithTotalDuration(
          id: 'task-tag-error',
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Task with Tag Error',
          totalDuration: 0,
        );

        final mockTaskTag = TaskTag(
            id: 'tasktag-error', taskId: 'task-tag-error', tagId: 'tag-error', createdDate: DateTime.utc(2024, 1, 1));

        when(taskRepository.getListWithOptions(
          pageIndex: 0,
          pageSize: 10,
          filterByTags: null,
          filterNoTags: false,
          filterByPlannedStartDate: null,
          filterByPlannedEndDate: null,
          filterByDeadlineStartDate: null,
          filterByDeadlineEndDate: null,
          filterDateOr: false,
          filterByCompleted: null,
          filterByCompletedStartDate: null,
          filterByCompletedEndDate: null,
          filterBySearch: null,
          filterByParentTaskId: null,
          areParentAndSubTasksIncluded: false,
          sortBy: [],
          sortByCustomSort: false,
          ignoreArchivedTagVisibility: false,
        )).thenAnswer((_) async => PaginatedList<TaskWithTotalDuration>(
              items: [mockTask],
              totalItemCount: 1,
              pageIndex: 0,
              pageSize: 10,
            ));

        when(taskTagRepository.getList(
          0,
          5,
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => PaginatedList<TaskTag>(
              items: [],
              totalItemCount: 0,
              pageIndex: 0,
              pageSize: 5,
            ));

        when(taskTagRepository.getList(
          0,
          5,
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => PaginatedList<TaskTag>(
              items: [mockTaskTag],
              totalItemCount: 1,
              pageIndex: 0,
              pageSize: 5,
            ));

        when(tagRepository.getById('tag-error')).thenThrow(Exception('Tag repository error'));

        when(taskRepository.getAll(
          includeDeleted: anyNamed('includeDeleted'),
          customWhereFilter: anyNamed('customWhereFilter'),
          customOrder: anyNamed('customOrder'),
        )).thenAnswer((_) async => []);

        // Act
        final result = await handler(GetListTasksQuery(pageIndex: 0, pageSize: 10));

        // Assert
        expect(result.items.length, 1);
        final taskItem = result.items.first;
        expect(taskItem.tags.length, 1);
        // Should have fallback values due to error
        expect(taskItem.tags[0].id, 'tag-error');
        expect(taskItem.tags[0].name, 'Error Loading Tag');
        expect(taskItem.tags[0].color, isNull);
      });

      test('should propagate repository errors', () async {
        // Arrange
        when(taskRepository.getListWithOptions(
          pageIndex: 0,
          pageSize: 10,
          filterByTags: null,
          filterNoTags: false,
          filterByPlannedStartDate: null,
          filterByPlannedEndDate: null,
          filterByDeadlineStartDate: null,
          filterByDeadlineEndDate: null,
          filterDateOr: false,
          filterByCompleted: null,
          filterByCompletedStartDate: null,
          filterByCompletedEndDate: null,
          filterBySearch: null,
          filterByParentTaskId: null,
          areParentAndSubTasksIncluded: false,
          sortBy: [],
          sortByCustomSort: false,
          ignoreArchivedTagVisibility: false,
        )).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => handler(GetListTasksQuery(pageIndex: 0, pageSize: 10)),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  group('TaskListItem Tests', () {
    test('should create TaskListItem with all properties', () {
      // Arrange
      final tags = [
        TagListItem(id: 'tag1', name: 'Important', color: '#FF0000'),
      ];
      final subTasks = [
        TaskListItem(
          id: 'subtask1',
          title: 'Subtask 1',
          isCompleted: true,
        ),
      ];

      // Act
      final item = TaskListItem(
        id: 'task-test',
        title: 'Test Task',
        isCompleted: false,
        priority: EisenhowerPriority.urgentImportant,
        plannedDate: DateTime.utc(2024, 1, 15),
        deadlineDate: DateTime.utc(2024, 1, 20),
        tags: tags,
        estimatedTime: 3600,
        totalElapsedTime: 1800,
        parentTaskId: 'parent-123',
        subTasksCompletionPercentage: 50.0,
        subTasks: subTasks,
        order: 2000,
        plannedDateReminderTime: ReminderTime.fiveMinutesBefore,
        deadlineDateReminderTime: ReminderTime.oneHourBefore,
      );

      // Assert
      expect(item.id, 'task-test');
      expect(item.title, 'Test Task');
      expect(item.isCompleted, false);
      expect(item.priority, EisenhowerPriority.urgentImportant);
      expect(item.plannedDate, DateTime.utc(2024, 1, 15));
      expect(item.deadlineDate, DateTime.utc(2024, 1, 20));
      expect(item.tags, tags);
      expect(item.estimatedTime, 3600);
      expect(item.totalElapsedTime, 1800);
      expect(item.parentTaskId, 'parent-123');
      expect(item.subTasksCompletionPercentage, 50.0);
      expect(item.subTasks, subTasks);
      expect(item.order, 2000);
      expect(item.plannedDateReminderTime, ReminderTime.fiveMinutesBefore);
      expect(item.deadlineDateReminderTime, ReminderTime.oneHourBefore);
    });

    test('should create TaskListItem with default values', () {
      // Act
      final item = TaskListItem(
        id: 'minimal-task',
        title: 'Minimal Task',
        isCompleted: true,
      );

      // Assert
      expect(item.id, 'minimal-task');
      expect(item.title, 'Minimal Task');
      expect(item.isCompleted, true);
      expect(item.priority, isNull);
      expect(item.plannedDate, isNull);
      expect(item.deadlineDate, isNull);
      expect(item.tags, isEmpty);
      expect(item.estimatedTime, isNull);
      expect(item.totalElapsedTime, 0);
      expect(item.parentTaskId, isNull);
      expect(item.subTasksCompletionPercentage, 0);
      expect(item.subTasks, isEmpty);
      expect(item.order, 0);
      expect(item.plannedDateReminderTime, ReminderTime.none);
      expect(item.deadlineDateReminderTime, ReminderTime.none);
    });

    test('should copy TaskListItem with updated values', () {
      // Arrange
      final original = TaskListItem(
        id: 'original-task',
        title: 'Original Task',
        isCompleted: false,
        priority: EisenhowerPriority.urgentImportant,
      );

      // Act
      final copy = original.copyWith(
        title: 'Updated Task',
        isCompleted: true,
        priority: EisenhowerPriority.notUrgentImportant,
      );

      // Assert
      expect(copy.id, 'original-task'); // Unchanged
      expect(copy.title, 'Updated Task'); // Updated
      expect(copy.isCompleted, true); // Updated
      expect(copy.priority, EisenhowerPriority.notUrgentImportant); // Updated
    });
  });
}
