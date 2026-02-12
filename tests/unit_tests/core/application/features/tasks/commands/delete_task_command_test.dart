import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:application/features/tasks/commands/delete_task_command.dart';
import 'package:application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/tasks/task_tag.dart';
import 'package:domain/features/tasks/task_time_record.dart';
import 'package:acore/acore.dart';

import 'delete_task_command_test.mocks.dart';

@GenerateMocks([ITaskRepository, ITaskTagRepository, ITaskTimeRecordRepository])
void main() {
  late MockITaskRepository mockTaskRepository;
  late MockITaskTagRepository mockTaskTagRepository;
  late MockITaskTimeRecordRepository mockTaskTimeRecordRepository;
  late DeleteTaskCommandHandler handler;

  setUp(() {
    mockTaskRepository = MockITaskRepository();
    mockTaskTagRepository = MockITaskTagRepository();
    mockTaskTimeRecordRepository = MockITaskTimeRecordRepository();
    handler = DeleteTaskCommandHandler(
      taskRepository: mockTaskRepository,
      taskTagRepository: mockTaskTagRepository,
      taskTimeRecordRepository: mockTaskTimeRecordRepository,
    );
  });

  group('DeleteTaskCommand Tests', () {
    group('Successful Deletion', () {
      test('should delete task successfully when task exists with no related entities', () async {
        // Arrange
        const taskId = 'task-123';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Test Task',
        );
        final command = DeleteTaskCommand(id: taskId);

        when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => task);
        when(mockTaskTagRepository.getByTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.delete(task)).thenAnswer((_) async => {});

        // Act
        final result = await handler.call(command);

        // Assert
        expect(result, isA<DeleteTaskCommandResponse>());
        verify(mockTaskRepository.getById(taskId)).called(1);
        verify(mockTaskRepository.delete(task)).called(1);
        verify(mockTaskTagRepository.getByTaskId(taskId)).called(1);
        verify(mockTaskTimeRecordRepository.getByTaskId(taskId)).called(1);
        verify(mockTaskRepository.getByParentTaskId(taskId)).called(1);
        verify(mockTaskRepository.getByRecurrenceParentId(taskId)).called(1);
      });

      test('should delete task with tags successfully', () async {
        // Arrange
        const taskId = 'task-456';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Task with Tags',
        );
        final taskTags = [
          TaskTag(id: 'tag-1', createdDate: DateTime.now().toUtc(), taskId: taskId, tagId: 'tag-a'),
          TaskTag(id: 'tag-2', createdDate: DateTime.now().toUtc(), taskId: taskId, tagId: 'tag-b'),
        ];
        final command = DeleteTaskCommand(id: taskId);

        when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => task);
        when(mockTaskTagRepository.getByTaskId(taskId)).thenAnswer((_) async => taskTags);
        when(mockTaskTagRepository.delete(any)).thenAnswer((_) async => {});
        when(mockTaskTimeRecordRepository.getByTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.delete(task)).thenAnswer((_) async => {});

        // Act
        final result = await handler.call(command);

        // Assert
        expect(result, isA<DeleteTaskCommandResponse>());
        verify(mockTaskTagRepository.delete(taskTags[0])).called(1);
        verify(mockTaskTagRepository.delete(taskTags[1])).called(1);
        verify(mockTaskRepository.delete(task)).called(1);
      });

      test('should delete task with time records successfully', () async {
        // Arrange
        const taskId = 'task-789';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Task with Time Records',
        );
        final timeRecords = [
          TaskTimeRecord(id: 'record-1', createdDate: DateTime.now().toUtc(), taskId: taskId, duration: 60),
          TaskTimeRecord(id: 'record-2', createdDate: DateTime.now().toUtc(), taskId: taskId, duration: 120),
        ];
        final command = DeleteTaskCommand(id: taskId);

        when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => task);
        when(mockTaskTagRepository.getByTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(taskId)).thenAnswer((_) async => timeRecords);
        when(mockTaskTimeRecordRepository.delete(any)).thenAnswer((_) async => {});
        when(mockTaskRepository.getByParentTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.delete(task)).thenAnswer((_) async => {});

        // Act
        final result = await handler.call(command);

        // Assert
        expect(result, isA<DeleteTaskCommandResponse>());
        verify(mockTaskTimeRecordRepository.delete(timeRecords[0])).called(1);
        verify(mockTaskTimeRecordRepository.delete(timeRecords[1])).called(1);
        verify(mockTaskRepository.delete(task)).called(1);
      });

      test('should cascade delete child tasks (subtasks)', () async {
        // Arrange
        const parentTaskId = 'parent-task-001';
        const childTaskId1 = 'child-task-001';
        const childTaskId2 = 'child-task-002';

        final parentTask = Task(
          id: parentTaskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Parent Task',
        );
        final childTask1 = Task(
          id: childTaskId1,
          createdDate: DateTime.now().toUtc(),
          title: 'Child Task 1',
          parentTaskId: parentTaskId,
        );
        final childTask2 = Task(
          id: childTaskId2,
          createdDate: DateTime.now().toUtc(),
          title: 'Child Task 2',
          parentTaskId: parentTaskId,
        );
        final command = DeleteTaskCommand(id: parentTaskId);

        // Parent task setup
        when(mockTaskRepository.getById(parentTaskId)).thenAnswer((_) async => parentTask);
        when(mockTaskTagRepository.getByTaskId(parentTaskId)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(parentTaskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(parentTaskId)).thenAnswer((_) async => [childTask1, childTask2]);
        when(mockTaskRepository.getByRecurrenceParentId(parentTaskId)).thenAnswer((_) async => []);

        // Child tasks setup
        when(mockTaskTagRepository.getByTaskId(childTaskId1)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(childTaskId1)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(childTaskId1)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(childTaskId1)).thenAnswer((_) async => []);

        when(mockTaskTagRepository.getByTaskId(childTaskId2)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(childTaskId2)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(childTaskId2)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(childTaskId2)).thenAnswer((_) async => []);

        when(mockTaskRepository.delete(any)).thenAnswer((_) async => {});

        // Act
        final result = await handler.call(command);

        // Assert
        expect(result, isA<DeleteTaskCommandResponse>());
        verify(mockTaskRepository.delete(childTask1)).called(1);
        verify(mockTaskRepository.delete(childTask2)).called(1);
        verify(mockTaskRepository.delete(parentTask)).called(1);
      });

      test('should cascade delete recurring task instances', () async {
        // Arrange
        const recurrenceParentId = 'recurring-parent-001';
        const instanceId1 = 'instance-001';
        const instanceId2 = 'instance-002';

        final recurrenceParent = Task(
          id: recurrenceParentId,
          createdDate: DateTime.now().toUtc(),
          title: 'Recurring Task',
          recurrenceType: RecurrenceType.daily,
        );
        final instance1 = Task(
          id: instanceId1,
          createdDate: DateTime.now().toUtc(),
          title: 'Instance 1',
          recurrenceParentId: recurrenceParentId,
        );
        final instance2 = Task(
          id: instanceId2,
          createdDate: DateTime.now().toUtc(),
          title: 'Instance 2',
          recurrenceParentId: recurrenceParentId,
        );
        final command = DeleteTaskCommand(id: recurrenceParentId);

        // Parent task setup
        when(mockTaskRepository.getById(recurrenceParentId)).thenAnswer((_) async => recurrenceParent);
        when(mockTaskTagRepository.getByTaskId(recurrenceParentId)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(recurrenceParentId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(recurrenceParentId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(recurrenceParentId))
            .thenAnswer((_) async => [instance1, instance2]);

        // Instance setup
        when(mockTaskTagRepository.getByTaskId(instanceId1)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(instanceId1)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(instanceId1)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(instanceId1)).thenAnswer((_) async => []);

        when(mockTaskTagRepository.getByTaskId(instanceId2)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(instanceId2)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(instanceId2)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(instanceId2)).thenAnswer((_) async => []);

        when(mockTaskRepository.delete(any)).thenAnswer((_) async => {});

        // Act
        final result = await handler.call(command);

        // Assert
        expect(result, isA<DeleteTaskCommandResponse>());
        verify(mockTaskRepository.delete(instance1)).called(1);
        verify(mockTaskRepository.delete(instance2)).called(1);
        verify(mockTaskRepository.delete(recurrenceParent)).called(1);
      });

      test('should delete task with all related entities (tags, time records, subtasks, recurring instances)',
          () async {
        // Arrange
        const taskId = 'complex-task-001';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Complex Task',
          recurrenceType: RecurrenceType.weekly,
        );

        final taskTags = [
          TaskTag(id: 'tag-1', createdDate: DateTime.now().toUtc(), taskId: taskId, tagId: 'tag-a'),
        ];
        final timeRecords = [
          TaskTimeRecord(id: 'record-1', createdDate: DateTime.now().toUtc(), taskId: taskId, duration: 60),
        ];
        final childTask = Task(
          id: 'child-001',
          createdDate: DateTime.now().toUtc(),
          title: 'Child Task',
          parentTaskId: taskId,
        );
        final recurringInstance = Task(
          id: 'instance-001',
          createdDate: DateTime.now().toUtc(),
          title: 'Recurring Instance',
          recurrenceParentId: taskId,
        );

        final command = DeleteTaskCommand(id: taskId);

        // Main task setup
        when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => task);
        when(mockTaskTagRepository.getByTaskId(taskId)).thenAnswer((_) async => taskTags);
        when(mockTaskTimeRecordRepository.getByTaskId(taskId)).thenAnswer((_) async => timeRecords);
        when(mockTaskRepository.getByParentTaskId(taskId)).thenAnswer((_) async => [childTask]);
        when(mockTaskRepository.getByRecurrenceParentId(taskId)).thenAnswer((_) async => [recurringInstance]);

        // Related entities setup
        when(mockTaskTagRepository.getByTaskId('child-001')).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId('child-001')).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId('child-001')).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId('child-001')).thenAnswer((_) async => []);

        when(mockTaskTagRepository.getByTaskId('instance-001')).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId('instance-001')).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId('instance-001')).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId('instance-001')).thenAnswer((_) async => []);

        when(mockTaskTagRepository.delete(any)).thenAnswer((_) async => {});
        when(mockTaskTimeRecordRepository.delete(any)).thenAnswer((_) async => {});
        when(mockTaskRepository.delete(any)).thenAnswer((_) async => {});

        // Act
        final result = await handler.call(command);

        // Assert
        expect(result, isA<DeleteTaskCommandResponse>());
        verify(mockTaskTagRepository.delete(taskTags[0])).called(1);
        verify(mockTaskTimeRecordRepository.delete(timeRecords[0])).called(1);
        verify(mockTaskRepository.delete(childTask)).called(1);
        verify(mockTaskRepository.delete(recurringInstance)).called(1);
        verify(mockTaskRepository.delete(task)).called(1);
      });
    });

    group('Error Handling', () {
      test('should throw BusinessException when task does not exist', () async {
        // Arrange
        const taskId = 'non-existent-task';
        final command = DeleteTaskCommand(id: taskId);

        when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () async => await handler.call(command),
          throwsA(isA<BusinessException>().having(
            (e) => e.message,
            'message',
            'Task not found',
          )),
        );
        verify(mockTaskRepository.getById(taskId)).called(1);
        verifyNever(mockTaskRepository.delete(any));
      });

      test('should throw exception when task repository throws error during fetch', () async {
        // Arrange
        const taskId = 'error-task';
        final command = DeleteTaskCommand(id: taskId);

        when(mockTaskRepository.getById(taskId)).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () async => await handler.call(command),
          throwsA(isA<Exception>()),
        );
        verify(mockTaskRepository.getById(taskId)).called(1);
      });

      test('should throw exception when tag deletion fails', () async {
        // Arrange
        const taskId = 'task-tag-error';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Task with Tag Error',
        );
        final taskTag = TaskTag(
          id: 'tag-1',
          createdDate: DateTime.now().toUtc(),
          taskId: taskId,
          tagId: 'tag-a',
        );
        final command = DeleteTaskCommand(id: taskId);

        when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => task);
        when(mockTaskTagRepository.getByTaskId(taskId)).thenAnswer((_) async => [taskTag]);
        when(mockTaskTimeRecordRepository.getByTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(taskId)).thenAnswer((_) async => []);
        when(mockTaskTagRepository.delete(taskTag)).thenThrow(Exception('Tag deletion failed'));

        // Act & Assert
        await expectLater(
          () async => await handler.call(command),
          throwsA(isA<Exception>()),
        );
        verify(mockTaskTagRepository.delete(taskTag)).called(1);
        verifyNever(mockTaskRepository.delete(any));
      });

      test('should throw exception when time record deletion fails', () async {
        // Arrange
        const taskId = 'task-time-error';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Task with Time Record Error',
        );
        final timeRecord =
            TaskTimeRecord(id: 'record-1', createdDate: DateTime.now().toUtc(), taskId: taskId, duration: 60);
        final command = DeleteTaskCommand(id: taskId);

        when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => task);
        when(mockTaskTagRepository.getByTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(taskId)).thenAnswer((_) async => [timeRecord]);
        when(mockTaskRepository.getByParentTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(taskId)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.delete(timeRecord)).thenThrow(Exception('Time record deletion failed'));

        // Act & Assert
        await expectLater(
          () async => await handler.call(command),
          throwsA(isA<Exception>()),
        );
        verify(mockTaskTimeRecordRepository.delete(timeRecord)).called(1);
        verifyNever(mockTaskRepository.delete(task));
      });

      test('should throw exception when task deletion fails', () async {
        // Arrange
        const taskId = 'task-delete-error';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Task Deletion Error',
        );
        final command = DeleteTaskCommand(id: taskId);

        when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => task);
        when(mockTaskTagRepository.getByTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.delete(task)).thenThrow(Exception('Task deletion failed'));

        // Act & Assert
        await expectLater(
          () async => await handler.call(command),
          throwsA(isA<Exception>()),
        );
        verify(mockTaskRepository.delete(task)).called(1);
      });
    });

    group('Edge Cases', () {
      test('should handle task with empty string ID', () async {
        // Arrange
        const taskId = '';
        final command = DeleteTaskCommand(id: taskId);

        when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () async => await handler.call(command),
          throwsA(isA<BusinessException>()),
        );
      });

      test('should handle deeply nested subtasks', () async {
        // Arrange
        const level1Id = 'level1';
        const level2Id = 'level2';
        const level3Id = 'level3';

        final level1Task = Task(
          id: level1Id,
          createdDate: DateTime.now().toUtc(),
          title: 'Level 1',
        );
        final level2Task = Task(
          id: level2Id,
          createdDate: DateTime.now().toUtc(),
          title: 'Level 2',
          parentTaskId: level1Id,
        );
        final level3Task = Task(
          id: level3Id,
          createdDate: DateTime.now().toUtc(),
          title: 'Level 3',
          parentTaskId: level2Id,
        );

        final command = DeleteTaskCommand(id: level1Id);

        // Level 1 setup
        when(mockTaskRepository.getById(level1Id)).thenAnswer((_) async => level1Task);
        when(mockTaskTagRepository.getByTaskId(level1Id)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(level1Id)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(level1Id)).thenAnswer((_) async => [level2Task]);
        when(mockTaskRepository.getByRecurrenceParentId(level1Id)).thenAnswer((_) async => []);

        // Level 2 setup
        when(mockTaskTagRepository.getByTaskId(level2Id)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(level2Id)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(level2Id)).thenAnswer((_) async => [level3Task]);
        when(mockTaskRepository.getByRecurrenceParentId(level2Id)).thenAnswer((_) async => []);

        // Level 3 setup
        when(mockTaskTagRepository.getByTaskId(level3Id)).thenAnswer((_) async => []);
        when(mockTaskTimeRecordRepository.getByTaskId(level3Id)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(level3Id)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(level3Id)).thenAnswer((_) async => []);

        when(mockTaskRepository.delete(any)).thenAnswer((_) async => {});

        // Act
        final result = await handler.call(command);

        // Assert
        expect(result, isA<DeleteTaskCommandResponse>());
        verify(mockTaskRepository.delete(level3Task)).called(1);
        verify(mockTaskRepository.delete(level2Task)).called(1);
        verify(mockTaskRepository.delete(level1Task)).called(1);
      });

      test('should handle task with large number of tags', () async {
        // Arrange
        const taskId = 'many-tags-task';
        final task = Task(
          id: taskId,
          createdDate: DateTime.now().toUtc(),
          title: 'Task with Many Tags',
        );
        final taskTags = List.generate(
          100,
          (i) => TaskTag(
            id: 'tag-$i',
            createdDate: DateTime.now().toUtc(),
            taskId: taskId,
            tagId: 'tag-id-$i',
          ),
        );
        final command = DeleteTaskCommand(id: taskId);

        when(mockTaskRepository.getById(taskId)).thenAnswer((_) async => task);
        when(mockTaskTagRepository.getByTaskId(taskId)).thenAnswer((_) async => taskTags);
        when(mockTaskTagRepository.delete(any)).thenAnswer((_) async => {});
        when(mockTaskTimeRecordRepository.getByTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByParentTaskId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.getByRecurrenceParentId(taskId)).thenAnswer((_) async => []);
        when(mockTaskRepository.delete(task)).thenAnswer((_) async => {});

        // Act
        final result = await handler.call(command);

        // Assert
        expect(result, isA<DeleteTaskCommandResponse>());
        verify(mockTaskTagRepository.delete(any)).called(100);
        verify(mockTaskRepository.delete(task)).called(1);
      });
    });
  });
}
