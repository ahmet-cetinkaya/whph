import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/infrastructure/persistence/features/tasks/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/drift_task_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/drift_tag_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';

void main() {
  group('Task Queries Integration Tests', () {
    late AppDatabase database;
    late DriftTaskRepository taskRepository;
    late DriftTaskTimeRecordRepository taskTimeRecordRepository;
    late DriftTaskTagRepository taskTagRepository;
    late DriftTagRepository tagRepository;
    late GetTaskQueryHandler getTaskHandler;
    late GetListTasksQueryHandler getListTasksHandler;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      database = AppDatabase.forTesting();
      taskRepository = DriftTaskRepository.withDatabase(database);
      taskTimeRecordRepository = DriftTaskTimeRecordRepository();
      taskTagRepository = DriftTaskTagRepository();
      tagRepository = DriftTagRepository();

      // Initialize the query handlers with the repositories
      getTaskHandler = GetTaskQueryHandler(
        taskRepository: taskRepository,
        taskTimeRecordRepository: taskTimeRecordRepository,
      );

      getListTasksHandler = GetListTasksQueryHandler(
        taskRepository: taskRepository,
        taskTagRepository: taskTagRepository,
        tagRepository: tagRepository,
        taskTimeRecordRepository: taskTimeRecordRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    group('GetTaskQuery Integration Tests', () {
      test('should retrieve a task from the database', () async {
        // Arrange - Create and store a task
        final task = Task(
          id: 'integration-test-1',
          createdDate: DateTime.utc(2024, 1, 1),
          title: 'Integration Test Task',
          description: 'Task for integration testing',
          priority: EisenhowerPriority.urgentImportant,
          plannedDate: DateTime.utc(2024, 1, 15),
          deadlineDate: DateTime.utc(2024, 1, 20),
          estimatedTime: 3600,
          parentTaskId: null,
        );

        await taskRepository.add(task);

        // Act - Execute the query
        final query = GetTaskQuery(id: 'integration-test-1');
        final result = await getTaskHandler(query);

        // Assert - Verify the result
        expect(result.id, task.id);
        expect(result.title, task.title);
        expect(result.description, task.description);
        expect(result.priority, task.priority);
        expect(result.plannedDate, task.plannedDate);
        expect(result.deadlineDate, task.deadlineDate);
        expect(result.estimatedTime, task.estimatedTime);
      });

      test('should throw BusinessException when task does not exist', () async {
        // Act & Assert - Execute the query for a non-existent task
        final query = GetTaskQuery(id: 'non-existent-task');
        expect(
          () => getTaskHandler(query),
          throwsA(isA<BusinessException>()),
        );
      });
    });

    group('GetListTasksQuery Integration Tests', () {
      test('should retrieve paginated list of tasks', () async {
        // Arrange - Create and store multiple tasks
        final tasks = [
          Task(
            id: 'list-test-1',
            createdDate: DateTime.utc(2024, 1, 1),
            title: 'First Task',
            parentTaskId: null,
          ),
          Task(
            id: 'list-test-2',
            createdDate: DateTime.utc(2024, 1, 2),
            title: 'Second Task',
            parentTaskId: null,
          ),
          Task(
            id: 'list-test-3',
            createdDate: DateTime.utc(2024, 1, 3),
            title: 'Third Task',
            parentTaskId: null,
          ),
        ];

        for (final task in tasks) {
          await taskRepository.add(task);
        }

        // Act - Execute the query
        final query = GetListTasksQuery(pageIndex: 0, pageSize: 10);
        final result = await getListTasksHandler(query);

        // Assert - Verify the results
        expect(result.items.length, greaterThanOrEqualTo(3));
        expect(result.totalItemCount, greaterThanOrEqualTo(3));
        expect(result.pageIndex, 0);
        expect(result.pageSize, 10);

        // Check that our created tasks are in the results
        final resultIds = result.items.map((item) => item.id).toList();
        expect(resultIds, contains('list-test-1'));
        expect(resultIds, contains('list-test-2'));
        expect(resultIds, contains('list-test-3'));
      });

      test('should handle empty database', () async {
        // Act - Execute the query with no tasks in database
        final query = GetListTasksQuery(pageIndex: 0, pageSize: 10);
        final result = await getListTasksHandler(query);

        // Assert - Verify empty results
        expect(result.items, isEmpty);
        expect(result.totalItemCount, 0);
        expect(result.pageIndex, 0);
        expect(result.pageSize, 10);
      });

      test('should apply filters correctly', () async {
        // Arrange - Create and store tasks with different properties
        final tasks = [
          Task(
            id: 'filter-test-1',
            createdDate: DateTime.utc(2024, 1, 1),
            title: 'Completed Task',
            completedAt: DateTime.utc(2024, 1, 2),
            parentTaskId: null,
          ),
          Task(
            id: 'filter-test-2',
            createdDate: DateTime.utc(2024, 1, 1),
            title: 'Incomplete Task',
            completedAt: null,
            parentTaskId: null,
          ),
        ];

        for (final task in tasks) {
          await taskRepository.add(task);
        }

        // Act - Execute the query with filter for completed tasks only
        final query = GetListTasksQuery(
          pageIndex: 0,
          pageSize: 10,
          filterByCompleted: true, // Only completed tasks
        );
        final result = await getListTasksHandler(query);

        // Assert - Verify filtered results
        expect(result.items.length, 1);
        expect(result.items[0].id, 'filter-test-1');
        expect(result.items[0].isCompleted, true);
        expect(result.totalItemCount, 1);
      });

      test('should handle pagination correctly', () async {
        // Arrange - Create more tasks than the page size
        final tasks = List.generate(15, (index) {
          return Task(
            id: 'pagination-test-$index',
            createdDate: DateTime.utc(2024, 1, 1).add(Duration(days: index)),
            title: 'Pagination Task $index',
            parentTaskId: null,
          );
        });

        for (final task in tasks) {
          await taskRepository.add(task);
        }

        // Act - Get first page
        final firstPageQuery = GetListTasksQuery(pageIndex: 0, pageSize: 5);
        final firstPageResult = await getListTasksHandler(firstPageQuery);

        // Act - Get second page
        final secondPageQuery = GetListTasksQuery(pageIndex: 1, pageSize: 5);
        final secondPageResult = await getListTasksHandler(secondPageQuery);

        // Assert - Verify pagination results
        expect(firstPageResult.items.length, 5);
        expect(firstPageResult.totalItemCount, 15);
        expect(firstPageResult.pageIndex, 0);
        expect(firstPageResult.pageSize, 5);

        expect(secondPageResult.items.length, 5);
        expect(secondPageResult.totalItemCount, 15);
        expect(secondPageResult.pageIndex, 1);
        expect(secondPageResult.pageSize, 5);

        // Ensure no overlap between pages
        final firstPageIds = firstPageResult.items.map((item) => item.id).toSet();
        final secondPageIds = secondPageResult.items.map((item) => item.id).toSet();
        expect(firstPageIds.intersection(secondPageIds), isEmpty);
      });
    });
  });
}
