import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';

import 'package:whph/core/application/features/habits/commands/complete_habit_command.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_habit_notification_handler.dart';

class HabitNotificationHandler implements IHabitNotificationHandler {
  final Mediator mediator;

  @override
  void Function(String habitId)? onHabitCompleted;

  HabitNotificationHandler(this.mediator);

  @override
  Future<void> handleNotificationHabitCompletion(String habitId) async {
    try {
      Logger.info('HabitNotificationHandler: Completing habit from notification: $habitId');

      await mediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
        CompleteHabitCommand(
          habitId: habitId,
          date: DateTime.now(),
        ),
      );

      Logger.info('HabitNotificationHandler: Habit completed successfully from notification');
      onHabitCompleted?.call(habitId);
    } on BusinessException catch (e, stackTrace) {
      Logger.error(
        '[$TaskErrorIds.notificationActionFailed] HabitNotificationHandler: Failed to complete habit',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
