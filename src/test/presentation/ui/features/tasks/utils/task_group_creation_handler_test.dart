import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_group_creation_handler.dart';
import 'package:whph/main.dart' as app_main;
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/core/domain/features/tasks/task_status_constants.dart';

void main() {
  group('TaskGroupCreationHandler.draftForGroup', () {
    const baseInput = TaskGroupCreationInput(
      groupKey: '',
      groupField: null,
      searchQuery: 'searched title',
    );

    test('priority group maps to Eisenhower priority', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: TaskTranslationKeys.priorityUrgentImportant,
        groupField: TaskSortFields.priority,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.priority, EisenhowerPriority.urgentImportant);
      expect(draft.title, 'searched title');
    });

    test('priority group falls through to null priority on unknown key', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: 'bogus',
        groupField: TaskSortFields.priority,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.priority, isNull);
    });

    test('planned date group maps to plannedDate', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: SharedTranslationKeys.today,
        groupField: TaskSortFields.plannedDate,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.plannedDate, isNotNull);
    });

    test('planned date group returns null on unrecognized key', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: 'mystery-bucket',
        groupField: TaskSortFields.plannedDate,
        input: baseInput,
      );
      expect(draft, isNull);
    });

    test('deadline date group maps to deadlineDate', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: SharedTranslationKeys.tomorrow,
        groupField: TaskSortFields.deadlineDate,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.deadlineDate, isNotNull);
    });

    test('deadline date group returns null on unrecognized key', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: 'who-knows',
        groupField: TaskSortFields.deadlineDate,
        input: baseInput,
      );
      expect(draft, isNull);
    });

    test('completedDate group maps completed flag', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: SharedTranslationKeys.today,
        groupField: TaskSortFields.completedDate,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.completed, isNotNull);
    });

    test('estimatedTime group maps minutes', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: SharedTranslationKeys.durationLessThan15Min,
        groupField: TaskSortFields.estimatedTime,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.estimatedTime, isNotNull);
    });

    test('estimatedTime group returns null on unrecognized key', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: 'eternity',
        groupField: TaskSortFields.estimatedTime,
        input: baseInput,
      );
      expect(draft, isNull);
    });

    test('tag "None" group yields an empty-tags draft', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: SharedTranslationKeys.none,
        groupField: TaskSortFields.tag,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.tagIds, isEmpty);
    });

    test('tag named group returns null (caller must use async path)', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: 'Inbox',
        groupField: TaskSortFields.tag,
        input: baseInput,
      );
      expect(draft, isNull);
    });

    test('showNoTagsFilter forces empty tagIds for non-tag groups', () {
      const input = TaskGroupCreationInput(
        groupKey: TaskTranslationKeys.priorityUrgentImportant,
        groupField: TaskSortFields.priority,
        searchQuery: null,
        defaultTagIds: ['fallback'],
        showNoTagsFilter: true,
      );
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: TaskTranslationKeys.priorityUrgentImportant,
        groupField: TaskSortFields.priority,
        input: input,
      );
      expect(draft, isNotNull);
      expect(draft!.tagIds, isEmpty);
    });

    test('parentTaskId is propagated', () {
      const input = TaskGroupCreationInput(
        groupKey: TaskTranslationKeys.priorityUrgentImportant,
        groupField: TaskSortFields.priority,
        parentTaskId: 'parent-7',
      );
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: TaskTranslationKeys.priorityUrgentImportant,
        groupField: TaskSortFields.priority,
        input: input,
      );
      expect(draft, isNotNull);
      expect(draft!.parentTaskId, 'parent-7');
    });

    test('status group returns null (caller must use async path)', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: 'In Progress',
        groupField: TaskSortFields.status,
        input: baseInput,
      );
      expect(draft, isNull);
    });

    test('title/created/modified groups are unsupported and return null', () {
      for (final field in [
        TaskSortFields.title,
        TaskSortFields.createdDate,
        TaskSortFields.modifiedDate,
        TaskSortFields.totalDuration,
      ]) {
        final draft = TaskGroupCreationHandler.draftForGroup(
          groupKey: 'anything',
          groupField: field,
          input: baseInput,
        );
        expect(draft, isNull, reason: 'field=$field should yield null draft');
      }
    });
  });

  group('TaskGroupCreationHandler.resolveStatusIdByKey', () {
    late FakeContainer fakeContainer;
    late FakeMediator fakeMediator;

    setUp(() {
      fakeContainer = FakeContainer();
      fakeMediator = FakeMediator();
      fakeContainer.register<Mediator>(fakeMediator);
      app_main.container = fakeContainer;
    });

    test('resolves built-in todo status ID', () async {
      fakeMediator.statusesResponse = GetListTaskStatusesQueryResponse(
        items: [
          TaskStatusListItem(id: TaskStatusConstants.todoId, name: '', order: 1, isBuiltIn: true, isDoneStatus: false),
          TaskStatusListItem(id: TaskStatusConstants.doneId, name: '', order: 2, isBuiltIn: true, isDoneStatus: true),
        ],
        totalItemCount: 2,
        pageIndex: 0,
        pageSize: 100,
      );

      final statusId = await TaskGroupCreationHandler.resolveStatusIdByKey(TaskTranslationKeys.statusBuiltInTodo);
      expect(statusId, TaskStatusConstants.todoId);
    });

    test('resolves built-in done status ID', () async {
      fakeMediator.statusesResponse = GetListTaskStatusesQueryResponse(
        items: [
          TaskStatusListItem(id: TaskStatusConstants.todoId, name: '', order: 1, isBuiltIn: true, isDoneStatus: false),
          TaskStatusListItem(id: TaskStatusConstants.doneId, name: '', order: 2, isBuiltIn: true, isDoneStatus: true),
        ],
        totalItemCount: 2,
        pageIndex: 0,
        pageSize: 100,
      );

      final statusId = await TaskGroupCreationHandler.resolveStatusIdByKey(TaskTranslationKeys.statusBuiltInDone);
      expect(statusId, TaskStatusConstants.doneId);
    });

    test('resolves custom status ID by name', () async {
      fakeMediator.statusesResponse = GetListTaskStatusesQueryResponse(
        items: [
          TaskStatusListItem(
              id: 'in-progress-uuid', name: 'In Progress', order: 1.5, isBuiltIn: false, isDoneStatus: false),
        ],
        totalItemCount: 1,
        pageIndex: 0,
        pageSize: 100,
      );

      final statusId = await TaskGroupCreationHandler.resolveStatusIdByKey('In Progress');
      expect(statusId, 'in-progress-uuid');
    });

    test('returns null for unresolved keys', () async {
      fakeMediator.statusesResponse = GetListTaskStatusesQueryResponse(
        items: [],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 100,
      );

      final statusId = await TaskGroupCreationHandler.resolveStatusIdByKey('In Progress');
      expect(statusId, isNull);
    });
  });
}

class FakeMediator extends Fake implements Mediator {
  GetListTaskStatusesQueryResponse? statusesResponse;

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse>(
    TRequest request,
  ) async {
    if (request is GetListTaskStatusesQuery) {
      return statusesResponse as TResponse;
    }
    throw UnimplementedError();
  }
}

class FakeContainer extends Fake implements IContainer {
  final Map<Type, dynamic> _registrations = {};

  void register<T>(dynamic instance) {
    _registrations[T] = instance;
  }

  @override
  T resolve<T>([String? name]) {
    if (_registrations.containsKey(T)) {
      return _registrations[T] as T;
    }
    throw Exception('Service setup missing for type $T');
  }
}
