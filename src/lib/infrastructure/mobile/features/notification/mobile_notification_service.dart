import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' show PlatformUtils;
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart' as shared;
import 'package:whph/core/domain/features/settings/setting.dart';

import 'package:whph/core/application/features/tasks/commands/complete_task_command.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';

class MobileNotificationService implements INotificationService {
  final Mediator _mediator;
  final FlutterLocalNotificationsPlugin _flutterLocalNotifications;
  final bool _isAndroid;
  final bool _isIOS;

  MobileNotificationService(
    this._mediator, {
    FlutterLocalNotificationsPlugin? flutterLocalNotifications,
    bool? isAndroid,
    bool? isIOS,
  })  : _flutterLocalNotifications = flutterLocalNotifications ?? FlutterLocalNotificationsPlugin(),
        _isAndroid = isAndroid ?? Platform.isAndroid,
        _isIOS = isIOS ?? Platform.isIOS;

  @override
  Future<void> init() async {
    await _flutterLocalNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    if (!_isAndroid) return;

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    final List<AndroidNotificationChannel> channels = [
      AndroidNotificationChannel(
        AndroidAppConstants.notificationChannels.taskChannelId,
        AndroidAppConstants.notificationChannels.taskChannelName,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
      AndroidNotificationChannel(
        AndroidAppConstants.notificationChannels.habitChannelId,
        AndroidAppConstants.notificationChannels.habitChannelName,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    ];

    for (final channel in channels) {
      await androidImplementation?.createNotificationChannel(channel);
    }
  }

  @override
  Future<void> handleNotificationTaskCompletion(String taskId) async {
    try {
      Logger.info('MobileNotificationService: Completing task from notification: $taskId');

      await _mediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
        CompleteTaskCommand(id: taskId),
      );

      Logger.info('MobileNotificationService: Task completed successfully from notification');
    } catch (e, stackTrace) {
      Logger.error(
        '[$TaskErrorIds.notificationActionFailed] MobileNotificationService: Failed to complete task from notification',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> handleNotificationHabitCompletion(String habitId) async {
    try {
      Logger.info('MobileNotificationService: Completing habit from notification: $habitId');

      await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(
        ToggleHabitCompletionCommand(
          habitId: habitId,
          date: DateTime.now(),
        ),
      );

      Logger.info('MobileNotificationService: Habit completed successfully from notification');
    } catch (e, stackTrace) {
      Logger.error(
        '[$TaskErrorIds.notificationActionFailed] MobileNotificationService: Failed to complete habit from notification',
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
    NotificationOptions? options,
  }) async {
    if (!await isEnabled()) return;

    final bool? permissionGranted = await _checkPermission();
    if (permissionGranted != true) return;

    // Use task channel as default if none provided
    final String effectiveChannelId = options?.channelId ?? AndroidAppConstants.notificationChannels.taskChannelId;
    final String effectiveChannelName = effectiveChannelId == AndroidAppConstants.notificationChannels.habitChannelId
        ? AndroidAppConstants.notificationChannels.habitChannelName
        : AndroidAppConstants.notificationChannels.taskChannelName;

    await _flutterLocalNotifications.show(
      id ?? shared.KeyHelper.generateNumericId(),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          effectiveChannelId,
          effectiveChannelName,
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
    if (_isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      return await androidImplementation?.requestNotificationsPermission();
    }

    if (_isIOS) {
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
      final setting = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(query);

      if (setting == null) {
        return true; // Default to true if setting not found
      }

      return setting.value == 'false' ? false : true;
    } catch (e) {
      return true; // Default to true if error occurs
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
    // Override platform check if flags are forced (testing)
    if (!_isAndroid && !_isIOS && !PlatformUtils.isMobile) {
      return true; // Always return true for non-mobile platforms
    }

    if (_isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final areNotificationsEnabled = await androidImplementation?.areNotificationsEnabled();
      return areNotificationsEnabled ?? false;
    }

    return false;
  }

  @override
  Future<bool> requestPermission() async {
    // Override platform check if flags are forced (testing)
    if (!_isAndroid && !_isIOS && !PlatformUtils.isMobile && !Platform.isIOS) {
      return true; // Non-mobile platforms don't need explicit permission
    }

    bool permissionGranted = false;

    try {
      if (_isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        permissionGranted = await androidImplementation?.requestNotificationsPermission() ?? false;
      } else if (_isIOS) {
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
