import 'package:mediatr/mediatr.dart';

import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
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
    } catch (e, stackTrace) {
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

      await mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(
        ToggleHabitCompletionCommand(
          habitId: habitId,
          date: DateTime.now(),
        ),
      );

      Logger.info('$componentName: Habit completed successfully from notification', component: componentName);
    } catch (e, stackTrace) {
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
    try {
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
    } catch (e, stackTrace) {
      Logger.error(
        '[notification_check_failed] $componentName: Failed to check if notifications are enabled, defaulting to disabled',
        error: e,
        stackTrace: stackTrace,
        component: componentName,
      );
      return false; // Default to FALSE on error - safer to disable than to silently fail
    }
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
