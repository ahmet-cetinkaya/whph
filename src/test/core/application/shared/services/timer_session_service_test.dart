import 'dart:io';

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_time_record_command.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/core/application/shared/services/timer_session_service.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

class _RecordingDurationWriter implements ITimerSessionDurationWriter {
  final List<TimerSessionDuration> writes = [];
  bool shouldFail = false;
  int? failAtAttempt;
  String? failTargetId;
  int attempts = 0;

  @override
  Future<void> write(TimerSessionDuration duration) async {
    attempts++;
    if (shouldFail ||
        attempts == failAtAttempt ||
        duration.targetId == failTargetId) throw StateError('save failed');
    writes.add(duration);
  }
}

class _RecordingAlarmScheduler implements ITimerSessionAlarmScheduler {
  final List<String> scheduledIds = [];
  final List<String> cancelledIds = [];

  @override
  Future<void> cancel(String alarmId) async => cancelledIds.add(alarmId);

  @override
  Future<void> schedule({
    required String alarmId,
    required DateTime scheduledAt,
  }) async =>
      scheduledIds.add(alarmId);
}

class _TaskEvents extends Fake implements ITaskEvents {
  final List<String> updatedTimeRecords = [];

  @override
  void notifyTaskTimeRecordUpdated(String taskId) =>
      updatedTimeRecords.add(taskId);
}

void main() {
  const stopwatchSettings = TimerSessionSettings(
    mode: TimerSessionMode.stopwatch,
    workDuration: Duration(minutes: 25),
    breakDuration: Duration(minutes: 5),
    longBreakDuration: Duration(minutes: 15),
    sessionsBeforeLongBreak: 4,
  );

  test('keeps task, habit, and marathon sessions independent', () {
    fakeAsync((async) {
      final writer = _RecordingDurationWriter();
      final service = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: _RecordingAlarmScheduler(),
        now: () => DateTime(2026, 9, 8).add(async.elapsed),
      );

      service.create(
        sessionId: 'task-1',
        owner: const TimerSessionOwner.task('task-1'),
        settings: stopwatchSettings,
      );
      service.create(
        sessionId: 'habit-1',
        owner: const TimerSessionOwner.habit('habit-1'),
        settings: stopwatchSettings,
      );
      service.create(
        sessionId: 'marathon',
        owner: const TimerSessionOwner.marathon(),
        settings: stopwatchSettings,
        selectedTaskId: 'task-2',
      );

      service.start('task-1');
      service.start('habit-1');
      service.start('marathon');
      async.elapse(const Duration(seconds: 3));

      expect(service.list(), hasLength(3));
      expect(service.state('task-1')!.elapsedTime, const Duration(seconds: 3));
      expect(service.state('habit-1')!.elapsedTime, const Duration(seconds: 3));
      expect(service.state('marathon')!.selectedTaskId, 'task-2');
    });
  });

  test('pause, resume, work-break, and stop are serialized and flush once', () {
    fakeAsync((async) {
      final writer = _RecordingDurationWriter();
      final service = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: _RecordingAlarmScheduler(),
        now: () => DateTime(2026, 9, 8).add(async.elapsed),
      );
      service.create(
        sessionId: 'task-1',
        owner: const TimerSessionOwner.task('task-1'),
        settings: stopwatchSettings,
      );

      service.start('task-1');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      service.pause('task-1');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      service.resume('task-1');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      Future.wait([service.stop('task-1'), service.stop('task-1')]);
      async.flushMicrotasks();

      expect(writer.writes.map((write) => write.duration.inSeconds), [4]);
      expect(service.state('task-1')!.isRunning, isFalse);
    });
  });

  test('periodic save flushes exactly at ten seconds without stop duplicate',
      () {
    fakeAsync((async) {
      final writer = _RecordingDurationWriter();
      final service = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: _RecordingAlarmScheduler(),
        now: () => DateTime(2026, 9, 8).add(async.elapsed),
      );
      service.create(
        sessionId: 'task-periodic',
        owner: const TimerSessionOwner.task('task-periodic'),
        settings: stopwatchSettings,
      );

      service.start('task-periodic');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();

      expect(writer.writes.map((write) => write.duration.inSeconds), [10]);
      service.stop('task-periodic');
      async.flushMicrotasks();
      expect(writer.writes.map((write) => write.duration.inSeconds), [10]);
    });
  });

  test('restart flushes elapsed time once and starts a fresh stopwatch', () {
    fakeAsync((async) {
      final writer = _RecordingDurationWriter();
      final service = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: _RecordingAlarmScheduler(),
        now: () => DateTime(2026, 9, 8).add(async.elapsed),
      );
      service.create(
        sessionId: 'task-restart',
        owner: const TimerSessionOwner.task('task-restart'),
        settings: stopwatchSettings,
      );
      service.start('task-restart');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));

      service.restart('task-restart');
      async.flushMicrotasks();

      expect(writer.writes.map((write) => write.duration.inSeconds), [5]);
      expect(service.state('task-restart')!.isRunning, isTrue);
      expect(service.state('task-restart')!.elapsedTime, Duration.zero);
    });
  });

  test('task switch flushes the old marathon target before changing it', () {
    fakeAsync((async) {
      final writer = _RecordingDurationWriter();
      final service = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: _RecordingAlarmScheduler(),
        now: () => DateTime(2026, 9, 8).add(async.elapsed),
      );
      service.create(
        sessionId: 'marathon',
        owner: const TimerSessionOwner.marathon(),
        settings: stopwatchSettings,
        selectedTaskId: 'task-1',
      );
      service.start('marathon');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));

      service.selectTask('marathon', 'task-2');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      service.stop('marathon');
      async.flushMicrotasks();

      expect(
          writer.writes
              .map((write) => '${write.targetId}:${write.duration.inSeconds}'),
          ['task-1:2', 'task-2:1']);
    });
  });

  test('work-break transition flushes work duration before starting break', () {
    fakeAsync((async) {
      final writer = _RecordingDurationWriter();
      final service = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: _RecordingAlarmScheduler(),
        now: () => DateTime(2026, 9, 8).add(async.elapsed),
      );
      service.create(
        sessionId: 'task-1',
        owner: const TimerSessionOwner.task('task-1'),
        settings: const TimerSessionSettings(
          mode: TimerSessionMode.pomodoro,
          workDuration: Duration(minutes: 25),
          breakDuration: Duration(minutes: 5),
          longBreakDuration: Duration(minutes: 15),
          sessionsBeforeLongBreak: 4,
        ),
      );
      service.start('task-1');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));

      service.toggleWorkBreak('task-1');
      async.flushMicrotasks();

      expect(writer.writes.single.duration, const Duration(seconds: 3));
      expect(service.state('task-1')!.isWorking, isFalse);
      expect(service.state('task-1')!.isRunning, isTrue);
      expect(
          service.state('task-1')!.remainingTime, const Duration(minutes: 5));
    });
  });

  test('failed save retains pending duration for an explicit retry', () {
    fakeAsync((async) {
      final writer = _RecordingDurationWriter()..shouldFail = true;
      final service = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: _RecordingAlarmScheduler(),
        now: () => DateTime(2026, 9, 8).add(async.elapsed),
      );
      service.create(
        sessionId: 'habit-1',
        owner: const TimerSessionOwner.habit('habit-1'),
        settings: stopwatchSettings,
      );
      service.start('habit-1');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));

      Object? saveError;
      service
          .stop('habit-1')
          .then<void>((_) {}, onError: (Object error) => saveError = error);
      async.flushMicrotasks();
      expect(saveError, isA<StateError>());
      writer.shouldFail = false;
      service.stop('habit-1');
      async.flushMicrotasks();

      expect(writer.writes.single.duration, const Duration(seconds: 2));
    });
  });

  test('splits persisted duration at the local day boundary', () {
    fakeAsync((async) {
      final writer = _RecordingDurationWriter();
      final service = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: _RecordingAlarmScheduler(),
        now: () => DateTime(2026, 9, 8, 23, 59, 58).add(async.elapsed),
      );
      service.create(
        sessionId: 'task-1',
        owner: const TimerSessionOwner.task('task-1'),
        settings: stopwatchSettings,
      );
      service.start('task-1');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 4));
      service.stop('task-1');
      async.flushMicrotasks();

      expect(writer.writes.map((write) => write.recordedAt.day), [8, 9]);
      expect(writer.writes.map((write) => write.duration.inSeconds), [2, 2]);
    });
  });

  test(
      'retry after a partial day-boundary failure does not duplicate the saved day',
      () {
    fakeAsync((async) {
      final writer = _RecordingDurationWriter()..failAtAttempt = 2;
      final service = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: _RecordingAlarmScheduler(),
        now: () => DateTime(2026, 9, 8, 23, 59, 58).add(async.elapsed),
      );
      service.create(
        sessionId: 'task-1',
        owner: const TimerSessionOwner.task('task-1'),
        settings: stopwatchSettings,
      );
      service.start('task-1');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 4));

      Object? saveError;
      service
          .stop('task-1')
          .then<void>((_) {}, onError: (Object error) => saveError = error);
      async.flushMicrotasks();
      expect(saveError, isA<StateError>());
      service.stop('task-1');
      async.flushMicrotasks();

      expect(writer.writes.map((write) => write.recordedAt.day), [8, 9]);
      expect(writer.writes.map((write) => write.duration.inSeconds), [2, 2]);
    });
  });

  test('uses a distinct alarm id for each session', () async {
    final alarms = _RecordingAlarmScheduler();
    final service = TimerSessionService(
      durationWriter: _RecordingDurationWriter(),
      alarmScheduler: alarms,
    );
    const normalSettings = TimerSessionSettings(
      mode: TimerSessionMode.normal,
      workDuration: Duration(minutes: 25),
      breakDuration: Duration(minutes: 5),
      longBreakDuration: Duration(minutes: 15),
      sessionsBeforeLongBreak: 4,
    );
    service.create(
      sessionId: 'task-1',
      owner: const TimerSessionOwner.task('task-1'),
      settings: normalSettings,
    );
    service.create(
      sessionId: 'habit-1',
      owner: const TimerSessionOwner.habit('habit-1'),
      settings: normalSettings,
    );

    await service.start('task-1');
    await service.start('habit-1');

    expect(alarms.scheduledIds, ['timer_alarm:task-1', 'timer_alarm:habit-1']);
  });

  test('shutdown attempts every session flush and reports a save failure', () {
    fakeAsync((async) {
      final writer = _RecordingDurationWriter()..failTargetId = 'task-1';
      final service = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: _RecordingAlarmScheduler(),
        now: () => DateTime(2026, 9, 8).add(async.elapsed),
      );
      service.create(
        sessionId: 'task-1',
        owner: const TimerSessionOwner.task('task-1'),
        settings: stopwatchSettings,
      );
      service.create(
        sessionId: 'habit-1',
        owner: const TimerSessionOwner.habit('habit-1'),
        settings: stopwatchSettings,
      );
      service.start('task-1');
      service.start('habit-1');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));

      Object? shutdownError;
      service
          .shutdown()
          .then<void>((_) {}, onError: (Object error) => shutdownError = error);
      async.flushMicrotasks();

      expect(shutdownError, isA<StateError>());
      expect(writer.writes.map((write) => write.targetId), ['habit-1']);
      expect(service.list().every((state) => !state.isRunning), isTrue);
    });
  });

  test('mediator duration writer persists through a real SQLite repository',
      () async {
    AppDatabase.isTestMode = true;
    final tempDirectory =
        await Directory.systemTemp.createTemp('whph-timer-session-');
    final databaseFile = File('${tempDirectory.path}/timer.sqlite');
    final database = AppDatabase(NativeDatabase(databaseFile));
    final repository = DriftTaskTimeRecordRepository.withDatabase(database);
    final taskEvents = _TaskEvents();
    final mediator = Mediator(Pipeline())
      ..registerHandler<AddTaskTimeRecordCommand,
          AddTaskTimeRecordCommandResponse, AddTaskTimeRecordCommandHandler>(
        () => AddTaskTimeRecordCommandHandler(
          taskTimeRecordRepository: repository,
          taskEvents: taskEvents,
        ),
      );
    final writer = MediatorTimerSessionDurationWriter(
      mediator: mediator,
    );

    try {
      await writer.write(TimerSessionDuration(
        owner: const TimerSessionOwner.task('task-sqlite'),
        targetId: 'task-sqlite',
        duration: const Duration(seconds: 7),
        recordedAt: DateTime(2026, 9, 8, 12),
      ));

      expect(await repository.getTotalDurationByTaskId('task-sqlite'), 7);
      expect(taskEvents.updatedTimeRecords, ['task-sqlite']);
      expect(await databaseFile.length(), greaterThan(0));
    } finally {
      await database.close();
      await tempDirectory.delete(recursive: true);
      AppDatabase.isTestMode = false;
    }
  });
}
