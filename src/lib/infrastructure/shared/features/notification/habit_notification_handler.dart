import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';

import 'package:whph/core/application/features/habits/commands/complete_habit_command.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_habit_notification_handler.dart';

class HabitNotificationHandler implements IHabitNotificationHandler {
  final Mediator mediator;

  @override
  void Function(String habitId)? onHabitActionHandled;

  HabitNotificationHandler(this.mediator);

  @override
  Future<void> handleNotificationHabitAction(String habitId) async {
    try {
      Logger.info('HabitNotificationHandler: Handling notification action for habit: $habitId');

      await mediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
        CompleteHabitCommand(
          habitId: habitId,
          date: DateTime.now(),
        ),
      );

      Logger.info('HabitNotificationHandler: Habit notification action handled successfully: $habitId');
      onHabitActionHandled?.call(habitId);
    } on BusinessException catch (e, stackTrace) {
      Logger.error(
        '[${TaskErrorIds.notificationActionFailed}] HabitNotificationHandler: Failed notification action for habit: $habitId',
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      // This is the outermost frame of a fire-and-forget notification callback,
      // so an infrastructure failure would otherwise be diagnosable from nothing.
      Logger.error(
        '[${TaskErrorIds.notificationActionFailed}] HabitNotificationHandler: Unexpected failure for habit: $habitId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
