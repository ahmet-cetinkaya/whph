import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';

import 'package:whph/core/application/features/tasks/commands/complete_task_command.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_task_notification_handler.dart';

class TaskNotificationHandler implements ITaskNotificationHandler {
  final Mediator mediator;

  TaskNotificationHandler(this.mediator);

  @override
  Future<void> handleNotificationTaskCompletion(String taskId) async {
    try {
      Logger.info('TaskNotificationHandler: Completing task from notification: $taskId');

      await mediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
        CompleteTaskCommand(id: taskId),
      );

      Logger.info('TaskNotificationHandler: Task completed successfully from notification');
    } on BusinessException catch (e, stackTrace) {
      Logger.error(
        '[$TaskErrorIds.notificationActionFailed] TaskNotificationHandler: Failed to complete task',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
