import 'dart:async';

import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_time_record_command.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_time_record_command.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

class MediatorTimerSessionDurationWriter implements ITimerSessionDurationWriter {
  final Mediator _mediator;

  const MediatorTimerSessionDurationWriter({
    required Mediator mediator,
  }) : _mediator = mediator;

  @override
  Future<void> write(TimerSessionDuration duration) async {
    switch (duration.owner.type) {
      case TimerSessionOwnerType.task:
      case TimerSessionOwnerType.marathon:
        await _mediator.send<AddTaskTimeRecordCommand, AddTaskTimeRecordCommandResponse>(
          AddTaskTimeRecordCommand(
            taskId: duration.targetId,
            duration: duration.duration.inSeconds,
            customDateTime: duration.recordedAt,
          ),
        );
      case TimerSessionOwnerType.habit:
        await _mediator.send<AddHabitTimeRecordCommand, AddHabitTimeRecordCommandResponse>(
          AddHabitTimeRecordCommand(
            habitId: duration.targetId,
            duration: duration.duration.inSeconds,
            customDateTime: duration.recordedAt,
          ),
        );
    }
  }
}

class TimerSessionService implements ITimerSessionService {
  static const _tickInterval = Duration(seconds: 1);
  static const _periodicSaveInterval = Duration(seconds: 10);
  static const _alarmPrefix = 'timer_alarm:';

  final ITimerSessionDurationWriter _durationWriter;
  final ITimerSessionAlarmScheduler _alarmScheduler;
  final DateTime Function() _now;
  final StreamController<TimerSessionState> _changes = StreamController.broadcast();
  Map<String, _TimerSession> _sessions = const {};
  Map<String, Future<void>> _operationQueues = const {};

  TimerSessionService({
    required ITimerSessionDurationWriter durationWriter,
    required ITimerSessionAlarmScheduler alarmScheduler,
    DateTime Function()? now,
  })  : _durationWriter = durationWriter,
        _alarmScheduler = alarmScheduler,
        _now = now ?? DateTime.now;

  @override
  Stream<TimerSessionState> get changes => _changes.stream;

  @override
  TimerSessionState create({
    required String sessionId,
    required TimerSessionOwner owner,
    required TimerSessionSettings settings,
    String? selectedTaskId,
  }) {
    _validateSession(sessionId, owner, settings, selectedTaskId);
    final existing = _sessions[sessionId];
    if (existing != null) {
      if (existing.state.owner.type != owner.type || existing.state.owner.ownerId != owner.ownerId) {
        throw StateError('Timer session "$sessionId" already belongs to another owner');
      }
      return existing.state;
    }

    final session = _TimerSession.initial(
      sessionId: sessionId,
      owner: owner,
      settings: settings,
      selectedTaskId: selectedTaskId,
    );
    _replaceSession(sessionId, session);
    return session.state;
  }

  @override
  List<TimerSessionState> list() => List.unmodifiable(_sessions.values.map((session) => session.state));

  @override
  TimerSessionState? state(String sessionId) => _sessions[sessionId]?.state;

  @override
  Future<TimerSessionState> start(String sessionId) => _serialize(sessionId, () => _start(sessionId));

  Future<TimerSessionState> _start(String sessionId) async {
    var session = _requireSession(sessionId);
    if (session.state.isRunning) return session.state;

    final isFresh = !session.isPaused;
    final now = _now();
    final freshRemaining = session.state.isWorking
        ? session.state.settings.workDuration
        : (session.state.isLongBreak ? session.state.settings.longBreakDuration : session.state.settings.breakDuration);
    session = session.copyWith(
      state: _copyState(
        session.state,
        isRunning: true,
        isAlarmPlaying: false,
        remainingTime: isFresh ? freshRemaining : session.state.remainingTime,
        elapsedTime: isFresh && session.state.settings.mode == TimerSessionMode.stopwatch
            ? Duration.zero
            : session.state.elapsedTime,
        sessionTotalElapsed: isFresh ? Duration.zero : session.state.sessionTotalElapsed,
        currentWorkSessionElapsed: isFresh ? Duration.zero : session.state.currentWorkSessionElapsed,
      ),
      isPaused: false,
      lastTickAt: now,
    );
    session = session.copyWith(timer: Timer.periodic(_tickInterval, (_) => _tick(sessionId)));
    _replaceSession(sessionId, session);
    await _scheduleAlarm(session);
    return session.state;
  }

  @override
  Future<TimerSessionState> pause(String sessionId) => _serialize(sessionId, () async {
        var session = _requireSession(sessionId);
        if (!session.state.isRunning) return session.state;
        session = _applyElapsed(session, _now());
        session.timer?.cancel();
        session = session.copyWith(
          state: _copyState(session.state, isRunning: false),
          timer: null,
          clearTimer: true,
          lastTickAt: null,
          clearLastTickAt: true,
          isPaused: true,
        );
        _replaceSession(sessionId, session);
        await _cancelAlarm(sessionId);
        return session.state;
      });

  @override
  Future<TimerSessionState> resume(String sessionId) => start(sessionId);

  @override
  Future<TimerSessionState> restart(String sessionId) => _serialize(sessionId, () async {
        await _stop(sessionId, null);
        return _start(sessionId);
      });

  @override
  Future<TimerSessionState> stop(
    String sessionId, {
    Future<void> Function()? beforeCommit,
  }) =>
      _serialize(sessionId, () => _stop(sessionId, beforeCommit));

  Future<TimerSessionState> _stop(String sessionId, Future<void> Function()? beforeCommit) async {
    var session = _requireSession(sessionId);
    if (session.state.isRunning) session = _applyElapsed(session, _now());
    session.timer?.cancel();
    session = session.copyWith(
      state: _copyState(session.state, isRunning: false, isAlarmPlaying: false),
      timer: null,
      clearTimer: true,
      lastTickAt: null,
      clearLastTickAt: true,
      isPaused: false,
    );
    _replaceSession(sessionId, session);
    await _cancelAlarm(sessionId);
    await beforeCommit?.call();
    await _flush(sessionId);
    session = _requireSession(sessionId);
    final resetState = _copyState(
      session.state,
      isWorking: true,
      isLongBreak: false,
      elapsedTime:
          session.state.settings.mode == TimerSessionMode.stopwatch ? Duration.zero : session.state.elapsedTime,
      remainingTime: session.state.settings.workDuration,
      currentWorkSessionElapsed: Duration.zero,
      completedSessions: 0,
    );
    _replaceSession(sessionId, session.copyWith(state: resetState));
    return resetState;
  }

  @override
  Future<TimerSessionState> toggleWorkBreak(
    String sessionId, {
    Future<void> Function()? beforeCommit,
  }) =>
      _serialize(sessionId, () async {
        var session = _requireSession(sessionId);
        if (session.state.settings.mode != TimerSessionMode.pomodoro) {
          throw StateError('Work/break transitions require pomodoro mode');
        }
        await beforeCommit?.call();
        if (session.state.isRunning) session = _applyElapsed(session, _now());
        session.timer?.cancel();
        _replaceSession(sessionId, session.copyWith(timer: null, clearTimer: true));
        await _cancelAlarm(sessionId);
        if (session.state.isWorking) await _flush(sessionId);

        session = _requireSession(sessionId);
        final nextCompletedSessions =
            session.state.isWorking ? session.state.completedSessions + 1 : session.state.completedSessions;
        final isLongBreak =
            session.state.isWorking && nextCompletedSessions >= session.state.settings.sessionsBeforeLongBreak;
        final nextIsWorking = !session.state.isWorking;
        final nextState = _copyState(
          session.state,
          isRunning: false,
          isWorking: nextIsWorking,
          isAlarmPlaying: false,
          isLongBreak: isLongBreak,
          remainingTime: nextIsWorking
              ? session.state.settings.workDuration
              : (isLongBreak ? session.state.settings.longBreakDuration : session.state.settings.breakDuration),
          currentWorkSessionElapsed: Duration.zero,
          completedSessions: isLongBreak ? 0 : nextCompletedSessions,
        );
        _replaceSession(sessionId, session.copyWith(state: nextState, isPaused: false));
        return _start(sessionId);
      });

  @override
  Future<TimerSessionState> selectTask(
    String sessionId,
    String? taskId, {
    Future<void> Function()? beforeCommit,
  }) =>
      _serialize(sessionId, () async {
        var session = _requireSession(sessionId);
        if (session.state.owner.type != TimerSessionOwnerType.marathon) {
          throw StateError('Only marathon sessions can select a task');
        }
        if (taskId != null && taskId.trim().isEmpty) throw ArgumentError.value(taskId, 'taskId');
        if (session.state.selectedTaskId == taskId) return session.state;
        await beforeCommit?.call();
        if (session.state.isRunning) session = _applyElapsed(session, _now());
        _replaceSession(sessionId, session);
        await _flush(sessionId);
        final nextState = _copyState(session.state, selectedTaskId: taskId, clearSelectedTaskId: taskId == null);
        _replaceSession(sessionId, _requireSession(sessionId).copyWith(state: nextState));
        return nextState;
      });

  @override
  Future<TimerSessionState> updateSettings(String sessionId, TimerSessionSettings settings) =>
      _serialize(sessionId, () async {
        _validateSettings(settings);
        var session = _requireSession(sessionId);
        if (session.state.isRunning) session = _applyElapsed(session, _now());
        session.timer?.cancel();
        _replaceSession(sessionId, session);
        await _cancelAlarm(sessionId);
        await _flush(sessionId);
        session = _requireSession(sessionId);
        final state = TimerSessionState(
          sessionId: session.state.sessionId,
          owner: session.state.owner,
          selectedTaskId: session.state.selectedTaskId,
          settings: settings,
          isRunning: false,
          isWorking: true,
          isAlarmPlaying: false,
          isLongBreak: false,
          remainingTime: settings.workDuration,
          elapsedTime: Duration.zero,
          sessionTotalElapsed: session.state.sessionTotalElapsed,
          currentWorkSessionElapsed: Duration.zero,
          completedSessions: 0,
        );
        _replaceSession(
          sessionId,
          session.copyWith(
            state: state,
            timer: null,
            clearTimer: true,
            lastTickAt: null,
            clearLastTickAt: true,
            isPaused: false,
          ),
        );
        return state;
      });

  @override
  Future<void> shutdown() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final sessionId in _sessions.keys.toList(growable: false)) {
      try {
        await stop(sessionId);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    await _changes.close();
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStackTrace!);
  }

  Future<TimerSessionState> _serialize(String sessionId, Future<TimerSessionState> Function() operation) {
    final result = Completer<TimerSessionState>();
    final previous = _operationQueues[sessionId] ?? Future.value();
    final queued = previous.catchError((_) {}).then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    _operationQueues = {..._operationQueues, sessionId: queued};
    queued.whenComplete(() {
      if (identical(_operationQueues[sessionId], queued)) {
        _operationQueues = Map.unmodifiable(Map.of(_operationQueues)..remove(sessionId));
      }
    });
    return result.future;
  }

  void _tick(String sessionId) {
    var session = _sessions[sessionId];
    if (session == null || !session.state.isRunning) return;
    session = _applyElapsed(session, _now());

    if (session.state.settings.mode != TimerSessionMode.stopwatch && session.state.remainingTime <= Duration.zero) {
      session.timer?.cancel();
      session = session.copyWith(
        state: _copyState(session.state, isRunning: false, isAlarmPlaying: true, remainingTime: Duration.zero),
        timer: null,
        clearTimer: true,
        lastTickAt: null,
        clearLastTickAt: true,
      );
      final shouldAutoStart = session.state.settings.mode == TimerSessionMode.pomodoro &&
          ((session.state.isWorking && session.state.settings.autoStartBreak) ||
              (!session.state.isWorking && session.state.settings.autoStartWork));
      if (shouldAutoStart) {
        unawaited(Future<void>.delayed(const Duration(seconds: 3), () async {
          if (_sessions[sessionId]?.state.isAlarmPlaying == true) {
            await toggleWorkBreak(sessionId);
          }
        }));
      }
    }
    _replaceSession(sessionId, session);
    if (_pendingDuration(session) >= _periodicSaveInterval) {
      unawaited(_serialize(sessionId, () async {
        await _flush(sessionId);
        return _requireSession(sessionId).state;
      }).catchError((Object error, StackTrace stackTrace) {
        Logger.error(
          'Periodic timer duration save failed',
          component: 'TimerSessionService',
          error: error,
          stackTrace: stackTrace,
        );
        return _requireSession(sessionId).state;
      }));
    }
  }

  _TimerSession _applyElapsed(_TimerSession session, DateTime now) {
    final lastTickAt = session.lastTickAt;
    if (lastTickAt == null || !now.isAfter(lastTickAt)) return session;
    final elapsed = now.difference(lastTickAt);
    final state = session.state;
    final nextRemaining =
        state.settings.mode == TimerSessionMode.stopwatch ? state.remainingTime : state.remainingTime - elapsed;
    return session.copyWith(
      state: _copyState(
        state,
        remainingTime: nextRemaining,
        elapsedTime:
            state.settings.mode == TimerSessionMode.stopwatch ? state.elapsedTime + elapsed : state.elapsedTime,
        sessionTotalElapsed: state.sessionTotalElapsed + elapsed,
        currentWorkSessionElapsed:
            state.isWorking ? state.currentWorkSessionElapsed + elapsed : state.currentWorkSessionElapsed,
      ),
      lastTickAt: now,
      pending: _targetId(state) == null ? session.pending : [...session.pending, ..._splitByLocalDay(lastTickAt, now)],
    );
  }

  List<_PendingDuration> _splitByLocalDay(DateTime start, DateTime end) {
    final durations = <_PendingDuration>[];
    var cursor = start;
    while (cursor.isBefore(end)) {
      final nextDay = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final segmentEnd = end.isBefore(nextDay) ? end : nextDay;
      durations.add(_PendingDuration(recordedAt: cursor, duration: segmentEnd.difference(cursor)));
      cursor = segmentEnd;
    }
    return durations;
  }

  Future<void> _flush(String sessionId) async {
    var session = _requireSession(sessionId);
    final targetId = _targetId(session.state);
    if (targetId == null || session.pending.isEmpty) return;
    var pendingSnapshot = session.pending;
    for (final group in _groupByDay(pendingSnapshot)) {
      final flushedCount =
          pendingSnapshot.takeWhile((pending) => _isSameLocalDay(pending.recordedAt, group.recordedAt)).length;
      if (group.duration.inSeconds > 0) {
        await _durationWriter.write(TimerSessionDuration(
          owner: session.state.owner,
          targetId: targetId,
          duration: Duration(seconds: group.duration.inSeconds),
          recordedAt: group.recordedAt,
        ));
      }
      session = _requireSession(sessionId);
      _replaceSession(
        sessionId,
        session.copyWith(
          pending: session.pending.skip(flushedCount).toList(growable: false),
        ),
      );
      pendingSnapshot = pendingSnapshot.skip(flushedCount).toList(growable: false);
    }
  }

  bool _isSameLocalDay(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month && first.day == second.day;

  List<_PendingDuration> _groupByDay(List<_PendingDuration> pending) {
    final grouped = <DateTime, Duration>{};
    for (final item in pending) {
      final day = DateTime(item.recordedAt.year, item.recordedAt.month, item.recordedAt.day);
      grouped[day] = (grouped[day] ?? Duration.zero) + item.duration;
    }
    return grouped.entries
        .map((entry) => _PendingDuration(recordedAt: entry.key, duration: entry.value))
        .toList(growable: false);
  }

  Duration _pendingDuration(_TimerSession session) =>
      session.pending.fold(Duration.zero, (total, pending) => total + pending.duration);

  Future<void> _scheduleAlarm(_TimerSession session) async {
    if (session.state.settings.mode == TimerSessionMode.stopwatch) return;
    try {
      await _alarmScheduler.schedule(
        alarmId: _alarmId(session.state.sessionId),
        scheduledAt: _now().add(session.state.remainingTime),
      );
    } catch (error, stackTrace) {
      Logger.error(
        'Failed to schedule timer alarm',
        component: 'TimerSessionService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _cancelAlarm(String sessionId) async {
    try {
      await _alarmScheduler.cancel(_alarmId(sessionId));
    } catch (error, stackTrace) {
      Logger.error(
        'Failed to cancel timer alarm',
        component: 'TimerSessionService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _alarmId(String sessionId) => '$_alarmPrefix$sessionId';

  String? _targetId(TimerSessionState state) => switch (state.owner.type) {
        TimerSessionOwnerType.task || TimerSessionOwnerType.habit => state.owner.ownerId,
        TimerSessionOwnerType.marathon => state.selectedTaskId,
      };

  void _replaceSession(String sessionId, _TimerSession session) {
    _sessions = {..._sessions, sessionId: session};
    if (!_changes.isClosed) _changes.add(session.state);
  }

  _TimerSession _requireSession(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) throw StateError('Unknown timer session "$sessionId"');
    return session;
  }

  void _validateSession(
    String sessionId,
    TimerSessionOwner owner,
    TimerSessionSettings settings,
    String? selectedTaskId,
  ) {
    if (sessionId.trim().isEmpty) throw ArgumentError.value(sessionId, 'sessionId');
    if (owner.ownerId.trim().isEmpty) throw ArgumentError.value(owner.ownerId, 'owner.ownerId');
    _validateSettings(settings);
    if (owner.type == TimerSessionOwnerType.marathon && selectedTaskId?.trim().isEmpty == true) {
      throw ArgumentError.value(selectedTaskId, 'selectedTaskId');
    }
  }

  void _validateSettings(TimerSessionSettings settings) {
    if (settings.workDuration <= Duration.zero ||
        settings.breakDuration <= Duration.zero ||
        settings.longBreakDuration <= Duration.zero ||
        settings.sessionsBeforeLongBreak <= 0) {
      throw ArgumentError.value(settings, 'settings');
    }
  }

  TimerSessionState _copyState(
    TimerSessionState state, {
    String? selectedTaskId,
    bool clearSelectedTaskId = false,
    bool? isRunning,
    bool? isWorking,
    bool? isAlarmPlaying,
    bool? isLongBreak,
    Duration? remainingTime,
    Duration? elapsedTime,
    Duration? sessionTotalElapsed,
    Duration? currentWorkSessionElapsed,
    int? completedSessions,
  }) =>
      TimerSessionState(
        sessionId: state.sessionId,
        owner: state.owner,
        selectedTaskId: clearSelectedTaskId ? null : selectedTaskId ?? state.selectedTaskId,
        settings: state.settings,
        isRunning: isRunning ?? state.isRunning,
        isWorking: isWorking ?? state.isWorking,
        isAlarmPlaying: isAlarmPlaying ?? state.isAlarmPlaying,
        isLongBreak: isLongBreak ?? state.isLongBreak,
        remainingTime: remainingTime ?? state.remainingTime,
        elapsedTime: elapsedTime ?? state.elapsedTime,
        sessionTotalElapsed: sessionTotalElapsed ?? state.sessionTotalElapsed,
        currentWorkSessionElapsed: currentWorkSessionElapsed ?? state.currentWorkSessionElapsed,
        completedSessions: completedSessions ?? state.completedSessions,
      );
}

class _TimerSession {
  final TimerSessionState state;
  final Timer? timer;
  final DateTime? lastTickAt;
  final bool isPaused;
  final List<_PendingDuration> pending;

  const _TimerSession({
    required this.state,
    required this.isPaused,
    required this.pending,
    this.timer,
    this.lastTickAt,
  });

  factory _TimerSession.initial({
    required String sessionId,
    required TimerSessionOwner owner,
    required TimerSessionSettings settings,
    String? selectedTaskId,
  }) =>
      _TimerSession(
        state: TimerSessionState(
          sessionId: sessionId,
          owner: owner,
          selectedTaskId: selectedTaskId,
          settings: settings,
          isRunning: false,
          isWorking: true,
          isAlarmPlaying: false,
          isLongBreak: false,
          remainingTime: settings.workDuration,
          elapsedTime: Duration.zero,
          sessionTotalElapsed: Duration.zero,
          currentWorkSessionElapsed: Duration.zero,
          completedSessions: 0,
        ),
        isPaused: false,
        pending: const [],
      );

  _TimerSession copyWith({
    TimerSessionState? state,
    Timer? timer,
    bool clearTimer = false,
    DateTime? lastTickAt,
    bool clearLastTickAt = false,
    bool? isPaused,
    List<_PendingDuration>? pending,
  }) =>
      _TimerSession(
        state: state ?? this.state,
        timer: clearTimer ? null : timer ?? this.timer,
        lastTickAt: clearLastTickAt ? null : lastTickAt ?? this.lastTickAt,
        isPaused: isPaused ?? this.isPaused,
        pending: List.unmodifiable(pending ?? this.pending),
      );
}

class _PendingDuration {
  final DateTime recordedAt;
  final Duration duration;

  const _PendingDuration({required this.recordedAt, required this.duration});
}
