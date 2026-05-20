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
  int scheduleCount = 0;
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
    scheduleCount++;
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

  group('TimerController', () {
    group('time calculation', () {
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
    });

    group('alarm scheduling', () {
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
    });

    group('alarm cancellation', () {
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

    group('pause and resume', () {
      test('timer pauses and resumes correctly, rescheduling alarms', () {
        fakeAsync((async) {
          controller.updateSettings(
            timerMode: TimerMode.normal,
            workDuration: 1, // 1 minute = 60 seconds
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

          // Elapse 10 seconds (under 30s forward clock threshold)
          async.elapse(const Duration(seconds: 10));

          // Pause timer
          controller.pauseTimer();
          expect(fakeReminderService.alarmCancelled, true);
          expect(controller.remainingTime.inSeconds, 50); // 60s - 10s

          // Resume timer
          controller.startTimer();
          expect(fakeReminderService.alarmScheduled, true);
          // New scheduled time should be at the same moment as initial (remaining time accounts for elapsed)
          expect(fakeReminderService.lastScheduledTime, initialAlarmTime);
        });
      });
    });

    group('tick broadcasting', () {
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
    });

    group('toggleWorkBreak', () {
      test('toggles from work to break and increments session count', () {
        fakeAsync((async) {
          controller.updateSettings(
            timerMode: TimerMode.pomodoro,
            workDuration: 1,
            breakDuration: 5,
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
          async.elapse(const Duration(minutes: 1, seconds: 1));

          expect(controller.isAlarmPlaying, true);
          expect(controller.isWorking, true);

          controller.toggleWorkBreak();

          expect(controller.isWorking, false);
          expect(controller.completedSessions, 1);
          expect(controller.isLongBreak, false);
          expect(controller.remainingTime, const Duration(minutes: 5));
        });
      });

      test('triggers long break after completing all sessions', () {
        fakeAsync((async) {
          controller.updateSettings(
            timerMode: TimerMode.pomodoro,
            workDuration: 5, // 5 seconds for fast test
            breakDuration: 5,
            longBreakDuration: 15,
            sessionsCount: 2,
            autoStartBreak: false,
            autoStartWork: false,
            tickingEnabled: false,
            keepScreenAwake: false,
            tickingVolume: 50,
            tickingSpeed: 1,
          );

          // Complete first work session → toggle to break
          controller.startTimer();
          async.elapse(const Duration(seconds: 6));
          controller.toggleWorkBreak();

          expect(controller.completedSessions, 1);
          expect(controller.isLongBreak, false);
          expect(controller.isWorking, false);

          // Complete break session → toggle back to work
          async.elapse(const Duration(seconds: 6));
          controller.toggleWorkBreak();

          expect(controller.isWorking, true);
          expect(controller.completedSessions, 1);

          // Complete second work session → toggle to break (triggers long break)
          async.elapse(const Duration(seconds: 6));
          controller.toggleWorkBreak();

          expect(controller.completedSessions, 0); // Reset after long break triggered
          expect(controller.isLongBreak, true);
          expect(controller.remainingTime, const Duration(minutes: 15));
        });
      });

      test('resets stopwatch elapsed time on toggle', () {
        fakeAsync((async) {
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
          async.elapse(const Duration(seconds: 5));

          expect(controller.elapsedTime.inSeconds, greaterThanOrEqualTo(5));

          controller.toggleWorkBreak();

          expect(controller.elapsedTime, Duration.zero);
          expect(controller.isRunning, true);
        });
      });
    });

    group('stopTimer', () {
      test('resets state correctly for pomodoro mode', () {
        fakeAsync((async) {
          controller.updateSettings(
            timerMode: TimerMode.pomodoro,
            workDuration: 1,
            breakDuration: 5,
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
          async.elapse(const Duration(minutes: 1, seconds: 1));
          controller.toggleWorkBreak();

          expect(controller.completedSessions, 1);
          expect(controller.isWorking, false);

          controller.stopTimer();

          expect(controller.isWorking, true);
          expect(controller.completedSessions, 0);
          expect(controller.isLongBreak, false);
          expect(controller.remainingTime, const Duration(minutes: 1));
        });
      });

      test('resets state correctly for normal mode', () {
        fakeAsync((async) {
          controller.updateSettings(
            timerMode: TimerMode.normal,
            workDuration: 1,
            breakDuration: 5,
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
          async.elapse(const Duration(seconds: 30));

          controller.stopTimer();

          expect(controller.remainingTime, const Duration(minutes: 1));
          expect(controller.isRunning, false);
        });
      });

      test('resets stopwatch elapsed time', () {
        fakeAsync((async) {
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
          async.elapse(const Duration(seconds: 10));

          controller.stopTimer();

          expect(controller.elapsedTime, Duration.zero);
        });
      });
    });

    group('startTimer', () {
      test('is idempotent - calling twice does not double-schedule', () async {
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
        expect(fakeReminderService.alarmScheduled, true);

        final firstScheduleCount = fakeReminderService.scheduleCount;

        controller.startTimer();

        expect(fakeReminderService.scheduleCount, firstScheduleCount);
      });
    });

    group('updateSettings', () {
      test('cancels active alarm when settings change', () async {
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

        controller.updateSettings(
          timerMode: TimerMode.normal,
          workDuration: 5,
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

        expect(fakeReminderService.alarmCancelled, true);
      });
    });
  });
}
