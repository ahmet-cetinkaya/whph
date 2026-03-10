import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/complete_task_command.dart';
import 'package:whph/infrastructure/mobile/features/notification/mobile_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';

import 'mobile_notification_service_test.mocks.dart';

@GenerateMocks([
  Mediator,
  FlutterLocalNotificationsPlugin,
  AndroidFlutterLocalNotificationsPlugin,
])
void main() {
  group('MobileNotificationService', () {
    late MobileNotificationService service;
    late MockMediator mockMediator;
    late MockFlutterLocalNotificationsPlugin mockFlutterLocalNotificationsPlugin;
    late MockAndroidFlutterLocalNotificationsPlugin mockAndroidFlutterLocalNotificationsPlugin;

    setUp(() {
      mockMediator = MockMediator();
      mockFlutterLocalNotificationsPlugin = MockFlutterLocalNotificationsPlugin();
      mockAndroidFlutterLocalNotificationsPlugin = MockAndroidFlutterLocalNotificationsPlugin();

      // Default mock behavior for platform implementation resolution
      when(mockFlutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(mockAndroidFlutterLocalNotificationsPlugin);
    });

    group('init', () {
      test('should initialize notifications and create channels on Android', () async {
        // Arrange
        when(mockFlutterLocalNotificationsPlugin.initialize(any,
                onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse')))
            .thenAnswer((_) async => true);

        when(mockAndroidFlutterLocalNotificationsPlugin.createNotificationChannel(any)).thenAnswer((_) async {});

        service = MobileNotificationService(
          mockMediator,
          flutterLocalNotifications: mockFlutterLocalNotificationsPlugin,
          isAndroid: true,
        );

        // Act
        await service.init();

        // Assert
        verify(mockFlutterLocalNotificationsPlugin.initialize(any,
                onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse')))
            .called(1);

        // Verify channels are created (Task and Habit)
        verify(mockAndroidFlutterLocalNotificationsPlugin.createNotificationChannel(argThat(
            predicate<AndroidNotificationChannel>((channel) =>
                channel.id == 'whph_task_reminders' &&
                channel.name == 'Task Reminders' &&
                channel.importance == Importance.max)))).called(1);

        verify(mockAndroidFlutterLocalNotificationsPlugin.createNotificationChannel(argThat(
            predicate<AndroidNotificationChannel>((channel) =>
                channel.id == 'whph_habit_reminders' &&
                channel.name == 'Habit Reminders' &&
                channel.importance == Importance.max)))).called(1);
      });
    });

    group('show', () {
      setUp(() {
        // Mock isEnabled to return true by default
        when(mockMediator.send<GetSettingQuery, GetSettingQueryResponse?>(
          argThat(isA<GetSettingQuery>()),
        )).thenAnswer((_) async => GetSettingQueryResponse(
              id: '1',
              createdDate: DateTime.now(),
              key: SettingKeys.notifications,
              value: 'true',
              valueType: SettingValueType.bool,
            ));

        // Mock permission check for Android
        when(mockFlutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>())
            .thenReturn(mockAndroidFlutterLocalNotificationsPlugin);

        when(mockAndroidFlutterLocalNotificationsPlugin.requestNotificationsPermission()).thenAnswer((_) async => true);

        when(mockFlutterLocalNotificationsPlugin.show(any, any, any, any, payload: anyNamed('payload')))
            .thenAnswer((_) async {});
      });

      test('should use task channel by default when no channelId provided', () async {
        // Arrange
        service = MobileNotificationService(
          mockMediator,
          flutterLocalNotifications: mockFlutterLocalNotificationsPlugin,
          isAndroid: true,
        );

        // Act
        await service.show(title: 'Test', body: 'Body');

        // Assert
        verify(mockFlutterLocalNotificationsPlugin.show(
          any,
          'Test',
          'Body',
          argThat(predicate<NotificationDetails>((details) {
            return details.android?.channelId == 'whph_task_reminders' &&
                details.android?.channelName == 'Task Reminders';
          })),
          payload: anyNamed('payload'),
        )).called(1);
      });

      test('should use habit channel when habit channelId provided', () async {
        // Arrange
        service = MobileNotificationService(
          mockMediator,
          flutterLocalNotifications: mockFlutterLocalNotificationsPlugin,
          isAndroid: true,
        );

        // Act
        await service.show(
          title: 'Habit',
          body: 'Done',
          options: const NotificationOptions(
            channelId: 'whph_habit_reminders',
          ),
        );

        // Assert
        verify(mockFlutterLocalNotificationsPlugin.show(
          any,
          'Habit',
          'Done',
          argThat(predicate<NotificationDetails>((details) {
            return details.android?.channelId == 'whph_habit_reminders' &&
                details.android?.channelName == 'Habit Reminders';
          })),
          payload: anyNamed('payload'),
        )).called(1);
      });
    });

    // Existing tests...
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
    });
  });
}
