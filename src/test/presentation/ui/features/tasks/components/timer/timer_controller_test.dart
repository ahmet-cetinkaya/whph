import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer_controller.dart';
import 'package:whph/presentation/ui/features/tasks/models/timer_settings.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';

/// No-op mediator implementation.
/// Used as a placeholder since TimerController requires a Mediator but
/// these tests don't exercise settings persistence paths.
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
    alarmCancelled = false;
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

TimerSettings _defaultSettings({
  TimerMode timerMode = TimerMode.normal,
  int workDuration = 1,
  int breakDuration = 1,
  int longBreakDuration = 15,
  int sessionsCount = 4,
  bool autoStartBreak = false,
  bool autoStartWork = false,
  bool tickingEnabled = false,
  bool keepScreenAwake = false,
  int tickingVolume = 50,
  int tickingSpeed = 1,
}) {
  return TimerSettings(
    timerMode: timerMode,
    workDuration: workDuration,
    breakDuration: breakDuration,
    longBreakDuration: longBreakDuration,
    sessionsCount: sessionsCount,
    autoStartBreak: autoStartBreak,
    autoStartWork: autoStartWork,
    tickingEnabled: tickingEnabled,
    keepScreenAwake: keepScreenAwake,
    tickingVolume: tickingVolume,
    tickingSpeed: tickingSpeed,
  );
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
          controller.updateSettings(_defaultSettings());

          controller.startTimer();
          expect(controller.isRunning, true);

          async.elapse(const Duration(milliseconds: 1100));

          expect(controller.sessionTotalElapsed.inMilliseconds, greaterThanOrEqualTo(1000));
        });
      });
    });

    group('alarm scheduling', () {
      test('system alarm is scheduled for countdown timers', () async {
        controller.updateSettings(_defaultSettings());

        expect(fakeReminderService.alarmScheduled, false);

        controller.startTimer();

        expect(fakeReminderService.alarmScheduled, true);
        expect(fakeReminderService.lastAlarmId, equals('timer_alarm'));
      });

      test('system alarm is NOT scheduled for stopwatch mode', () async {
        controller.updateSettings(_defaultSettings(timerMode: TimerMode.stopwatch));

        controller.startTimer();

        expect(fakeReminderService.alarmScheduled, false);
      });
    });

    group('alarm cancellation', () {
      test('system alarm is cancelled when timer stops', () async {
        controller.updateSettings(_defaultSettings());

        controller.startTimer();
        expect(fakeReminderService.alarmCancelled, false);

        controller.stopTimer();

        expect(fakeReminderService.alarmCancelled, true);
      });

      test('system alarm is cancelled when timer completes naturally', () {
        fakeAsync((async) {
          controller.updateSettings(_defaultSettings());

          controller.startTimer();
          expect(fakeReminderService.alarmCancelled, false);

          async.elapse(const Duration(minutes: 1, seconds: 1));

          expect(controller.isRunning, false);
          expect(controller.isAlarmPlaying, true);
          expect(fakeReminderService.alarmCancelled, true);
        });
      });

      test('system alarm is cancelled on dispose', () async {
        controller.updateSettings(_defaultSettings());

        controller.startTimer();
        controller.dispose();

        expect(fakeReminderService.alarmCancelled, true);
      });
    });

    group('pause and resume', () {
      test('timer pauses and resumes correctly, rescheduling alarms', () {
        fakeAsync((async) {
          controller.updateSettings(_defaultSettings());

          controller.startTimer();
          expect(fakeReminderService.alarmScheduled, true);
          final initialAlarmTime = fakeReminderService.lastScheduledTime;

          async.elapse(const Duration(seconds: 10));

          controller.pauseTimer();
          expect(fakeReminderService.alarmCancelled, true);
          expect(controller.remainingTime.inSeconds, 50);

          controller.startTimer();
          expect(fakeReminderService.alarmScheduled, true);
          expect(fakeReminderService.lastScheduledTime, initialAlarmTime);
        });
      });
    });

    group('tick broadcasting', () {
      test('timer broadcasts tick state for tray/notification updates', () {
        fakeAsync((async) {
          controller.updateSettings(_defaultSettings());

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
          controller.updateSettings(_defaultSettings(
            timerMode: TimerMode.pomodoro,
            breakDuration: 5,
          ));

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
          controller.updateSettings(_defaultSettings(
            timerMode: TimerMode.pomodoro,
            workDuration: 5,
            breakDuration: 5,
            sessionsCount: 2,
          ));

          controller.startTimer();
          async.elapse(const Duration(seconds: 6));
          controller.toggleWorkBreak();

          expect(controller.completedSessions, 1);
          expect(controller.isLongBreak, false);
          expect(controller.isWorking, false);

          async.elapse(const Duration(seconds: 6));
          controller.toggleWorkBreak();

          expect(controller.isWorking, true);
          expect(controller.completedSessions, 1);

          async.elapse(const Duration(seconds: 6));
          controller.toggleWorkBreak();

          expect(controller.completedSessions, 0);
          expect(controller.isLongBreak, true);
          expect(controller.remainingTime, const Duration(minutes: 15));
        });
      });

      test('resets stopwatch elapsed time on toggle', () {
        fakeAsync((async) {
          controller.updateSettings(_defaultSettings(timerMode: TimerMode.stopwatch));

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
          controller.updateSettings(_defaultSettings(
            timerMode: TimerMode.pomodoro,
            breakDuration: 5,
          ));

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
          controller.updateSettings(_defaultSettings(
            timerMode: TimerMode.normal,
            breakDuration: 5,
          ));

          controller.startTimer();
          async.elapse(const Duration(seconds: 30));

          controller.stopTimer();

          expect(controller.remainingTime, const Duration(minutes: 1));
          expect(controller.isRunning, false);
        });
      });

      test('resets stopwatch elapsed time', () {
        fakeAsync((async) {
          controller.updateSettings(_defaultSettings(timerMode: TimerMode.stopwatch));

          controller.startTimer();
          async.elapse(const Duration(seconds: 10));

          controller.stopTimer();

          expect(controller.elapsedTime, Duration.zero);
        });
      });
    });

    group('startTimer', () {
      test('is idempotent - calling twice does not double-schedule', () async {
        controller.updateSettings(_defaultSettings());

        controller.startTimer();
        expect(fakeReminderService.alarmScheduled, true);

        final firstScheduleCount = fakeReminderService.scheduleCount;

        controller.startTimer();

        expect(fakeReminderService.scheduleCount, firstScheduleCount);
      });
    });

    group('updateSettings', () {
      test('cancels active alarm when settings change', () async {
        controller.updateSettings(_defaultSettings());

        controller.startTimer();
        expect(fakeReminderService.alarmCancelled, false);

        controller.updateSettings(_defaultSettings(workDuration: 5));

        expect(fakeReminderService.alarmCancelled, true);
      });
    });
  });
}
