import 'package:acore/acore.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/mcp/mcp_tool_registry.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';

typedef MarathonTaskSelector = Future<String?> Function(
  String? selectedTaskId,
);

List<McpToolDefinition> buildTimerTools({
  required ITimerSessionService timerSessionService,
  required Mediator mediator,
  required McpToolAuthorizer authorize,
  required MarathonTaskSelector selectNextMarathonTask,
}) =>
    List.unmodifiable([
      _tool('whph_timers_list', 'List active timer sessions.', _listInput, _sessionsOutput,
          const {McpScopes.timersRead}, _read, (args, extra) => _list(timerSessionService, args)),
      _tool('whph_timers_read', 'Read one timer session.', _sessionInput, _stateOutput, const {McpScopes.timersRead},
          _read, (args, extra) => _readState(timerSessionService, args)),
      _tool(
          'whph_timers_start',
          'Start an owner-bound timer session.',
          _startInput,
          _stateOutput,
          const {McpScopes.timersWrite},
          _add,
          (args, extra) => _start(timerSessionService, mediator, authorize, args, extra)),
      _tool('whph_timers_pause', 'Pause a timer session.', _sessionInput, _stateOutput, const {McpScopes.timersWrite},
          _mutate, (args, extra) => _control(timerSessionService, authorize, args, extra, timerSessionService.pause)),
      _tool(
          'whph_timers_resume',
          'Resume a paused timer session.',
          _sessionInput,
          _stateOutput,
          const {McpScopes.timersWrite},
          _mutate,
          (args, extra) => _control(timerSessionService, authorize, args, extra, timerSessionService.resume)),
      _tool('whph_timers_stop', 'Stop a timer and flush its recorded duration.', _sessionInput, _stopOutput,
          const {McpScopes.timersWrite}, _destroy, (args, extra) => _stop(timerSessionService, authorize, args, extra)),
      _tool(
          'whph_timers_update_settings',
          'Update allowlisted timer settings and active sessions.',
          _settingsInput,
          _settingsOutput,
          const {McpScopes.timersWrite, McpScopes.settingsWrite},
          _mutate,
          (args, extra) => _updateSettings(timerSessionService, mediator, authorize, args, extra)),
      _tool(
          'whph_timers_set_phase',
          'Set the explicit work or break phase.',
          _phaseInput,
          _stateOutput,
          const {McpScopes.timersWrite},
          _mutate,
          (args, extra) => _setPhase(timerSessionService, authorize, args, extra)),
      _tool(
          'whph_marathon_select_task',
          'Select a revision-matched task for the marathon timer.',
          _selectInput,
          _stateOutput,
          const {McpScopes.timersWrite, McpScopes.tasksWrite},
          _mutate,
          (args, extra) => _selectTask(timerSessionService, mediator, authorize, args, extra)),
      _tool(
          'whph_marathon_advance',
          'Advance the marathon timer to the next available task.',
          _sessionInput,
          _stateOutput,
          const {McpScopes.timersWrite, McpScopes.tasksWrite},
          _destroy,
          (args, extra) => _advance(timerSessionService, mediator, authorize, selectNextMarathonTask, args, extra)),
    ]);

Future<CallToolResult> _list(ITimerSessionService service, McpToolArguments args) => _run(() async {
      final ownerType = args.optionalString('ownerType');
      final filter = ownerType == null ? null : _parseOwnerType(ownerType);
      return {
        'sessions': service
            .list()
            .where((state) => filter == null || state.owner.type == filter)
            .map(_stateJson)
            .toList(growable: false),
      };
    });

Future<CallToolResult> _readState(ITimerSessionService service, McpToolArguments args) =>
    _run(() async => _stateJson(_requireState(service, args)));

Future<CallToolResult> _start(
  ITimerSessionService service,
  Mediator mediator,
  McpToolAuthorizer authorize,
  McpToolArguments args,
  RequestHandlerExtra extra,
) =>
    _run(() async {
      final owner = _owner(args);
      final scopes = _writeScopes(owner);
      await _guard(authorize, extra, scopes);
      await _validateOwner(mediator, owner);
      final settings = await _readSettings(mediator);
      final requestedMode = args.optionalString('mode');
      final sessionSettings = settings.sessionSettings(
        mode: requestedMode == null ? null : _parseMode(requestedMode),
      );
      await _guard(authorize, extra, scopes);
      final sessionId = _sessionId(owner);
      final existing = service.state(sessionId);
      if (requestedMode != null && existing != null && existing.settings.mode != sessionSettings.mode) {
        throw const _TimerConflict();
      }
      service.create(sessionId: sessionId, owner: owner, settings: sessionSettings);
      return _stateJson(await service.start(sessionId));
    });

Future<CallToolResult> _control(
  ITimerSessionService service,
  McpToolAuthorizer authorize,
  McpToolArguments args,
  RequestHandlerExtra extra,
  Future<TimerSessionState> Function(String sessionId) operation,
) =>
    _run(() async {
      final state = _requireState(service, args);
      await _guard(authorize, extra, const {McpScopes.timersWrite});
      return _stateJson(await operation(state.sessionId));
    });

Future<CallToolResult> _stop(
  ITimerSessionService service,
  McpToolAuthorizer authorize,
  McpToolArguments args,
  RequestHandlerExtra extra,
) =>
    _run(() async {
      final current = _requireState(service, args);
      final scopes = _stopScopes(current);
      await _guard(authorize, extra, scopes);
      final stopped = await service.stop(current.sessionId, beforeCommit: () => _guard(authorize, extra, scopes));
      return {
        'session': current.sessionId,
        'state': _stateJson(stopped),
        'savedDurationSeconds': stopped.sessionTotalElapsed.inSeconds,
      };
    });

Future<CallToolResult> _setPhase(
  ITimerSessionService service,
  McpToolAuthorizer authorize,
  McpToolArguments args,
  RequestHandlerExtra extra,
) =>
    _run(() async {
      final state = _requireState(service, args);
      final phase = args.requireString('phase');
      if (phase != 'work' && phase != 'break') throw _validation('phase');
      await _guard(authorize, extra, const {McpScopes.timersWrite});
      final wantsWork = phase == 'work';
      if (state.isWorking == wantsWork) return _stateJson(state);
      return _stateJson(await service.toggleWorkBreak(state.sessionId,
          beforeCommit: () => _guard(authorize, extra, const {McpScopes.timersWrite})));
    });

Future<CallToolResult> _selectTask(
  ITimerSessionService service,
  Mediator mediator,
  McpToolAuthorizer authorize,
  McpToolArguments args,
  RequestHandlerExtra extra,
) =>
    _run(() async {
      final state = _requireMarathon(service, args);
      final taskId = _nonEmpty(args.requireString('taskId'), 'taskId');
      final expected = _revision(args.requireString('expectedTaskRevision'));
      await _guard(authorize, extra, const {McpScopes.timersWrite, McpScopes.tasksWrite});
      final task = await _task(mediator, taskId);
      if (!_sameRevision(task.modifiedDate ?? task.createdDate, expected)) {
        throw const _TimerConflict();
      }
      return _stateJson(await service.selectTask(
        state.sessionId,
        taskId,
        beforeCommit: () async {
          await _guard(authorize, extra, const {McpScopes.timersWrite, McpScopes.tasksWrite});
          final currentTask = await _task(mediator, taskId);
          if (!_sameRevision(currentTask.modifiedDate ?? currentTask.createdDate, expected)) {
            throw const _TimerConflict();
          }
        },
      ));
    });

Future<CallToolResult> _advance(
  ITimerSessionService service,
  Mediator mediator,
  McpToolAuthorizer authorize,
  MarathonTaskSelector selector,
  McpToolArguments args,
  RequestHandlerExtra extra,
) =>
    _run(() async {
      final state = _requireMarathon(service, args);
      await _guard(authorize, extra, const {McpScopes.timersWrite, McpScopes.tasksWrite});
      final nextTaskId = await selector(state.selectedTaskId);
      if (nextTaskId != null) await _task(mediator, nextTaskId);
      return _stateJson(await service.selectTask(state.sessionId, nextTaskId,
          beforeCommit: () => _guard(authorize, extra, const {McpScopes.timersWrite, McpScopes.tasksWrite})));
    });

Future<CallToolResult> _updateSettings(
  ITimerSessionService service,
  Mediator mediator,
  McpToolAuthorizer authorize,
  McpToolArguments args,
  RequestHandlerExtra extra,
) =>
    _run(() async {
      final current = await _readSettings(mediator);
      final next = current.patch(args);
      await _guard(authorize, extra, const {McpScopes.timersWrite, McpScopes.settingsWrite});
      await next.persistChanges(mediator, args);
      for (final state in service.list()) {
        await service.updateSettings(state.sessionId, next.sessionSettings(mode: state.settings.mode));
      }
      return next.toJson();
    });

TimerSessionState _requireState(ITimerSessionService service, McpToolArguments args) {
  final sessionId = _nonEmpty(args.requireString('sessionId'), 'sessionId');
  final state = service.state(sessionId);
  if (state == null) throw const _TimerNotFound();
  if (_sessionId(state.owner) != sessionId) throw const _TimerNotFound();
  return state;
}

TimerSessionState _requireMarathon(ITimerSessionService service, McpToolArguments args) {
  final state = _requireState(service, args);
  if (state.owner.type != TimerSessionOwnerType.marathon) {
    throw _validation('sessionId');
  }
  return state;
}

TimerSessionOwner _owner(McpToolArguments args) {
  final type = _parseOwnerType(args.requireString('ownerType'));
  final ownerId = args.optionalString('ownerId');
  return switch (type) {
    TimerSessionOwnerType.task => TimerSessionOwner.task(_nonEmpty(ownerId, 'ownerId')),
    TimerSessionOwnerType.habit => TimerSessionOwner.habit(_nonEmpty(ownerId, 'ownerId')),
    TimerSessionOwnerType.marathon =>
      ownerId == null ? const TimerSessionOwner.marathon() : throw _validation('ownerId'),
  };
}

Future<void> _validateOwner(Mediator mediator, TimerSessionOwner owner) async {
  switch (owner.type) {
    case TimerSessionOwnerType.task:
      await _task(mediator, owner.ownerId);
    case TimerSessionOwnerType.habit:
      await mediator.send<GetHabitQuery, GetHabitQueryResponse>(GetHabitQuery(id: owner.ownerId));
    case TimerSessionOwnerType.marathon:
      return;
  }
}

Future<GetTaskQueryResponse> _task(Mediator mediator, String id) =>
    mediator.send<GetTaskQuery, GetTaskQueryResponse>(GetTaskQuery(id: id));

Set<String> _writeScopes(TimerSessionOwner owner) => {
      McpScopes.timersWrite,
      if (owner.type == TimerSessionOwnerType.task) McpScopes.tasksWrite,
      if (owner.type == TimerSessionOwnerType.habit) McpScopes.habitsWrite,
    };

Set<String> _stopScopes(TimerSessionState state) => {
      ..._writeScopes(state.owner),
      if (state.owner.type == TimerSessionOwnerType.marathon && state.selectedTaskId != null) McpScopes.tasksWrite,
    };

Future<void> _guard(McpToolAuthorizer authorize, RequestHandlerExtra extra, Set<String> scopes) async {
  if (!await authorize(extra, scopes)) {
    throw McpToolException(McpToolError(
        code: McpToolErrorCode.permissionDenied, message: 'The connection is not permitted to use this tool.'));
  }
}

Future<CallToolResult> _run(Future<Map<String, dynamic>> Function() operation) async {
  try {
    return McpToolResult.success(await operation());
  } on McpToolException catch (error) {
    return McpToolResult.failure(error.error);
  } on _TimerNotFound {
    return McpToolResult.failure(
        McpToolError(code: McpToolErrorCode.notFound, message: 'The timer target was not found.'));
  } on _TimerConflict {
    return McpToolResult.failure(
        McpToolError(code: McpToolErrorCode.conflict, message: 'The timer state conflicts with the request.'));
  } on BusinessException {
    return McpToolResult.failure(
        McpToolError(code: McpToolErrorCode.notFound, message: 'The timer target was not found.'));
  } on ArgumentError {
    return McpToolResult.failure(
        McpToolError(code: McpToolErrorCode.validationError, message: 'The request is invalid.'));
  } on StateError {
    return McpToolResult.failure(
        McpToolError(code: McpToolErrorCode.operationFailed, message: 'The timer operation failed.'));
  } catch (_) {
    return McpToolResult.failure(
        McpToolError(code: McpToolErrorCode.operationFailed, message: 'The operation failed.'));
  }
}

class _TimerNotFound implements Exception {
  const _TimerNotFound();
}

class _TimerConflict implements Exception {
  const _TimerConflict();
}

final class _TimerToolSettings {
  const _TimerToolSettings({
    required this.workMinutes,
    required this.breakMinutes,
    required this.longBreakMinutes,
    required this.sessionsBeforeLongBreak,
    required this.autoStartBreak,
    required this.autoStartWork,
    required this.tickingEnabled,
    required this.tickingVolume,
    required this.tickingSpeed,
    required this.keepScreenAwake,
    required this.defaultMode,
  });

  final int workMinutes;
  final int breakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;
  final bool autoStartBreak;
  final bool autoStartWork;
  final bool tickingEnabled;
  final int tickingVolume;
  final int tickingSpeed;
  final bool keepScreenAwake;
  final TimerSessionMode defaultMode;

  TimerSessionSettings sessionSettings({TimerSessionMode? mode}) => TimerSessionSettings(
      mode: mode ?? defaultMode,
      workDuration: Duration(minutes: workMinutes),
      breakDuration: Duration(minutes: breakMinutes),
      longBreakDuration: Duration(minutes: longBreakMinutes),
      sessionsBeforeLongBreak: sessionsBeforeLongBreak,
      autoStartBreak: autoStartBreak,
      autoStartWork: autoStartWork);

  _TimerToolSettings patch(McpToolArguments args) {
    final next = _TimerToolSettings(
      workMinutes: args.optionalInt('workMinutes') ?? workMinutes,
      breakMinutes: args.optionalInt('breakMinutes') ?? breakMinutes,
      longBreakMinutes: args.optionalInt('longBreakMinutes') ?? longBreakMinutes,
      sessionsBeforeLongBreak: args.optionalInt('sessionsBeforeLongBreak') ?? sessionsBeforeLongBreak,
      autoStartBreak: args.optionalBool('autoStartBreak') ?? autoStartBreak,
      autoStartWork: args.optionalBool('autoStartWork') ?? autoStartWork,
      tickingEnabled: args.optionalBool('tickingEnabled') ?? tickingEnabled,
      tickingVolume: args.optionalInt('tickingVolume') ?? tickingVolume,
      tickingSpeed: args.optionalInt('tickingSpeed') ?? tickingSpeed,
      keepScreenAwake: args.optionalBool('keepScreenAwake') ?? keepScreenAwake,
      defaultMode:
          args.optionalString('defaultMode') == null ? defaultMode : _parseMode(args.requireString('defaultMode')),
    );
    if (next.workMinutes <= 0 ||
        next.breakMinutes <= 0 ||
        next.longBreakMinutes <= 0 ||
        next.sessionsBeforeLongBreak <= 0 ||
        next.tickingVolume < 5 ||
        next.tickingVolume > 100 ||
        next.tickingSpeed <= 0) throw _validation('settings');
    return next;
  }

  Future<void> persistChanges(Mediator mediator, McpToolArguments args) async {
    final writes = <Future<Object?>>[];
    void save(String field, String key, Object value, SettingValueType type) {
      if (!args.contains(field)) return;
      writes.add(mediator.send(SaveSettingCommand(key: key, value: '$value', valueType: type)));
    }

    save('workMinutes', SettingKeys.workTime, workMinutes, SettingValueType.int);
    save('breakMinutes', SettingKeys.breakTime, breakMinutes, SettingValueType.int);
    save('longBreakMinutes', SettingKeys.longBreakTime, longBreakMinutes, SettingValueType.int);
    save('sessionsBeforeLongBreak', SettingKeys.sessionsBeforeLongBreak, sessionsBeforeLongBreak, SettingValueType.int);
    save('autoStartBreak', SettingKeys.autoStartBreak, autoStartBreak, SettingValueType.bool);
    save('autoStartWork', SettingKeys.autoStartWork, autoStartWork, SettingValueType.bool);
    save('tickingEnabled', SettingKeys.tickingEnabled, tickingEnabled, SettingValueType.bool);
    save('tickingVolume', SettingKeys.tickingVolume, tickingVolume, SettingValueType.int);
    save('tickingSpeed', SettingKeys.tickingSpeed, tickingSpeed, SettingValueType.int);
    save('keepScreenAwake', SettingKeys.keepScreenAwake, keepScreenAwake, SettingValueType.bool);
    save('defaultMode', SettingKeys.defaultTimerMode, defaultMode.name, SettingValueType.string);
    await Future.wait(writes);
  }

  Map<String, dynamic> toJson() => {
        'workMinutes': workMinutes,
        'breakMinutes': breakMinutes,
        'longBreakMinutes': longBreakMinutes,
        'sessionsBeforeLongBreak': sessionsBeforeLongBreak,
        'autoStartBreak': autoStartBreak,
        'autoStartWork': autoStartWork,
        'tickingEnabled': tickingEnabled,
        'tickingVolume': tickingVolume,
        'tickingSpeed': tickingSpeed,
        'keepScreenAwake': keepScreenAwake,
        'defaultMode': defaultMode.name,
      };
}

Future<_TimerToolSettings> _readSettings(Mediator mediator) async {
  Future<T> value<T>(String key, T fallback) async {
    final setting = await mediator.send<GetSettingQuery, GetSettingQueryResponse?>(GetSettingQuery(key: key));
    return setting?.getValue<T>() ?? fallback;
  }

  return _TimerToolSettings(
    workMinutes: await value(SettingKeys.workTime, 25),
    breakMinutes: await value(SettingKeys.breakTime, 5),
    longBreakMinutes: await value(SettingKeys.longBreakTime, 15),
    sessionsBeforeLongBreak: await value(SettingKeys.sessionsBeforeLongBreak, 4),
    autoStartBreak: await value(SettingKeys.autoStartBreak, false),
    autoStartWork: await value(SettingKeys.autoStartWork, false),
    tickingEnabled: await value(SettingKeys.tickingEnabled, false),
    tickingVolume: await value(SettingKeys.tickingVolume, 50),
    tickingSpeed: await value(SettingKeys.tickingSpeed, 1),
    keepScreenAwake: await value(SettingKeys.keepScreenAwake, false),
    defaultMode: _parseMode(await value(SettingKeys.defaultTimerMode, 'pomodoro')),
  );
}

Map<String, dynamic> _stateJson(TimerSessionState state) => {
      'sessionId': state.sessionId,
      'ownerType': state.owner.type.name,
      'ownerId': state.owner.ownerId,
      'selectedTaskId': state.selectedTaskId,
      'mode': state.settings.mode.name,
      'phase': state.isWorking ? 'work' : 'break',
      'isRunning': state.isRunning,
      'isAlarmPlaying': state.isAlarmPlaying,
      'isLongBreak': state.isLongBreak,
      'remainingSeconds': state.remainingTime.inSeconds,
      'elapsedSeconds': state.elapsedTime.inSeconds,
      'sessionTotalElapsedSeconds': state.sessionTotalElapsed.inSeconds,
      'currentWorkSessionElapsedSeconds': state.currentWorkSessionElapsed.inSeconds,
      'completedSessions': state.completedSessions,
    };

TimerSessionOwnerType _parseOwnerType(String value) =>
    TimerSessionOwnerType.values.firstWhere((type) => type.name == value, orElse: () => throw _validation('ownerType'));
TimerSessionMode _parseMode(String value) =>
    TimerSessionMode.values.firstWhere((mode) => mode.name == value, orElse: () => throw _validation('mode'));
String _sessionId(TimerSessionOwner owner) => switch (owner.type) {
      TimerSessionOwnerType.task => 'task:${owner.ownerId}',
      TimerSessionOwnerType.habit => 'habit:${owner.ownerId}',
      TimerSessionOwnerType.marathon => 'marathon',
    };
String _nonEmpty(String? value, String field) {
  if (value == null || value.trim().isEmpty) throw _validation(field);
  return value;
}

DateTime _revision(String value) {
  final revision = DateTime.tryParse(value);
  if (revision == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw _validation('expectedTaskRevision');
  }
  return revision.toUtc();
}

bool _sameRevision(DateTime actual, DateTime expected) =>
    actual.toUtc().millisecondsSinceEpoch ~/ 1000 == expected.millisecondsSinceEpoch ~/ 1000;

McpToolException _validation(String field) => McpToolException(McpToolError(
    code: McpToolErrorCode.validationError, message: 'Argument "$field" is invalid.', details: {'field': field}));

McpToolDefinition _tool(String name, String description, JsonObject input, JsonObject output, Set<String> scopes,
        ToolAnnotations annotations, McpToolHandler handler) =>
    McpToolDefinition(
        name: name,
        description: description,
        inputSchema: input,
        outputSchema: output,
        annotations: annotations,
        requiredScopes: scopes,
        handler: handler);

const _read = ToolAnnotations(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false);
const _add = ToolAnnotations(destructiveHint: false, idempotentHint: false, openWorldHint: false);
const _mutate = ToolAnnotations(destructiveHint: true, idempotentHint: true, openWorldHint: false);
const _destroy = ToolAnnotations(destructiveHint: true, idempotentHint: false, openWorldHint: false);

JsonObject _closed(Map<String, JsonSchema> properties, [List<String>? required]) =>
    JsonSchema.object(properties: properties, required: required, additionalProperties: false);
final _ownerType = JsonSchema.string(enumValues: ['task', 'habit', 'marathon']);
final _mode = JsonSchema.string(enumValues: ['pomodoro', 'normal', 'stopwatch']);
final _sessionInput = _closed({'sessionId': JsonSchema.string(minLength: 1)}, ['sessionId']);
final _listInput = _closed({'ownerType': _ownerType});
final _startInput = _closed({
  'ownerType': _ownerType,
  'ownerId': JsonSchema.string(minLength: 1),
  'mode': _mode,
}, [
  'ownerType'
]);
final _phaseInput = _closed({
  'sessionId': JsonSchema.string(minLength: 1),
  'phase': JsonSchema.string(enumValues: ['work', 'break']),
}, [
  'sessionId',
  'phase'
]);
final _selectInput = _closed({
  'sessionId': JsonSchema.string(minLength: 1),
  'taskId': JsonSchema.string(minLength: 1),
  'expectedTaskRevision': JsonSchema.string(format: 'date-time'),
}, [
  'sessionId',
  'taskId',
  'expectedTaskRevision'
]);
final _nullableString = JsonSchema.anyOf([JsonSchema.string(), JsonSchema.nullValue()]);
final _stateOutput = _closed({
  'sessionId': JsonSchema.string(),
  'ownerType': _ownerType,
  'ownerId': JsonSchema.string(),
  'selectedTaskId': _nullableString,
  'mode': _mode,
  'phase': JsonSchema.string(enumValues: ['work', 'break']),
  'isRunning': JsonSchema.boolean(),
  'isAlarmPlaying': JsonSchema.boolean(),
  'isLongBreak': JsonSchema.boolean(),
  'remainingSeconds': JsonSchema.integer(),
  'elapsedSeconds': JsonSchema.integer(),
  'sessionTotalElapsedSeconds': JsonSchema.integer(),
  'currentWorkSessionElapsedSeconds': JsonSchema.integer(),
  'completedSessions': JsonSchema.integer(),
}, [
  'sessionId',
  'ownerType',
  'ownerId',
  'selectedTaskId',
  'mode',
  'phase',
  'isRunning',
  'isAlarmPlaying',
  'isLongBreak',
  'remainingSeconds',
  'elapsedSeconds',
  'sessionTotalElapsedSeconds',
  'currentWorkSessionElapsedSeconds',
  'completedSessions'
]);
final _sessionsOutput = _closed({'sessions': JsonSchema.array(items: _stateOutput)}, ['sessions']);
final _stopOutput = _closed({
  'session': JsonSchema.string(),
  'state': _stateOutput,
  'savedDurationSeconds': JsonSchema.integer(),
}, [
  'session',
  'state',
  'savedDurationSeconds'
]);
final _settingsFields = <String, JsonSchema>{
  'workMinutes': JsonSchema.integer(minimum: 1),
  'breakMinutes': JsonSchema.integer(minimum: 1),
  'longBreakMinutes': JsonSchema.integer(minimum: 1),
  'sessionsBeforeLongBreak': JsonSchema.integer(minimum: 1),
  'autoStartBreak': JsonSchema.boolean(),
  'autoStartWork': JsonSchema.boolean(),
  'tickingEnabled': JsonSchema.boolean(),
  'tickingVolume': JsonSchema.integer(minimum: 5, maximum: 100),
  'tickingSpeed': JsonSchema.integer(minimum: 1),
  'keepScreenAwake': JsonSchema.boolean(),
  'defaultMode': _mode,
};
final _settingsInput = _closed(_settingsFields);
final _settingsOutput = _closed(_settingsFields, _settingsFields.keys.toList());
