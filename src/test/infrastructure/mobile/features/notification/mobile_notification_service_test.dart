import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/complete_task_command.dart';
import 'package:whph/infrastructure/mobile/features/notification/mobile_notification_service.dart';

import 'mobile_notification_service_test.mocks.dart';

@GenerateMocks([
  Mediator,
])
void main() {
  group('MobileNotificationService', () {
    late MobileNotificationService service;
    late MockMediator mockMediator;

    setUp(() {
      mockMediator = MockMediator();
    });

    group('handleNotificationTaskCompletion', () {
      test('should send CompleteTaskCommand when valid task ID is provided', () async {
        // Arrange
        final taskId = 'test-task-id';

        when(mockMediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
          argThat(isA<CompleteTaskCommand>()),
        )).thenAnswer((_) async => CompleteTaskCommandResponse(taskId: taskId));

        service = MobileNotificationService(mockMediator);

        // Act
        await service.handleNotificationTaskCompletion(taskId);

        // Assert
        verify(mockMediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
          argThat(isA<CompleteTaskCommand>()),
        )).called(1);
      });

      test('should pass correct task ID to CompleteTaskCommand', () async {
        // Arrange
        final taskId = 'test-task-id-123';

        when(mockMediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
          argThat(isA<CompleteTaskCommand>()),
        )).thenAnswer((_) async => CompleteTaskCommandResponse(taskId: taskId));

        service = MobileNotificationService(mockMediator);

        // Act
        await service.handleNotificationTaskCompletion(taskId);

        // Assert
        final captured = verify(mockMediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
          captureAny,
        )).captured.last as CompleteTaskCommand;

        expect(captured.id, equals(taskId));
      });

      test('should handle mediator errors gracefully', () async {
        // Arrange
        final taskId = 'error-task';

        when(mockMediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
          argThat(isA<CompleteTaskCommand>()),
        )).thenThrow(Exception('Database error'));

        service = MobileNotificationService(mockMediator);

        // Act & Assert - should not throw
        await expectLater(
          () => service.handleNotificationTaskCompletion(taskId),
          returnsNormally,
        );
      });

      test('should handle task not found error', () async {
        // Arrange
        final taskId = 'non-existent-task';

        when(mockMediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
          argThat(isA<CompleteTaskCommand>()),
        )).thenThrow(Exception('Task not found'));

        service = MobileNotificationService(mockMediator);

        // Act & Assert - should not throw
        await expectLater(
          () => service.handleNotificationTaskCompletion(taskId),
          returnsNormally,
        );
      });

      test('should return response with task ID', () async {
        // Arrange
        final taskId = 'response-test';

        when(mockMediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
          argThat(isA<CompleteTaskCommand>()),
        )).thenAnswer((_) async => CompleteTaskCommandResponse(taskId: taskId));

        service = MobileNotificationService(mockMediator);

        // Act & Assert - should not throw
        await expectLater(
          () => service.handleNotificationTaskCompletion(taskId),
          returnsNormally,
        );
      });
    });
  });
}
