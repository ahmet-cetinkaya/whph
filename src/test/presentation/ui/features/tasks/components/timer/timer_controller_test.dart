import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer_controller.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';

class FakeMediator implements Mediator {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReminderService implements IReminderService {
  bool alarmScheduled = false;
  bool alarmCancelled = false;
  String? lastAlarmId;
  DateTime? lastScheduledTime;

  @override
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    alarmScheduled = true;
    lastAlarmId = id;
    lastScheduledTime = scheduledDate;
  }

  @override
  Future<void> cancelReminder(String id) async {
    alarmCancelled = true;
    lastAlarmId = id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late TimerController controller;
  late FakeMediator fakeMediator;
  late FakeReminderService fakeReminderService;

  setUp(() {
    fakeMediator = FakeMediator();
    fakeReminderService = FakeReminderService();
    controller = TimerController(
      mediator: fakeMediator,
      reminderService: fakeReminderService,
    );
  });

  group('TimerController fixes for #268', () {
    test('wall clock time calculation works regardless of tick frequency', () async {
      controller.updateSettings(
        timerMode: TimerMode.normal,
        workDuration: 1,
        breakDuration: 1,
        longBreakDuration: 15,
        sessionsCount: 4,
        autoStartBreak: false,
        autoStartWork: false,
        tickingEnabled: false,
        keepScreenAwake: false,
        tickingVolume: 50,
        tickingSpeed: 1,
      );

      controller.startTimer();
      expect(controller.isRunning, true);

      // Simulate real time passing
      await Future.delayed(const Duration(milliseconds: 1100));

      expect(controller.sessionTotalElapsed.inMilliseconds, greaterThanOrEqualTo(1000));
    });

    test('system alarm is scheduled for countdown timers', () async {
      controller.updateSettings(
        timerMode: TimerMode.normal,
        workDuration: 1,
        breakDuration: 1,
        longBreakDuration: 15,
        sessionsCount: 4,
        autoStartBreak: false,
        autoStartWork: false,
        tickingEnabled: false,
        keepScreenAwake: false,
        tickingVolume: 50,
        tickingSpeed: 1,
      );

      expect(fakeReminderService.alarmScheduled, false);

      controller.startTimer();

      expect(fakeReminderService.alarmScheduled, true);
      expect(fakeReminderService.lastAlarmId, equals('timer_alarm'));
    });

    test('system alarm is NOT scheduled for stopwatch mode', () async {
      controller.updateSettings(
        timerMode: TimerMode.stopwatch,
        workDuration: 1,
        breakDuration: 1,
        longBreakDuration: 15,
        sessionsCount: 4,
        autoStartBreak: false,
        autoStartWork: false,
        tickingEnabled: false,
        keepScreenAwake: false,
        tickingVolume: 50,
        tickingSpeed: 1,
      );

      controller.startTimer();

      expect(fakeReminderService.alarmScheduled, false);
    });

    test('system alarm is cancelled when timer stops', () async {
      controller.updateSettings(
        timerMode: TimerMode.normal,
        workDuration: 1,
        breakDuration: 1,
        longBreakDuration: 15,
        sessionsCount: 4,
        autoStartBreak: false,
        autoStartWork: false,
        tickingEnabled: false,
        keepScreenAwake: false,
        tickingVolume: 50,
        tickingSpeed: 1,
      );

      controller.startTimer();
      expect(fakeReminderService.alarmCancelled, false);

      controller.stopTimer();

      expect(fakeReminderService.alarmCancelled, true);
    });

    test('system alarm is cancelled on dispose', () async {
      controller.updateSettings(
        timerMode: TimerMode.normal,
        workDuration: 1,
        breakDuration: 1,
        longBreakDuration: 15,
        sessionsCount: 4,
        autoStartBreak: false,
        autoStartWork: false,
        tickingEnabled: false,
        keepScreenAwake: false,
        tickingVolume: 50,
        tickingSpeed: 1,
      );

      controller.startTimer();
      controller.dispose();

      expect(fakeReminderService.alarmCancelled, true);
    });
  });
}
