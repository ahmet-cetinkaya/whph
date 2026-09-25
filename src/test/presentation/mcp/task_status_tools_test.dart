import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/application/features/tasks/services/mcp_task_actions.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_status.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_status_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/services/drift_application_transaction_service.dart';
import 'package:whph/presentation/mcp/tools/task_status_tools.dart';

void main() {
  late AppDatabase database;
  late DriftTaskStatusRepository statuses;
  late McpTaskActions actions;

  setUp(() {
    database = AppDatabase.forTesting();
    AppDatabase.setInstanceForTesting(database);
    statuses = DriftTaskStatusRepository.withDatabase(database);
    actions = McpTaskActions(
      transactions: DriftApplicationTransactionService(database),
      taskRepository: DriftTaskRepository.withDatabase(database),
      taskStatusRepository: statuses,
      taskTagRepository: DriftTaskTagRepository.withDatabase(database),
      taskTimeRecordRepository: DriftTaskTimeRecordRepository.withDatabase(database),
      tagRepository: DriftTagRepository.withDatabase(database),
      taskEvents: _Events(),
      recurrenceService: _Recurrence(),
      mediator: Mediator(Pipeline()),
    );
  });

  tearDown(() async {
    await database.close();
    AppDatabase.resetInstance();
  });

  test('catalog exposes every canonical status tool with closed schemas', () {
    final tools = buildTaskStatusTools(
      mediator: Mediator(Pipeline()),
      actions: actions,
      authorizeBeforeCommit: (extra, scopes) async => true,
    );
    expect(tools.map((tool) => tool.name), [
      'whph_task_statuses_list',
      'whph_task_statuses_read',
      'whph_task_statuses_create',
      'whph_task_statuses_update',
      'whph_task_statuses_delete',
      'whph_task_statuses_reorder',
    ]);
    expect(tools.every((tool) => tool.inputSchema.additionalProperties == false), isTrue);
    expect(tools.every((tool) => tool.outputSchema.additionalProperties == false), isTrue);
  });

  test('status update is CAS and preserves omitted color', () async {
    await statuses.add(TaskStatus(
      id: 'status-1',
      createdDate: DateTime.now().toUtc(),
      name: 'Waiting',
      color: '112233',
    ));
    final stored = (await statuses.getById('status-1'))!;
    final revision = stored.modifiedDate ?? stored.createdDate;
    final repositoryInput = TaskStatus(
      id: stored.id,
      createdDate: stored.createdDate,
      modifiedDate: stored.modifiedDate,
      name: 'Repository CAS',
      color: stored.color,
      order: stored.order,
    );
    final committedRevision = await statuses.updateIfRevision(repositoryInput, revision);
    expect(committedRevision, isNotNull);
    expect(repositoryInput.modifiedDate, stored.modifiedDate);

    final updated = await actions.updateStatus(
      id: stored.id,
      expectedRevision: committedRevision!,
      patch: const McpTaskPatch({'name': 'Blocked'}),
      beforeCommit: () async {},
    );
    expect(updated.name, 'Blocked');
    expect(updated.color, '112233');
    await expectLater(
      actions.updateStatus(
        id: stored.id,
        expectedRevision: committedRevision,
        patch: const McpTaskPatch({'name': 'Stale'}),
        beforeCommit: () async {},
      ),
      throwsA(isA<McpRevisionConflictException>()),
    );
  });

  test('virtual built-in update uses stable revision and protected status cannot be deleted', () async {
    final updated = await actions.updateStatus(
      id: TaskStatusConstants.todoId,
      expectedRevision: McpTaskActions.virtualStatusRevision,
      patch: const McpTaskPatch({'name': 'Ready'}),
      beforeCommit: () async {},
    );
    expect(updated.name, 'Ready');
    expect(await statuses.existsInDb(TaskStatusConstants.todoId), isTrue);
    final persisted = (await statuses.getById(updated.id))!;
    expect(updated.createdDate, persisted.createdDate);
    await expectLater(
      actions.deleteStatus(
        id: updated.id,
        expectedRevision: persisted.modifiedDate ?? persisted.createdDate,
        beforeCommit: () async {},
      ),
      throwsArgumentError,
    );
    expect(await statuses.getById(updated.id), isNotNull);
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

final class _Recurrence implements ITaskRecurrenceService {
  @override
  bool canCreateNextInstance(Task task) => false;
  @override
  DateTime calculateNextRecurrenceDate(Task task, DateTime currentDate) => currentDate;
  @override
  List<WeekDays>? getRecurrenceDays(Task task) => null;
  @override
  Future<String?> handleCompletedRecurringTask(String taskId, Mediator mediator) async => null;
  @override
  bool isRecurring(Task task) => false;
}
