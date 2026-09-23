import 'dart:io';

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_time_record_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/core/application/shared/services/timer_session_service.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/tools/timer_tools.dart';

class _Writer implements ITimerSessionDurationWriter {
  final List<TimerSessionDuration> writes = [];
  bool fail = false;

  @override
  Future<void> write(TimerSessionDuration duration) async {
    if (fail) throw StateError('sensitive database failure');
    writes.add(duration);
  }
}

class _Alarm implements ITimerSessionAlarmScheduler {
  @override
  Future<void> cancel(String alarmId) async {}

  @override
  Future<void> schedule(
      {required String alarmId, required DateTime scheduledAt}) async {}
}

class _TaskEvents extends Fake implements ITaskEvents {
  final List<String> timeUpdates = [];

  @override
  void notifyTaskTimeRecordUpdated(String taskId) => timeUpdates.add(taskId);
}

class _TaskResponse extends Fake implements GetTaskQueryResponse {
  _TaskResponse(this.id, this.modifiedDate);

  @override
  final String id;
  @override
  final DateTime modifiedDate;
  @override
  DateTime get createdDate => modifiedDate;
}

class _HabitResponse extends Fake implements GetHabitQueryResponse {
  _HabitResponse(this.id);

  @override
  final String id;
}

class _Mediator extends Fake implements Mediator {
  _Mediator(this.revisions, {this.habitIds = const {}});

  final Map<String, DateTime> revisions;
  final Set<String> habitIds;

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    final Object value = request;
    if (value is GetSettingQuery) return null as R;
    if (value is GetTaskQuery) {
      final revision = revisions[value.id];
      if (revision == null) throw StateError('missing');
      return _TaskResponse(value.id, revision) as R;
    }
    if (value is GetHabitQuery && habitIds.contains(value.id)) {
      return _HabitResponse(value.id!) as R;
    }
    throw StateError('unexpected request');
  }
}

class _SettingsMediator extends _Mediator {
  _SettingsMediator() : super(const {});

  final List<SaveSettingCommand> saves = [];

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    final Object value = request;
    if (value is SaveSettingCommand) {
      saves.add(value);
      return SaveSettingCommandResponse(
          id: value.key, createdDate: DateTime.utc(2026, 9, 8)) as R;
    }
    return super.send(request);
  }
}

class _ChangingRevisionMediator extends _Mediator {
  _ChangingRevisionMediator(this.initialRevision, this.changedRevision)
      : super(const {});

  final DateTime initialRevision;
  final DateTime changedRevision;
  var reads = 0;

  @override
  Future<R> send<T extends IRequest<R>, R extends Object?>(T request) async {
    final Object value = request;
    if (value is GetTaskQuery) {
      final revision = reads++ == 0 ? initialRevision : changedRevision;
      return _TaskResponse(value.id, revision) as R;
    }
    return super.send(request);
  }
}

RequestHandlerExtra _extra() => RequestHandlerExtra(
      signal: BasicAbortController().signal,
      requestId: 'timer-tools-test',
      sendNotification: (notification, {relatedTask}) async {},
      sendRequest:
          <T extends BaseResultData>(request, resultFactory, options) async =>
              resultFactory(const {}),
    );

McpToolDefinition _tool(List<McpToolDefinition> tools, String name) =>
    tools.singleWhere((tool) => tool.name == name);

void main() {
  test('publishes the complete canonical timer tool family', () {
    final service = TimerSessionService(
        durationWriter: _Writer(), alarmScheduler: _Alarm());
    final tools = buildTimerTools(
      timerSessionService: service,
      mediator: _Mediator(const {}),
      authorize: (extra, scopes) => true,
      selectNextMarathonTask: (selectedTaskId) async => null,
    );

    expect(tools.map((tool) => tool.name), {
      'whph_timers_list',
      'whph_timers_read',
      'whph_timers_start',
      'whph_timers_pause',
      'whph_timers_resume',
      'whph_timers_stop',
      'whph_timers_update_settings',
      'whph_timers_set_phase',
      'whph_marathon_select_task',
      'whph_marathon_advance',
    });
  });

  test('task start binds the canonical session and rechecks owner scope',
      () async {
    final revision = DateTime.utc(2026, 9, 8);
    final service = TimerSessionService(
        durationWriter: _Writer(), alarmScheduler: _Alarm());
    final checkedScopes = <Set<String>>[];
    final tools = buildTimerTools(
      timerSessionService: service,
      mediator: _Mediator({'task-1': revision}),
      authorize: (extra, scopes) {
        checkedScopes.add(Set.unmodifiable(scopes));
        return true;
      },
      selectNextMarathonTask: (selectedTaskId) async => null,
    );

    final result = await _tool(tools, 'whph_timers_start').handler(
      McpToolArguments(const {
        'ownerType': 'task',
        'ownerId': 'task-1',
        'mode': 'stopwatch'
      }),
      _extra(),
    );

    expect(result.isError, isFalse);
    expect(result.structuredContent?['sessionId'], 'task:task-1');
    expect(checkedScopes, contains(equals({'timers:write', 'tasks:write'})));
    expect(service.state('task:task-1')!.isRunning, isTrue);
    final conflictingMode = await _tool(tools, 'whph_timers_start').handler(
      McpToolArguments(
          const {'ownerType': 'task', 'ownerId': 'task-1', 'mode': 'normal'}),
      _extra(),
    );
    expect(conflictingMode.structuredContent?['error'],
        containsPair('code', 'conflict'));
    expect(service.state('task:task-1')!.settings.mode,
        TimerSessionMode.stopwatch);
    await service.stop('task:task-1');
  });

  test('set phase is explicit and idempotent', () async {
    final service = TimerSessionService(
        durationWriter: _Writer(), alarmScheduler: _Alarm());
    final tools = buildTimerTools(
      timerSessionService: service,
      mediator: _Mediator(const {}),
      authorize: (extra, scopes) => true,
      selectNextMarathonTask: (selectedTaskId) async => null,
    );
    await _tool(tools, 'whph_timers_start').handler(
        McpToolArguments(const {'ownerType': 'marathon', 'mode': 'pomodoro'}),
        _extra());

    final work = await _tool(tools, 'whph_timers_set_phase').handler(
        McpToolArguments(const {'sessionId': 'marathon', 'phase': 'work'}),
        _extra());
    final pause = await _tool(tools, 'whph_timers_pause')
        .handler(McpToolArguments(const {'sessionId': 'marathon'}), _extra());
    final breakResult = await _tool(tools, 'whph_timers_set_phase').handler(
        McpToolArguments(const {'sessionId': 'marathon', 'phase': 'break'}),
        _extra());

    expect(work.structuredContent?['phase'], 'work');
    expect(pause.structuredContent?['phase'], 'work');
    expect(breakResult.structuredContent?['phase'], 'break');
    await service.stop('marathon');
  });

  test('habit session uses habit scope and flushes its own target', () {
    fakeAsync((async) {
      final writer = _Writer();
      final service = TimerSessionService(
          durationWriter: writer,
          alarmScheduler: _Alarm(),
          now: () => DateTime(2026, 9, 8).add(async.elapsed));
      final checkedScopes = <Set<String>>[];
      final tools = buildTimerTools(
        timerSessionService: service,
        mediator: _Mediator(const {}, habitIds: const {'habit-1'}),
        authorize: (extra, scopes) {
          checkedScopes.add(Set.unmodifiable(scopes));
          return true;
        },
        selectNextMarathonTask: (selectedTaskId) async => null,
      );
      _tool(tools, 'whph_timers_start').handler(
          McpToolArguments(const {
            'ownerType': 'habit',
            'ownerId': 'habit-1',
            'mode': 'stopwatch'
          }),
          _extra());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      _tool(tools, 'whph_timers_stop').handler(
          McpToolArguments(const {'sessionId': 'habit:habit-1'}), _extra());
      async.flushMicrotasks();

      expect(checkedScopes, contains(equals({'timers:write', 'habits:write'})));
      expect(
          writer.writes
              .map((write) => '${write.targetId}:${write.duration.inSeconds}'),
          ['habit-1:2']);
    });
  });

  test('stale marathon selection and missing dynamic permission fail closed',
      () async {
    final revision = DateTime.utc(2026, 9, 8);
    final service = TimerSessionService(
        durationWriter: _Writer(), alarmScheduler: _Alarm());
    var allowTaskWrites = false;
    final tools = buildTimerTools(
      timerSessionService: service,
      mediator: _Mediator({'task-1': revision}),
      authorize: (extra, scopes) =>
          allowTaskWrites || !scopes.contains('tasks:write'),
      selectNextMarathonTask: (selectedTaskId) async => null,
    );
    final denied = await _tool(tools, 'whph_timers_start').handler(
        McpToolArguments(const {'ownerType': 'task', 'ownerId': 'task-1'}),
        _extra());
    expect(denied.structuredContent?['error'],
        containsPair('code', 'permission_denied'));
    expect(service.state('task:task-1'), isNull);
    allowTaskWrites = true;

    service.create(
      sessionId: 'marathon',
      owner: const TimerSessionOwner.marathon(),
      settings: const TimerSessionSettings(
        mode: TimerSessionMode.stopwatch,
        workDuration: Duration(minutes: 25),
        breakDuration: Duration(minutes: 5),
        longBreakDuration: Duration(minutes: 15),
        sessionsBeforeLongBreak: 4,
      ),
    );
    final stale = await _tool(tools, 'whph_marathon_select_task').handler(
      McpToolArguments(const {
        'sessionId': 'marathon',
        'taskId': 'task-1',
        'expectedTaskRevision': '2026-09-07T00:00:00.000Z'
      }),
      _extra(),
    );
    expect(stale.structuredContent?['error'], containsPair('code', 'conflict'));
  });

  test('marathon selection rechecks revision inside the serialized commit',
      () async {
    final expected = DateTime.utc(2026, 9, 8, 12);
    final mediator = _ChangingRevisionMediator(
        expected, expected.add(const Duration(seconds: 1)));
    final service = TimerSessionService(
        durationWriter: _Writer(), alarmScheduler: _Alarm());
    service.create(
      sessionId: 'marathon',
      owner: const TimerSessionOwner.marathon(),
      settings: const TimerSessionSettings(
        mode: TimerSessionMode.stopwatch,
        workDuration: Duration(minutes: 25),
        breakDuration: Duration(minutes: 5),
        longBreakDuration: Duration(minutes: 15),
        sessionsBeforeLongBreak: 4,
      ),
    );
    final tools = buildTimerTools(
      timerSessionService: service,
      mediator: mediator,
      authorize: (extra, scopes) => true,
      selectNextMarathonTask: (selectedTaskId) async => null,
    );

    final result = await _tool(tools, 'whph_marathon_select_task').handler(
      McpToolArguments({
        'sessionId': 'marathon',
        'taskId': 'task-1',
        'expectedTaskRevision': expected.toIso8601String(),
      }),
      _extra(),
    );

    expect(result.structuredContent?['error'], containsPair('code', 'conflict'));
    expect(service.state('marathon')!.selectedTaskId, isNull);
    expect(mediator.reads, 2);
  });

  test('updates only supplied allowlisted settings and normalizes output',
      () async {
    final mediator = _SettingsMediator();
    final service = TimerSessionService(
        durationWriter: _Writer(), alarmScheduler: _Alarm());
    final tools = buildTimerTools(
      timerSessionService: service,
      mediator: mediator,
      authorize: (extra, scopes) => true,
      selectNextMarathonTask: (selectedTaskId) async => null,
    );

    final result = await _tool(tools, 'whph_timers_update_settings').handler(
      McpToolArguments(const {
        'workMinutes': 30,
        'tickingVolume': 65,
        'defaultMode': 'normal'
      }),
      _extra(),
    );

    expect(result.isError, isFalse);
    expect(result.structuredContent, containsPair('workMinutes', 30));
    expect(result.structuredContent, containsPair('breakMinutes', 5));
    expect(result.structuredContent, containsPair('tickingVolume', 65));
    expect(result.structuredContent, containsPair('defaultMode', 'normal'));
    expect(mediator.saves.map((save) => save.key),
        ['WORK_TIME', 'TICKING_VOLUME', 'DEFAULT_TIMER_MODE']);
  });

  test('repeat stop saves once and sanitizes a failed flush', () {
    fakeAsync((async) {
      final writer = _Writer();
      final service = TimerSessionService(
        durationWriter: writer,
        alarmScheduler: _Alarm(),
        now: () => DateTime(2026, 9, 8).add(async.elapsed),
      );
      final tools = buildTimerTools(
        timerSessionService: service,
        mediator: _Mediator(const {}),
        authorize: (extra, scopes) => true,
        selectNextMarathonTask: (selectedTaskId) async => null,
      );
      service.create(
          sessionId: 'marathon',
          owner: const TimerSessionOwner.marathon(),
          selectedTaskId: 'task-1',
          settings: const TimerSessionSettings(
              mode: TimerSessionMode.stopwatch,
              workDuration: Duration(minutes: 25),
              breakDuration: Duration(minutes: 5),
              longBreakDuration: Duration(minutes: 15),
              sessionsBeforeLongBreak: 4));
      service.start('marathon');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      _tool(tools, 'whph_timers_stop')
          .handler(McpToolArguments(const {'sessionId': 'marathon'}), _extra());
      async.flushMicrotasks();
      _tool(tools, 'whph_timers_stop')
          .handler(McpToolArguments(const {'sessionId': 'marathon'}), _extra());
      async.flushMicrotasks();
      expect(writer.writes.map((write) => write.duration.inSeconds), [3]);

      service.start('marathon');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      writer.fail = true;
      Object? failure;
      Future.sync(() => _tool(tools, 'whph_timers_stop').handler(
              McpToolArguments(const {'sessionId': 'marathon'}), _extra()))
          .then<void>((result) => failure = result.structuredContent);
      async.flushMicrotasks();
      expect(failure.toString(), isNot(contains('sensitive database failure')));
      expect(failure.toString(), contains('operation_failed'));
    });
  });

  test('revocation at stop commit boundary prevents duration persistence', () {
    fakeAsync((async) {
      final writer = _Writer();
      final service = TimerSessionService(
          durationWriter: writer,
          alarmScheduler: _Alarm(),
          now: () => DateTime(2026, 9, 8).add(async.elapsed));
      service.create(
          sessionId: 'marathon',
          owner: const TimerSessionOwner.marathon(),
          selectedTaskId: 'task-1',
          settings: const TimerSessionSettings(
              mode: TimerSessionMode.stopwatch,
              workDuration: Duration(minutes: 25),
              breakDuration: Duration(minutes: 5),
              longBreakDuration: Duration(minutes: 15),
              sessionsBeforeLongBreak: 4));
      service.start('marathon');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      var authorizationChecks = 0;
      final tools = buildTimerTools(
        timerSessionService: service,
        mediator: _Mediator(const {}),
        authorize: (extra, scopes) => ++authorizationChecks == 1,
        selectNextMarathonTask: (selectedTaskId) async => null,
      );
      Object? result;
      Future.sync(() => _tool(tools, 'whph_timers_stop').handler(
              McpToolArguments(const {'sessionId': 'marathon'}), _extra()))
          .then<void>((value) => result = value.structuredContent);
      async.flushMicrotasks();

      expect(result.toString(), contains('permission_denied'));
      expect(writer.writes, isEmpty);
      expect(authorizationChecks, 2);
    });
  });

  test('rejects malformed owners and unknown or mismatched sessions', () async {
    final service = TimerSessionService(
        durationWriter: _Writer(), alarmScheduler: _Alarm());
    final tools = buildTimerTools(
      timerSessionService: service,
      mediator: _Mediator(const {}),
      authorize: (extra, scopes) => true,
      selectNextMarathonTask: (selectedTaskId) async => null,
    );
    final malformed = await _tool(tools, 'whph_timers_start')
        .handler(McpToolArguments(const {'ownerType': 'system'}), _extra());
    final missing = await _tool(tools, 'whph_timers_read').handler(
        McpToolArguments(const {'sessionId': 'task:missing'}), _extra());
    service.create(
        sessionId: 'task:owner',
        owner: const TimerSessionOwner.habit('owner'),
        settings: const TimerSessionSettings(
            mode: TimerSessionMode.stopwatch,
            workDuration: Duration(minutes: 25),
            breakDuration: Duration(minutes: 5),
            longBreakDuration: Duration(minutes: 15),
            sessionsBeforeLongBreak: 4));
    final mismatch = await _tool(tools, 'whph_timers_read')
        .handler(McpToolArguments(const {'sessionId': 'task:owner'}), _extra());

    expect(malformed.structuredContent?['error'],
        containsPair('code', 'validation_error'));
    expect(
        missing.structuredContent?['error'], containsPair('code', 'not_found'));
    expect(mismatch.structuredContent?['error'],
        containsPair('code', 'not_found'));
  });

  test('marathon advance validates and flushes the previous selection once',
      () async {
    final revision = DateTime.utc(2026, 9, 8);
    final writer = _Writer();
    var now = DateTime(2026, 9, 8, 12);
    final service = TimerSessionService(
        durationWriter: writer, alarmScheduler: _Alarm(), now: () => now);
    service.create(
        sessionId: 'marathon',
        owner: const TimerSessionOwner.marathon(),
        selectedTaskId: 'task-1',
        settings: const TimerSessionSettings(
            mode: TimerSessionMode.stopwatch,
            workDuration: Duration(minutes: 25),
            breakDuration: Duration(minutes: 5),
            longBreakDuration: Duration(minutes: 15),
            sessionsBeforeLongBreak: 4));
    final tools = buildTimerTools(
      timerSessionService: service,
      mediator: _Mediator({'task-2': revision}),
      authorize: (extra, scopes) => true,
      selectNextMarathonTask: (selectedTaskId) async => 'task-2',
    );
    await service.start('marathon');
    now = now.add(const Duration(seconds: 3));
    final result = await _tool(tools, 'whph_marathon_advance')
        .handler(McpToolArguments(const {'sessionId': 'marathon'}), _extra());

    expect(result.isError, isFalse);
    expect(result.structuredContent?['selectedTaskId'], 'task-2');
    expect(service.state('marathon')!.selectedTaskId, 'task-2');
    expect(
        writer.writes
            .map((write) => '${write.targetId}:${write.duration.inSeconds}'),
        ['task-1:3']);
    await service.stop('marathon');
  });

  test('real SQLite tool stop persists duration and emits one event', () async {
    AppDatabase.isTestMode = true;
    final directory = await Directory.systemTemp.createTemp('whph-tool-timer-');
    final databaseFile = File('${directory.path}/timer.sqlite');
    final database = AppDatabase(NativeDatabase(databaseFile));
    final repository = DriftTaskTimeRecordRepository.withDatabase(database);
    final events = _TaskEvents();
    final mediator = Mediator(Pipeline())
      ..registerHandler<AddTaskTimeRecordCommand,
          AddTaskTimeRecordCommandResponse, AddTaskTimeRecordCommandHandler>(
        () => AddTaskTimeRecordCommandHandler(
            taskTimeRecordRepository: repository, taskEvents: events),
      );
    var now = DateTime(2026, 9, 8, 12);
    final service = TimerSessionService(
        durationWriter: MediatorTimerSessionDurationWriter(mediator: mediator),
        alarmScheduler: _Alarm(),
        now: () => now);
    final tools = buildTimerTools(
      timerSessionService: service,
      mediator: mediator,
      authorize: (extra, scopes) => true,
      selectNextMarathonTask: (selectedTaskId) async => null,
    );
    try {
      service.create(
          sessionId: 'marathon',
          owner: const TimerSessionOwner.marathon(),
          selectedTaskId: 'sqlite-task',
          settings: const TimerSessionSettings(
              mode: TimerSessionMode.stopwatch,
              workDuration: Duration(minutes: 25),
              breakDuration: Duration(minutes: 5),
              longBreakDuration: Duration(minutes: 15),
              sessionsBeforeLongBreak: 4));
      await service.start('marathon');
      now = now.add(const Duration(seconds: 7));

      final result = await _tool(tools, 'whph_timers_stop')
          .handler(McpToolArguments(const {'sessionId': 'marathon'}), _extra());

      expect(result.isError, isFalse);
      expect(result.structuredContent?['savedDurationSeconds'], 7);
      expect(await repository.getTotalDurationByTaskId('sqlite-task'), 7);
      expect(events.timeUpdates, ['sqlite-task']);
      expect(await databaseFile.length(), greaterThan(0));
    } finally {
      await database.close();
      await directory.delete(recursive: true);
      AppDatabase.isTestMode = false;
    }
  });
}
