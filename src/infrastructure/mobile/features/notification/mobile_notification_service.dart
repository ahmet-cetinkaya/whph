import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mediatr/mediatr.dart';
import 'package:application/features/settings/commands/save_setting_command.dart';
import 'package:application/features/settings/queries/get_setting_query.dart';
import 'package:application/shared/utils/key_helper.dart' as shared;
import 'package:domain/features/settings/setting.dart';

import 'package:application/features/tasks/commands/complete_task_command.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:application/features/habits/commands/toggle_habit_completion_command.dart';
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

    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation == null) {
        DomainLogger.error(
          '[notification_channel_init_failed] MobileNotificationService: Android notification implementation not available',
        );
        return;
      }

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
        try {
          await androidImplementation.createNotificationChannel(channel);
          DomainLogger.info(
            'MobileNotificationService: Created notification channel ${channel.id}',
          );
        } catch (e, stackTrace) {
          DomainLogger.error(
            '[notification_channel_creation_failed] MobileNotificationService: Failed to create notification channel ${channel.id}',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }
    } catch (e, stackTrace) {
      DomainLogger.error(
        '[notification_channel_init_failed] MobileNotificationService: Failed to initialize notification channels',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> handleNotificationTaskCompletion(String taskId) async {
    try {
      DomainLogger.info('MobileNotificationService: Completing task from notification: $taskId');

      await _mediator.send<CompleteTaskCommand, CompleteTaskCommandResponse>(
        CompleteTaskCommand(id: taskId),
      );

      DomainLogger.info('MobileNotificationService: Task completed successfully from notification');
    } catch (e, stackTrace) {
      DomainLogger.error(
        '[$TaskErrorIds.notificationActionFailed] MobileNotificationService: Failed to complete task from notification',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> handleNotificationHabitCompletion(String habitId) async {
    try {
      DomainLogger.info('MobileNotificationService: Completing habit from notification: $habitId');

      await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(
        ToggleHabitCompletionCommand(
          habitId: habitId,
          date: DateTime.now(),
        ),
      );

      DomainLogger.info('MobileNotificationService: Habit completed successfully from notification');
    } catch (e, stackTrace) {
      DomainLogger.error(
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

    // Platform-specific notification details
    NotificationDetails notificationDetails;

    if (_isAndroid) {
      // Use task channel as default if none provided
      final String effectiveChannelId = options?.channelId ?? AndroidAppConstants.notificationChannels.taskChannelId;
      final String effectiveChannelName = effectiveChannelId == AndroidAppConstants.notificationChannels.habitChannelId
          ? AndroidAppConstants.notificationChannels.habitChannelName
          : AndroidAppConstants.notificationChannels.taskChannelName;

      notificationDetails = NotificationDetails(
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
      );
    } else {
      // iOS or other platforms
      notificationDetails = const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
    }

    await _flutterLocalNotifications.show(
      id ?? shared.KeyHelper.generateNumericId(),
      title,
      body,
      notificationDetails,
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
        DomainLogger.warning(
          'MobileNotificationService: Notification setting not found, defaulting to enabled',
        );
        return true; // Default to true if setting not found
      }

      return setting.value == 'false' ? false : true;
    } catch (e, stackTrace) {
      DomainLogger.error(
        '[notification_check_failed] MobileNotificationService: Failed to check if notifications are enabled, defaulting to disabled',
        error: e,
        stackTrace: stackTrace,
      );
      return false; // Default to FALSE on error - safer to disable than to silently fail
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
    if (!_isAndroid && !_isIOS) {
      return true; // Always return true for non-mobile platforms
    }

    if (_isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final areNotificationsEnabled = await androidImplementation?.areNotificationsEnabled();
      return areNotificationsEnabled ?? false;
    }

    if (_isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          _flutterLocalNotifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      final permissions = await iosImplementation?.checkPermissions();
      // iOS notifications are enabled if alert, badge, or sound is enabled
      return permissions?.isEnabled ?? false;
    }

    return false;
  }

  @override
  Future<bool> requestPermission() async {
    // Override platform check if flags are forced (testing)
    if (!_isAndroid && !_isIOS) {
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
    } catch (e, stackTrace) {
      DomainLogger.error(
        '[permission_request_failed] MobileNotificationService: Failed to request notification permission',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
