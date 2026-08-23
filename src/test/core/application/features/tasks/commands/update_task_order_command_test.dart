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
    verify(taskRepository.update(moved)).called(1);
  });
}

Task _task(String id, String order) => Task(
      id: id,
      createdDate: DateTime.utc(2026),
      title: id,
      order: order,
    );
