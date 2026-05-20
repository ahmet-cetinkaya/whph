import 'package:fake_async/fake_async.dart';
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
    alarmCancelled = false; // Reset cancellation flag when new alarm is scheduled
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
    test('wall clock time calculation works regardless of tick frequency', () {
      fakeAsync((async) {
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

        // Simulate time passing deterministically
        async.elapse(const Duration(milliseconds: 1100));

        expect(controller.sessionTotalElapsed.inMilliseconds, greaterThanOrEqualTo(1000));
      });
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

    test('system alarm is cancelled when timer completes naturally', () {
      fakeAsync((async) {
        controller.updateSettings(
          timerMode: TimerMode.normal,
          workDuration: 1, // 1 minute
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

        // Advance past the 1 minute duration
        async.elapse(const Duration(minutes: 1, seconds: 1));

        expect(controller.isRunning, false);
        expect(controller.isAlarmPlaying, true);
        // The natural completion should NOT manually cancel the alarm,
        // as the OS alarm service handles playing its own notification
      });
    });

    test('timer pauses and resumes correctly, rescheduling alarms', () {
      fakeAsync((async) {
        controller.updateSettings(
          timerMode: TimerMode.normal,
          workDuration: 10,
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
        expect(fakeReminderService.alarmScheduled, true);
        final initialAlarmTime = fakeReminderService.lastScheduledTime;

        // Elapse 1 minute
        async.elapse(const Duration(minutes: 1));

        // Pause timer
        controller.pauseTimer();
        expect(fakeReminderService.alarmCancelled, true);
        expect(controller.remainingTime.inMinutes, 9); // 10m - 1m

        // Resume timer
        controller.startTimer();
        expect(fakeReminderService.alarmScheduled, true);
        // New scheduled time should be at the same moment as initial (remaining time accounts for elapsed)
        expect(fakeReminderService.lastScheduledTime, initialAlarmTime);
      });
    });

    test('timer broadcasts tick state for tray/notification updates', () {
      fakeAsync((async) {
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

        int tickBroadcastCount = 0;
        Duration? lastTickDelta;
        controller.onTick = (delta) {
          tickBroadcastCount++;
          lastTickDelta = delta;
        };

        controller.startTimer();

        async.elapse(const Duration(seconds: 3));

        expect(tickBroadcastCount, 3);
        expect(lastTickDelta, const Duration(seconds: 1));
      });
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
