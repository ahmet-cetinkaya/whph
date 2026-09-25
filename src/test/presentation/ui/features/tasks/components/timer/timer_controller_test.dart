import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/core/application/shared/services/timer_session_service.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/infrastructure/android/constants/android_app_constants.dart';
import 'package:whph/infrastructure/shared/features/wakelock/abstractions/i_wakelock_service.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/tasks/components/timer/timer.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer_controller.dart';
import 'package:whph/presentation/ui/features/tasks/models/timer_settings.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_reminder_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/notification_payload_service.dart';

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

class FakeDurationWriter implements ITimerSessionDurationWriter {
  @override
  Future<void> write(TimerSessionDuration duration) async {}
}

class _RecordingWidgetDurationWriter implements ITimerSessionDurationWriter {
  final List<TimerSessionDuration> writes = [];

  @override
  Future<void> write(TimerSessionDuration duration) async => writes.add(duration);
}

class FakeAlarmScheduler implements ITimerSessionAlarmScheduler {
  @override
  Future<void> cancel(String alarmId) async {}

  @override
  Future<void> schedule({
    required String alarmId,
    required DateTime scheduledAt,
  }) async {}
}

class _TimerWidgetMediator extends Fake implements Mediator {
  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    final Object settingRequest = request;
    if (settingRequest is GetSettingQuery && settingRequest.key == SettingKeys.defaultTimerMode) {
      return GetSettingQueryResponse(
        id: 'timer-mode',
        createdDate: DateTime(2026, 9, 8),
        key: SettingKeys.defaultTimerMode,
        value: TimerMode.normal.value,
        valueType: SettingValueType.string,
      ) as R;
    }
    return null as R;
  }
}

class _FakeContainer extends Fake implements IContainer {
  Map<Type, Object> _registrations = const {};

  void register<T extends Object>(T instance) => _registrations = {..._registrations, T: instance};

  @override
  T resolve<T>([String? name]) => _registrations[T] as T;
}

class _FakeSoundManager extends Fake implements ISoundManagerService {
  @override
  Future<void> stopAll() async {}

  @override
  Future<void> stopTimerAlarmLoop() async {}
}

class _FakeSystemTray extends Fake implements ISystemTrayService {
  @override
  Future<void> setTitle(String title) async {}

  @override
  Future<void> setBody(String body) async {}

  @override
  Future<void> setIcon(TrayIconType type) async {}

  @override
  Future<void> insertMenuItem(TrayMenuItem item, {int? index}) async {}

  @override
  Future<void> removeMenuItem(String key) async {}

  @override
  Future<void> reset() async {}

  @override
  List<TrayMenuItem> getMenuItems() => const [];
}

class _FakeWakelock extends Fake implements IWakelockService {
  @override
  Future<void> disable() async {}
}

class _FakeTranslation extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class _FakeNotification extends Fake implements INotificationService {}

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
    testWidgets('AppTimer normal notification action uses the shared restart operation', (tester) async {
      var now = DateTime(2026, 9, 8);
      final writer = _RecordingWidgetDurationWriter();
      final sessionService = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: FakeAlarmScheduler(),
        now: () => now,
      );
      final widgetContainer = _FakeContainer()
        ..register<Mediator>(_TimerWidgetMediator())
        ..register<ISoundManagerService>(_FakeSoundManager())
        ..register<ISystemTrayService>(_FakeSystemTray())
        ..register<ITranslationService>(_FakeTranslation())
        ..register<INotificationService>(_FakeNotification())
        ..register<IWakelockService>(_FakeWakelock())
        ..register<IReminderService>(FakeReminderService())
        ..register<ITimerSessionService>(sessionService);
      app_main.container = widgetContainer;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        NotificationPayloadService.disposeActionStream();
        await sessionService.shutdown();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTimer(
              sessionId: 'task:notification-widget',
              sessionOwner: TimerSessionOwner.task('notification-widget'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await sessionService.start('task:notification-widget');
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));

      NotificationPayloadService.handleForegroundAction(
        '${AndroidAppConstants.intentActions.timerStartBreak}:task:notification-widget',
      );
      await tester.pump();

      final state = sessionService.state('task:notification-widget')!;
      expect(state.settings.mode, TimerSessionMode.normal);
      expect(state.isRunning, isTrue);
      expect(state.sessionTotalElapsed, Duration.zero);
      expect(writer.writes.map((write) => write.duration.inSeconds), [5]);
      await sessionService.stop('task:notification-widget');
    });

    test('reflects the same shared session controlled outside the UI', () {
      fakeAsync((async) {
        final sessionService = TimerSessionService(
          durationWriter: FakeDurationWriter(),
          alarmScheduler: FakeAlarmScheduler(),
          now: () => DateTime(2026, 9, 8).add(async.elapsed),
        );
        final sharedController = TimerController(
          mediator: FakeMediator(),
          reminderService: FakeReminderService(),
          sessionService: sessionService,
          sessionId: 'task:shared',
          sessionOwner: const TimerSessionOwner.task('shared'),
        );
        sharedController.updateSettings(
          _defaultSettings(timerMode: TimerMode.stopwatch),
        );
        async.flushMicrotasks();

        sessionService.start('task:shared');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(sharedController.isRunning, isTrue);
        expect(sharedController.elapsedTime, const Duration(seconds: 2));
        sharedController.dispose();
        expect(sessionService.state('task:shared')!.isRunning, isTrue);
      });
    });

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
      test('shared normal notification transition resets and restarts the timer', () {
        fakeAsync((async) {
          final sessionService = TimerSessionService(
            durationWriter: FakeDurationWriter(),
            alarmScheduler: FakeAlarmScheduler(),
            now: () => DateTime(2026, 9, 8).add(async.elapsed),
          );
          final sharedController = TimerController(
            mediator: FakeMediator(),
            reminderService: FakeReminderService(),
            sessionService: sessionService,
            sessionId: 'task:normal-notification',
            sessionOwner: const TimerSessionOwner.task('normal-notification'),
          );
          sharedController.updateSettings(
            _defaultSettings(timerMode: TimerMode.normal),
          );
          async.flushMicrotasks();
          sharedController.startTimer();
          async.flushMicrotasks();
          async.elapse(const Duration(minutes: 1, seconds: 1));
          async.flushMicrotasks();

          expect(sharedController.isAlarmPlaying, isTrue);
          sharedController.startNextPhase();
          async.flushMicrotasks();

          expect(sharedController.isRunning, isTrue);
          expect(sharedController.isAlarmPlaying, isFalse);
          expect(sharedController.remainingTime, const Duration(minutes: 1));
          sharedController.dispose();
        });
      });

      test('shared stopwatch notification transition resets elapsed time', () {
        fakeAsync((async) {
          final sessionService = TimerSessionService(
            durationWriter: FakeDurationWriter(),
            alarmScheduler: FakeAlarmScheduler(),
            now: () => DateTime(2026, 9, 8).add(async.elapsed),
          );
          final sharedController = TimerController(
            mediator: FakeMediator(),
            reminderService: FakeReminderService(),
            sessionService: sessionService,
            sessionId: 'task:stopwatch-notification',
            sessionOwner: const TimerSessionOwner.task('stopwatch-notification'),
          );
          sharedController.updateSettings(
            _defaultSettings(timerMode: TimerMode.stopwatch),
          );
          async.flushMicrotasks();
          sharedController.startTimer();
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();

          expect(sharedController.elapsedTime, const Duration(seconds: 5));
          sharedController.startNextPhase();
          async.flushMicrotasks();

          expect(sharedController.elapsedTime, Duration.zero);
          expect(sharedController.isRunning, isTrue);
          sharedController.dispose();
        });
      });

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
