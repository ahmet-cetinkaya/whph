import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:application/features/tasks/commands/remove_task_tag_command.dart';
import 'package:application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:domain/features/tasks/task_tag.dart';
import 'package:acore/acore.dart';

import 'remove_task_tag_command_test.mocks.dart';

@GenerateMocks([ITaskTagRepository])
void main() {
  late RemoveTaskTagCommandHandler handler;
  late MockITaskTagRepository mockTaskTagRepository;

  setUp(() {
    mockTaskTagRepository = MockITaskTagRepository();
    handler = RemoveTaskTagCommandHandler(taskTagRepository: mockTaskTagRepository);
  });

  group('RemoveTaskTagCommandHandler Tests', () {
    // Test successful removal of task tag
    test('should remove task tag when tag exists and is not deleted', () async {
      // Arrange
      const taskTagId = 'task-tag-1';
      final existingTaskTag = TaskTag(
        id: taskTagId,
        createdDate: DateTime.now().toUtc(),
        taskId: 'task-1',
        tagId: 'tag-1',
        deletedDate: null,
      );

      final command = RemoveTaskTagCommand(id: taskTagId);

      when(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).thenAnswer((_) async => existingTaskTag);

      when(mockTaskTagRepository.delete(existingTaskTag)).thenAnswer((_) async => Future.value());

      // Act
      final result = await handler(command);

      // Assert
      expect(result.id, taskTagId);
      verify(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).called(1);
      verify(mockTaskTagRepository.delete(existingTaskTag)).called(1);
    });

    // Test handling of non-existent task tag
    test('should throw BusinessException when task tag does not exist', () async {
      // Arrange
      const taskTagId = 'task-tag-1';
      final command = RemoveTaskTagCommand(id: taskTagId);

      when(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => handler(command),
        throwsA(
          predicate((e) => e is BusinessException && e.message == 'Task tag not found'),
        ),
      );
      verify(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).called(1);
      verifyNever(mockTaskTagRepository.delete(any));
    });

    // Test handling of already deleted task tag
    test('should throw BusinessException when task tag is already deleted', () async {
      // Arrange
      const taskTagId = 'task-tag-1';
      final existingTaskTag = TaskTag(
        id: taskTagId,
        createdDate: DateTime.now().toUtc(),
        taskId: 'task-1',
        tagId: 'tag-1',
        deletedDate: DateTime.now().toUtc(), // Marked as deleted
      );

      final command = RemoveTaskTagCommand(id: taskTagId);

      when(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).thenAnswer((_) async => existingTaskTag);

      // Act & Assert
      expect(
        () => handler(command),
        throwsA(
          predicate((e) => e is BusinessException && e.message == 'Task tag already deleted'),
        ),
      );
      verify(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).called(1);
      verifyNever(mockTaskTagRepository.delete(any));
    });

    // Test error handling when repository throws an exception during getById
    test('should propagate repository exceptions from getById', () async {
      // Arrange
      const taskTagId = 'task-tag-1';
      final command = RemoveTaskTagCommand(id: taskTagId);

      when(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).thenThrow(Exception('Database error'));

      // Act & Assert
      expect(
        () => handler(command),
        throwsException,
      );
      verify(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).called(1);
      verifyNever(mockTaskTagRepository.delete(any));
    });

    // Test error handling when repository throws an exception during delete
    test('should propagate repository exceptions from delete', () async {
      // Arrange
      const taskTagId = 'task-tag-1';
      final existingTaskTag = TaskTag(
        id: taskTagId,
        createdDate: DateTime.now().toUtc(),
        taskId: 'task-1',
        tagId: 'tag-1',
        deletedDate: null,
      );

      final command = RemoveTaskTagCommand(id: taskTagId);

      when(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).thenAnswer((_) async => existingTaskTag);

      when(mockTaskTagRepository.delete(existingTaskTag)).thenThrow(Exception('Database error'));

      // Act & Assert
      await expectLater(
        () => handler(command),
        throwsException,
      );
      verify(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).called(1);
      verify(mockTaskTagRepository.delete(existingTaskTag)).called(1);
    });

    // Test with different ID formats
    test('should handle different ID formats correctly', () async {
      // Arrange
      const taskTagId = 'uuid-like-id-12345';
      final existingTaskTag = TaskTag(
        id: taskTagId,
        createdDate: DateTime.now().toUtc(),
        taskId: 'task-1',
        tagId: 'tag-1',
        deletedDate: null,
      );

      final command = RemoveTaskTagCommand(id: taskTagId);

      when(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).thenAnswer((_) async => existingTaskTag);

      when(mockTaskTagRepository.delete(existingTaskTag)).thenAnswer((_) async => Future.value());

      // Act
      final result = await handler(command);

      // Assert
      expect(result.id, taskTagId);
      verify(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).called(1);
      verify(mockTaskTagRepository.delete(existingTaskTag)).called(1);
    });

    // Test interaction verification
    test('should correctly interact with repository methods', () async {
      // Arrange
      const taskTagId = 'task-tag-1';
      final existingTaskTag = TaskTag(
        id: taskTagId,
        createdDate: DateTime.now().toUtc(),
        taskId: 'task-1',
        tagId: 'tag-1',
        deletedDate: null,
      );

      final command = RemoveTaskTagCommand(id: taskTagId);

      when(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).thenAnswer((_) async => existingTaskTag);

      when(mockTaskTagRepository.delete(existingTaskTag)).thenAnswer((_) async => Future.value());

      // Act
      final result = await handler(command);

      // Assert
      // Verify that the repository methods were called with correct parameters
      verify(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).called(1);
      verify(mockTaskTagRepository.delete(existingTaskTag)).called(1);

      // Verify that the result has the expected ID
      expect(result.id, taskTagId);
    });

    // Test with empty string ID (edge case)
    test('should handle empty string ID correctly', () async {
      // Arrange
      const taskTagId = '';
      final command = RemoveTaskTagCommand(id: taskTagId);

      when(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => handler(command),
        throwsA(
          predicate((e) => e is BusinessException && e.message == 'Task tag not found'),
        ),
      );
      verify(mockTaskTagRepository.getById(taskTagId, includeDeleted: false)).called(1);
      verifyNever(mockTaskTagRepository.delete(any));
    });
  });
}
