import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' show PlatformUtils, DateTimeHelper;
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart' as shared;
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/main.dart' show container;
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

class MobileNotificationService implements INotificationService {
  final Mediator _mediator;
  final FlutterLocalNotificationsPlugin _flutterLocalNotifications;
  final ITaskRecurrenceService _recurrenceService;
  final TasksService _tasksService;

  MobileNotificationService(this._mediator, [ITaskRecurrenceService? recurrenceService, TasksService? tasksService])
      : _flutterLocalNotifications = FlutterLocalNotificationsPlugin(),
        _recurrenceService = recurrenceService ?? container.resolve<ITaskRecurrenceService>(),
        _tasksService = tasksService ?? container.resolve<TasksService>();

  @override
  Future<void> init() async {
    await _flutterLocalNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  @override
  Future<void> handleNotificationTaskCompletion(String taskId) async {
    try {
      Logger.info('MobileNotificationService: Completing task from notification: $taskId');

      // Get current task details
      final task = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
        GetTaskQuery(id: taskId),
      );

      // Mark as completed - following the same pattern as TaskCompleteButton
      final command = SaveTaskCommand(
        id: task.id,
        title: task.title,
        description: task.description,
        priority: task.priority,
        plannedDate: task.plannedDate != null ? DateTimeHelper.toUtcDateTime(task.plannedDate!) : null,
        deadlineDate: task.deadlineDate != null ? DateTimeHelper.toUtcDateTime(task.deadlineDate!) : null,
        estimatedTime: task.estimatedTime,
        completedAt: DateTime.now().toUtc(),
        plannedDateReminderTime: task.plannedDateReminderTime,
        deadlineDateReminderTime: task.deadlineDateReminderTime,
        recurrenceType: task.recurrenceType,
        recurrenceInterval: task.recurrenceInterval,
        recurrenceDays: _recurrenceService.getRecurrenceDays(task),
        recurrenceStartDate: task.recurrenceStartDate,
        recurrenceEndDate: task.recurrenceEndDate,
        recurrenceCount: task.recurrenceCount,
      );

      await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

      // Notify listeners that the task was completed (triggers UI refresh)
      _tasksService.notifyTaskCompleted(taskId);

      Logger.info('MobileNotificationService: Task completed successfully from notification');
    } catch (e, stackTrace) {
      Logger.error(
        'MobileNotificationService: Failed to complete task from notification',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    if (!await isEnabled()) return;

    final bool? permissionGranted = await _checkPermission();
    if (permissionGranted != true) return;

    await _flutterLocalNotifications.show(
      id ?? shared.KeyHelper.generateNumericId(),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppInfo.name,
          AppInfo.name,
          importance: Importance.max,
          priority: Priority.high,
          channelShowBadge: true,
          enableLights: true,
          enableVibration: true,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<bool?> _checkPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      return await androidImplementation?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      return await _flutterLocalNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    return false;
  }

  @override
  Future<void> clearAll() async {
    await _flutterLocalNotifications.cancelAll();
  }

  @override
  Future<void> destroy() async {
    await clearAll();
  }

  @override
  Future<bool> isEnabled() async {
    try {
      final query = GetSettingQuery(key: SettingKeys.notifications);
      final setting = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(query);
      return setting.value == 'false' ? false : true; // Default to true if no setting
    } catch (e) {
      return true; // Default to true if setting not found
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _checkPermission();
    }

    final command = SaveSettingCommand(
      key: SettingKeys.notifications,
      value: enabled.toString(),
      valueType: SettingValueType.bool,
    );

    await _mediator.send(command);
  }

  @override
  Future<bool> checkPermissionStatus() async {
    if (!PlatformUtils.isMobile) {
      return true; // Always return true for non-mobile platforms
    }

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final areNotificationsEnabled = await androidImplementation?.areNotificationsEnabled();
      return areNotificationsEnabled ?? false;
    }

    return false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!PlatformUtils.isMobile && !Platform.isIOS) {
      return true; // Non-mobile platforms don't need explicit permission
    }

    bool permissionGranted = false;

    try {
      if (PlatformUtils.isMobile) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        permissionGranted = await androidImplementation?.requestNotificationsPermission() ?? false;
      } else if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosImplementation =
            _flutterLocalNotifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

        permissionGranted = await iosImplementation?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      // If permission is granted, ensure notifications are enabled in app settings
      if (permissionGranted) {
        await setEnabled(true);
      }

      return permissionGranted;
    } catch (e) {
      Logger.error('Error requesting notification permission: $e');
      return false;
    }
  }
}
