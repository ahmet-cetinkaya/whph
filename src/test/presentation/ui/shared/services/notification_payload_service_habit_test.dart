import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/shared/services/notification_payload_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Define the channel name
  const channelName = 'me.ahmetcetinkaya.whph/notification';

  group('NotificationPayloadService (Habits)', () {
    late List<MethodCall> log;

    setUp(() {
      NotificationPayloadService.forceAndroid = true;
      log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        (MethodCall methodCall) async {
          log.add(methodCall);

          if (methodCall.method == 'getPendingHabitCompletions') {
            return ['habit1', 'habit2'];
          } else if (methodCall.method == 'getRetryCount') {
            return 0;
          } else if (methodCall.method == 'clearPendingHabitCompletion') {
            return null;
          } else if (methodCall.method == 'setRetryCount') {
            return null;
          } else if (methodCall.method == 'clearRetryCount') {
            return null;
          }
          return null;
        },
      );
    });

    tearDown(() {
      NotificationPayloadService.forceAndroid = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        null,
      );
    });

    group('processPendingHabitCompletions', () {
      test('should process all pending habit completions on startup', () async {
        // Arrange
        final completedHabits = <String>[];
        Future<void> onHabitCompletion(String habitId) async {
          completedHabits.add(habitId);
        }

        // Act
        await NotificationPayloadService.processPendingHabitCompletions(onHabitCompletion);

        // Assert - Verify callbacks were called
        expect(completedHabits.length, equals(2));
        expect(completedHabits, equals(['habit1', 'habit2']));

        // Assert - Verify native calls
        // Should get pending habits
        expect(log.any((c) => c.method == 'getPendingHabitCompletions'), isTrue);

        // Should clear pending habit for each processed habit
        expect(log.where((c) => c.method == 'clearPendingHabitCompletion').length, equals(2));
        expect(log.any((c) => c.method == 'clearPendingHabitCompletion' && c.arguments == 'habit1'), isTrue);
        expect(log.any((c) => c.method == 'clearPendingHabitCompletion' && c.arguments == 'habit2'), isTrue);
      });

      test('should handle empty pending list gracefully', () async {
        // Arrange
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel(channelName),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getPendingHabitCompletions') {
              return <dynamic>[];
            }
            return null;
          },
        );

        final completedHabits = <String>[];
        Future<void> onHabitCompletion(String habitId) async {
          completedHabits.add(habitId);
        }

        // Act
        await NotificationPayloadService.processPendingHabitCompletions(onHabitCompletion);

        // Assert
        expect(completedHabits.isEmpty, isTrue);
      });

      test('should retry failed habit completions', () async {
        // Arrange
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel(channelName),
          (MethodCall methodCall) async {
            log.add(methodCall);
            if (methodCall.method == 'getPendingHabitCompletions') {
              return ['habit_fail'];
            } else if (methodCall.method == 'getRetryCount') {
              return 0;
            } else if (methodCall.method == 'setRetryCount') {
              return null;
            }
            return null;
          },
        );

        Future<void> onHabitCompletion(String habitId) async {
          throw Exception('Failed to complete habit');
        }

        // Act
        await NotificationPayloadService.processPendingHabitCompletions(onHabitCompletion);

        // Assert
        // Should set retry count to 1
        expect(
            log.any((c) =>
                c.method == 'setRetryCount' &&
                (c.arguments as Map)['key'] == 'retry_count_habit_fail' &&
                (c.arguments as Map)['count'] == 1),
            isTrue);

        // Should NOT clear pending habit
        expect(log.any((c) => c.method == 'clearPendingHabitCompletion'), isFalse);
      });

      test('should stop retrying after max attempts', () async {
        // Arrange
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel(channelName),
          (MethodCall methodCall) async {
            log.add(methodCall);
            if (methodCall.method == 'getPendingHabitCompletions') {
              return ['habit_max_retry'];
            } else if (methodCall.method == 'getRetryCount') {
              return 5; // Max retries reached
            } else if (methodCall.method == 'clearPendingHabitCompletion') {
              return null;
            } else if (methodCall.method == 'clearRetryCount') {
              return null;
            }
            return null;
          },
        );

        bool callbackCalled = false;
        Future<void> onHabitCompletion(String habitId) async {
          callbackCalled = true;
        }

        // Act
        await NotificationPayloadService.processPendingHabitCompletions(onHabitCompletion);

        // Assert
        // Should NOT call callback
        expect(callbackCalled, isFalse);

        // Should clear pending habit (give up)
        expect(log.any((c) => c.method == 'clearPendingHabitCompletion' && c.arguments == 'habit_max_retry'), isTrue);

        // Should clear retry count
        expect(log.any((c) => c.method == 'clearRetryCount'), isTrue);
      });
    });
  });
}
