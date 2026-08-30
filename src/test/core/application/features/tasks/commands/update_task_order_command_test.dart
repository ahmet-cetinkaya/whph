import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/tasks/commands/update_task_order_command.dart';
import 'package:whph/core/domain/features/tasks/task.dart';

import 'save_task_command_test.mocks.dart';

void main() {
  late MockITaskRepository taskRepository;
  late UpdateTaskOrderCommandHandler handler;

  setUp(() {
    taskRepository = MockITaskRepository();
    handler = UpdateTaskOrderCommandHandler(taskRepository);
  });

  test('places a filtered task after its authoritative visible neighbor across a page boundary', () async {
    final tasks = [
      _task('A', 'A'),
      _task('B', 'C'),
      _task('C', 'E'),
      _task('D', 'G'),
      _task('E', 'I'),
    ];
    final moved = tasks[1];
    final visibleTasks = [tasks[1], tasks[3], tasks[4]];

    when(taskRepository.getById(moved.id)).thenAnswer((_) async => moved);
    when(taskRepository.getAll(
      customWhereFilter: anyNamed('customWhereFilter'),
      customOrder: anyNamed('customOrder'),
    )).thenAnswer((_) async => tasks.where((task) => task.id != moved.id).toList());
    when(taskRepository.update(moved)).thenAnswer((_) async {});

    final response = await handler(UpdateTaskOrderCommand(
      taskId: moved.id,
      targetIndex: visibleTasks.indexOf(tasks[3]) + 1,
      beforeTaskId: tasks[3].id,
    ));

    expect(response.order.compareTo(tasks[3].order), greaterThan(0));
    expect(response.order.compareTo(tasks[4].order), lessThan(0));
    final capturedOrders = verify(taskRepository.getAll(
      customWhereFilter: anyNamed('customWhereFilter'),
      customOrder: captureAnyNamed('customOrder'),
    )).captured.single as List<CustomOrder>;
    expect(capturedOrders.map((order) => order.field), ['order', 'created_date', 'id']);
    verify(taskRepository.update(moved)).called(1);
  });

  test('scopes siblings to the moved task\'s own parent, not any caller-supplied value', () async {
    // A flat "show sub-tasks" list can display a subtask (parent: root-a)
    // alongside root tasks (parent: null) in the same visual list. The
    // command carries no parent hint, so the handler must derive scope from
    // the persisted task rather than assume the moved task is a root task.
    final subtask = _task('sub-1', '1', parentTaskId: 'root-a');
    final trueSibling = _task('sub-2', '2', parentTaskId: 'root-a');
    final unrelatedRoot = _task('root-b', 'A');

    when(taskRepository.getById(subtask.id)).thenAnswer((_) async => subtask);
    when(taskRepository.update(subtask)).thenAnswer((_) async {});

    late CustomWhereFilter capturedFilter;
    when(taskRepository.getAll(
      customWhereFilter: anyNamed('customWhereFilter'),
      customOrder: anyNamed('customOrder'),
    )).thenAnswer((invocation) async {
      capturedFilter = invocation.namedArguments[#customWhereFilter] as CustomWhereFilter;
      // Return only the subtask's true sibling — proves the handler queried
      // the subtask's own parent scope, not a root/global scope that would
      // also need to return unrelatedRoot.
      return [trueSibling];
    });

    await handler(UpdateTaskOrderCommand(
      taskId: subtask.id,
      targetIndex: 1,
      afterTaskId: unrelatedRoot.id, // a stale/unrelated hint from a flat list
    ));

    expect(capturedFilter.query, contains('parent_task_id = ?'));
    expect(capturedFilter.variables, contains('root-a'));
  });
}

Task _task(String id, String order, {String? parentTaskId}) => Task(
      id: id,
      createdDate: DateTime.utc(2026),
      title: id,
      order: order,
      parentTaskId: parentTaskId,
    );
