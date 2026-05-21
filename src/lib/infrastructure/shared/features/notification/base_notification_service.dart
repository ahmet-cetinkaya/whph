import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';

import 'package:whph/core/application/features/habits/commands/complete_habit_command.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/features/tasks/commands/complete_task_command.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';

abstract class BaseNotificationService implements INotificationService {
  final Mediator mediator;

  /// The component name to use for logging
  String get componentName;

  BaseNotificationService(this.mediator);

  @override
  Future<void> handleNotificationTaskCompletion(String taskId) async {
    try {
      Logger.info('$componentName: Completing task from notification: $taskId', component: componentName);

      await mediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
        CompleteTaskCommand(id: taskId),
      );

      Logger.info('$componentName: Task completed successfully from notification', component: componentName);
    } on BusinessException catch (e, stackTrace) {
      Logger.error(
        '[$TaskErrorIds.notificationActionFailed] $componentName: Failed to complete task',
        error: e,
        stackTrace: stackTrace,
        component: componentName,
      );
    }
  }

  @override
  Future<void> handleNotificationHabitCompletion(String habitId) async {
    try {
      Logger.info('$componentName: Completing habit from notification: $habitId', component: componentName);

      await mediator.send<CompleteHabitCommand, CompleteHabitCommandResponse>(
        CompleteHabitCommand(
          habitId: habitId,
          date: DateTime.now(),
        ),
      );

      Logger.info('$componentName: Habit completed successfully from notification', component: componentName);
    } on BusinessException catch (e, stackTrace) {
      Logger.error(
        '[$TaskErrorIds.notificationActionFailed] $componentName: Failed to complete habit',
        error: e,
        stackTrace: stackTrace,
        component: componentName,
      );
    }
  }

  @override
  Future<void> destroy() async {
    await clearAll();
  }

  @override
  Future<bool> isEnabled() async {
    final query = GetSettingQuery(key: SettingKeys.notifications);
    final setting = await mediator.send<GetSettingQuery, GetSettingQueryResponse?>(query);

    if (setting == null) {
      Logger.warning(
        '$componentName: Notification setting not found, defaulting to enabled',
        component: componentName,
      );
      return true; // Default to true if no setting
    }

    final isEnabled = setting.value == 'false' ? false : true;
    return isEnabled;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final command = SaveSettingCommand(
      key: SettingKeys.notifications,
      value: enabled.toString(),
      valueType: SettingValueType.bool,
    );

    await mediator.send(command);
  }
}
