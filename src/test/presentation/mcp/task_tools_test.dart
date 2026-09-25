import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart' hide Task;
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_time_record_command.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_total_duration_by_task_id_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/application/features/tasks/services/mcp_task_actions.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/settings/repositories/drift_settings_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_status_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/services/drift_application_transaction_service.dart';
import 'package:whph/presentation/mcp/tools/task_tools.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/mcp_tool_registry.dart';

void main() {
  late AppDatabase database;
  late DriftTaskRepository tasks;
  late McpTaskActions actions;
  late Mediator mediator;
  late _Recurrence recurrence;

  setUp(() {
    database = AppDatabase.forTesting();
    AppDatabase.setInstanceForTesting(database);
    tasks = DriftTaskRepository.withDatabase(database);
    mediator = Mediator(Pipeline());
    final taskTags = DriftTaskTagRepository.withDatabase(database);
    final timeRecords = DriftTaskTimeRecordRepository.withDatabase(database);
    final tags = DriftTagRepository.withDatabase(database);
    final events = _Events();
    mediator
      ..registerHandler<SaveTaskCommand, SaveTaskCommandResponse, SaveTaskCommandHandler>(
        () => SaveTaskCommandHandler(
          taskService: tasks,
          taskTagRepository: taskTags,
          taskTimeRecordRepository: timeRecords,
          settingRepository: DriftSettingRepository.withDatabase(database),
          taskEvents: events,
        ),
      )
      ..registerHandler<GetTaskQuery, GetTaskQueryResponse, GetTaskQueryHandler>(
        () => GetTaskQueryHandler(taskRepository: tasks, taskTimeRecordRepository: timeRecords),
      )
      ..registerHandler<GetListTaskTagsQuery, GetListTaskTagsQueryResponse, GetListTaskTagsQueryHandler>(
        () => GetListTaskTagsQueryHandler(tagRepository: tags, taskTagRepository: taskTags),
      )
      ..registerHandler<AddTaskTimeRecordCommand, AddTaskTimeRecordCommandResponse, AddTaskTimeRecordCommandHandler>(
        () => AddTaskTimeRecordCommandHandler(
          taskTimeRecordRepository: timeRecords,
          taskEvents: events,
        ),
      )
      ..registerHandler<GetTotalDurationByTaskIdQuery, GetTotalDurationByTaskIdQueryResponse,
          GetTotalDurationByTaskIdQueryHandler>(
        () => GetTotalDurationByTaskIdQueryHandler(taskTimeRecordRepository: timeRecords),
      );
    recurrence = _Recurrence();
    actions = McpTaskActions(
      transactions: DriftApplicationTransactionService(database),
      taskRepository: tasks,
      taskStatusRepository: DriftTaskStatusRepository.withDatabase(database),
      taskTagRepository: taskTags,
      taskTimeRecordRepository: timeRecords,
      tagRepository: tags,
      taskEvents: events,
      recurrenceService: recurrence,
      mediator: mediator,
    );
  });

  tearDown(() async {
    await database.close();
    AppDatabase.resetInstance();
  });

  test('catalog exposes every canonical task and time tool with closed schemas', () {
    final tools = buildTaskTools(
      mediator: Mediator(Pipeline()),
      actions: actions,
      authorizeBeforeCommit: (extra, scopes) async => true,
    );
    expect(tools.map((tool) => tool.name), [
      'whph_tasks_list',
      'whph_tasks_read',
      'whph_tasks_create',
      'whph_tasks_update',
      'whph_tasks_delete',
      'whph_tasks_set_completion',
      'whph_tasks_reorder',
      'whph_tasks_import',
      'whph_task_time_records_list',
      'whph_task_time_records_add',
      'whph_task_time_records_update',
      'whph_task_time_total',
    ]);
    expect(tools.every((tool) => tool.inputSchema.additionalProperties == false), isTrue);
    expect(tools.every((tool) => tool.outputSchema.additionalProperties == false), isTrue);
  });

  test('public tools create, read, patch, complete, reopen, and delete in SQLite', () async {
    final tools = buildTaskTools(
      mediator: mediator,
      actions: actions,
      authorizeBeforeCommit: (extra, scopes) async => true,
    );
    Future<Map<String, dynamic>> call(String name, Map<String, dynamic> arguments) async {
      final result = await tools.singleWhere((tool) => tool.name == name).handler(
            McpToolArguments(arguments),
            _extra(),
          );
      expect(result.isError, isFalse, reason: '$name: ${result.structuredContent}');
      return result.structuredContent!;
    }

    final created = await call('whph_tasks_create', {
      'title': 'Tool task',
      'description': 'clear me',
      'plannedAt': '2026-09-09T09:00:00+03:00',
      'plannedReminder': {'time': 'custom', 'customOffsetMinutes': 30},
      'recurrence': {'type': 'daily', 'interval': 2},
    });
    final id = created['id'] as String;
    final read = await call('whph_tasks_read', {'id': id});
    expect(read['plannedAt'], '2026-09-09T06:00:00.000Z');

    final patched = await call('whph_tasks_update', {
      'id': id,
      'expectedRevision': created['revision'],
      'description': null,
      'plannedReminder': null,
      'recurrence': null,
    });
    final persistedPatch = (await tasks.getById(id))!;
    expect(persistedPatch.description, isNull);
    expect(persistedPatch.plannedDateReminderTime, ReminderTime.none);
    expect(persistedPatch.plannedDateReminderCustomOffset, isNull);
    expect(persistedPatch.recurrenceType, RecurrenceType.none);
    expect(persistedPatch.recurrenceInterval, isNull);
    final bypassCompletion = await tools.singleWhere((tool) => tool.name == 'whph_tasks_update').handler(
          McpToolArguments({
            'id': id,
            'expectedRevision': patched['revision'],
            'statusId': TaskStatusConstants.doneId,
          }),
          _extra(),
        );
    expect(bypassCompletion.structuredContent?['error'], containsPair('code', 'validation_error'));
    await call('whph_task_time_records_add', {
      'taskId': id,
      'durationSeconds': 30,
      'occurredAt': '2026-09-09T03:00:00+03:00',
    });
    final records = await call('whph_task_time_records_list', {'taskId': id});
    expect(records['totalDurationSeconds'], 30);
    expect((records['items'] as List).single['occurredAt'], '2026-09-09T00:00:00.000Z');
    final total = await call('whph_task_time_total', {'taskId': id});
    expect(total['totalDurationSeconds'], 30);
    final timed = await call('whph_task_time_records_update', {
      'taskId': id,
      'date': '2026-09-09',
      'totalDurationSeconds': 45,
      'expectedRevision': patched['revision'],
    });
    final replacedRecords = await call('whph_task_time_records_list', {'taskId': id});
    expect(replacedRecords['totalDurationSeconds'], 45);
    expect((replacedRecords['items'] as List), hasLength(1));
    final completed = await call('whph_tasks_set_completion', {
      'id': id,
      'expectedRevision': timed['revision'],
      'isCompleted': true,
      'completedAt': '2026-09-09T10:00:00+03:00',
    });
    final repeated = await call('whph_tasks_set_completion', {
      'id': id,
      'expectedRevision': completed['revision'],
      'isCompleted': true,
    });
    expect(repeated['revision'], completed['revision']);
    expect(recurrence.completionCalls, 1);
    final reopened = await call('whph_tasks_set_completion', {
      'id': id,
      'expectedRevision': repeated['revision'],
      'isCompleted': false,
    });
    await call('whph_tasks_delete', {'id': id, 'expectedRevision': reopened['revision']});
    expect(await tasks.getById(id), isNull);
  });

  test('update distinguishes omitted fields from explicit null and rejects stale revisions', () async {
    final created = DateTime.utc(2026, 9, 8, 10);
    await tasks.add(Task(
      id: 'task-1',
      createdDate: created,
      title: 'Original',
      description: 'clear me',
      plannedDate: DateTime.utc(2026, 9, 9, 10),
    ));
    final stored = (await tasks.getById('task-1'))!;
    final revision = stored.modifiedDate ?? stored.createdDate;
    final repositoryInput = stored.copyWith(title: 'Repository CAS');
    final committedRevision = await tasks.updateIfRevision(repositoryInput, revision);
    expect(committedRevision, isNotNull);
    expect(repositoryInput.modifiedDate, stored.modifiedDate);
    final result = await actions.updateTask(
      id: stored.id,
      expectedRevision: committedRevision!,
      patch: const McpTaskPatch({'description': null}),
      beforeCommit: () async {},
    );

    final updated = (await tasks.getById(stored.id))!;
    expect(updated.title, 'Repository CAS');
    expect(updated.description, isNull);
    expect(updated.plannedDate, isNotNull);
    expect(result.revision.isAfter(committedRevision), isTrue);
    await expectLater(
      actions.updateTask(
        id: stored.id,
        expectedRevision: committedRevision,
        patch: const McpTaskPatch({'title': 'stale'}),
        beforeCommit: () async {},
      ),
      throwsA(isA<McpRevisionConflictException>()),
    );
  });

  test('parent cycle and revoked before-commit guard leave persisted task unchanged', () async {
    await tasks.add(Task(id: 'parent', createdDate: DateTime.now().toUtc(), title: 'Parent'));
    await tasks.add(Task(
      id: 'child',
      createdDate: DateTime.now().toUtc(),
      title: 'Child',
      parentTaskId: 'parent',
    ));
    final parent = (await tasks.getById('parent'))!;
    final revision = parent.modifiedDate ?? parent.createdDate;

    await expectLater(
      actions.updateTask(
        id: parent.id,
        expectedRevision: revision,
        patch: const McpTaskPatch({'parentId': 'child'}),
        beforeCommit: () async {},
      ),
      throwsArgumentError,
    );
    await expectLater(
      actions.updateTask(
        id: parent.id,
        expectedRevision: revision,
        patch: const McpTaskPatch({'title': 'must rollback'}),
        beforeCommit: () async => throw StateError('revoked'),
      ),
      throwsStateError,
    );
    expect((await tasks.getById(parent.id))!.title, 'Parent');
  });

  test('create rolls back the task when a relationship write fails', () async {
    final tagRepository = DriftTagRepository.withDatabase(database);
    await tagRepository.add(Tag(
      id: 'tag-1',
      createdDate: DateTime.now().toUtc(),
      name: 'Tag',
    ));
    final rollbackActions = McpTaskActions(
      transactions: DriftApplicationTransactionService(database),
      taskRepository: tasks,
      taskStatusRepository: DriftTaskStatusRepository.withDatabase(database),
      taskTagRepository: _FailingTaskTagRepository(database),
      taskTimeRecordRepository: DriftTaskTimeRecordRepository.withDatabase(database),
      taskEvents: _Events(),
      tagRepository: tagRepository,
      recurrenceService: recurrence,
      mediator: mediator,
    );

    await expectLater(
      rollbackActions.createTask(
        task: Task(
          id: 'rollback-task',
          createdDate: DateTime.now().toUtc(),
          title: 'Must roll back',
          statusId: TaskStatusConstants.todoId,
        ),
        tagIds: const ['tag-1'],
        beforeCommit: () async {},
      ),
      throwsStateError,
    );
    expect(await tasks.getById('rollback-task'), isNull);
  });

  test('public boundary rejects bad references/date and hides delete without scope', () async {
    final tools = buildTaskTools(
      mediator: mediator,
      actions: actions,
      authorizeBeforeCommit: (extra, scopes) async => true,
    );
    Future<CallToolResult> invoke(String name, Map<String, dynamic> arguments) async =>
        await tools.singleWhere((tool) => tool.name == name).handler(McpToolArguments(arguments), _extra());

    final badStatus = await invoke('whph_tasks_create', const {'title': 'bad', 'statusId': 'missing'});
    expect(badStatus.structuredContent?['error'], containsPair('code', 'validation_error'));
    final badTag = await invoke('whph_tasks_create', const {
      'title': 'bad',
      'tagIds': ['missing']
    });
    expect(badTag.structuredContent?['error'], containsPair('code', 'validation_error'));
    final badDate = await invoke('whph_task_time_records_update', const {
      'taskId': 'missing',
      'date': '2026-02-30',
      'totalDurationSeconds': 10,
      'expectedRevision': '2026-09-08T10:00:00Z',
    });
    expect(badDate.structuredContent?['error'], containsPair('code', 'validation_error'));

    final registry = McpToolRegistry(
      tools: tools,
      authorize: (extra, scopes) => true,
      runInvocation: (invocation) => invocation(),
    );
    expect(
      registry.discover(const {'tasks:read', 'tags:read', 'timers:read'}).map((tool) => tool.name),
      isNot(contains('whph_tasks_delete')),
    );
  });
}

final class _Events implements ITaskEvents {
  @override
  void notifyTaskCompleted(String taskId) {}
  @override
  void notifyTaskCreated(String taskId) {}
  @override
  void notifyTaskDeleted(String taskId) {}
  @override
  void notifyTaskTimeRecordUpdated(String taskId) {}
  @override
  void notifyTaskUpdated(String taskId) {}
}

final class _FailingTaskTagRepository extends DriftTaskTagRepository {
  _FailingTaskTagRepository(super.database) : super.withDatabase();

  @override
  Future<void> add(TaskTag item) => throw StateError('relationship failed');
}

final class _Recurrence implements ITaskRecurrenceService {
  int completionCalls = 0;

  @override
  bool canCreateNextInstance(Task task) => false;
  @override
  DateTime calculateNextRecurrenceDate(Task task, DateTime currentDate) => currentDate;
  @override
  List<WeekDays>? getRecurrenceDays(Task task) => null;
  @override
  Future<String?> handleCompletedRecurringTask(String taskId, Mediator mediator) async {
    completionCalls++;
    return null;
  }

  @override
  bool isRecurring(Task task) => false;
}

RequestHandlerExtra _extra() => RequestHandlerExtra(
      signal: BasicAbortController().signal,
      requestId: 'task-tool-test',
      sendNotification: (notification, {relatedTask}) async {},
      sendRequest: <T extends BaseResultData>(request, resultFactory, options) async => resultFactory(const {}),
    );
