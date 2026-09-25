enum TimerSessionOwnerType { task, habit, marathon }

enum TimerSessionMode { pomodoro, normal, stopwatch }

class TimerSessionOwner {
  final TimerSessionOwnerType type;
  final String ownerId;

  const TimerSessionOwner.task(String taskId)
      : type = TimerSessionOwnerType.task,
        ownerId = taskId;

  const TimerSessionOwner.habit(String habitId)
      : type = TimerSessionOwnerType.habit,
        ownerId = habitId;

  const TimerSessionOwner.marathon()
      : type = TimerSessionOwnerType.marathon,
        ownerId = 'marathon';
}

class TimerSessionSettings {
  final TimerSessionMode mode;
  final Duration workDuration;
  final Duration breakDuration;
  final Duration longBreakDuration;
  final int sessionsBeforeLongBreak;
  final bool autoStartBreak;
  final bool autoStartWork;

  const TimerSessionSettings({
    required this.mode,
    required this.workDuration,
    required this.breakDuration,
    required this.longBreakDuration,
    required this.sessionsBeforeLongBreak,
    this.autoStartBreak = false,
    this.autoStartWork = false,
  });
}

class TimerSessionState {
  final String sessionId;
  final TimerSessionOwner owner;
  final String? selectedTaskId;
  final TimerSessionSettings settings;
  final bool isRunning;
  final bool isWorking;
  final bool isAlarmPlaying;
  final bool isLongBreak;
  final Duration remainingTime;
  final Duration elapsedTime;
  final Duration sessionTotalElapsed;
  final Duration currentWorkSessionElapsed;
  final int completedSessions;

  const TimerSessionState({
    required this.sessionId,
    required this.owner,
    required this.settings,
    required this.isRunning,
    required this.isWorking,
    required this.isAlarmPlaying,
    required this.isLongBreak,
    required this.remainingTime,
    required this.elapsedTime,
    required this.sessionTotalElapsed,
    required this.currentWorkSessionElapsed,
    required this.completedSessions,
    this.selectedTaskId,
  });
}

class TimerSessionDuration {
  final TimerSessionOwner owner;
  final String targetId;
  final Duration duration;
  final DateTime recordedAt;

  const TimerSessionDuration({
    required this.owner,
    required this.targetId,
    required this.duration,
    required this.recordedAt,
  });
}

abstract interface class ITimerSessionDurationWriter {
  Future<void> write(TimerSessionDuration duration);
}

abstract interface class ITimerSessionAlarmScheduler {
  Future<void> schedule({
    required String alarmId,
    required DateTime scheduledAt,
  });

  Future<void> cancel(String alarmId);
}

abstract interface class ITimerSessionService {
  Stream<TimerSessionState> get changes;

  TimerSessionState create({
    required String sessionId,
    required TimerSessionOwner owner,
    required TimerSessionSettings settings,
    String? selectedTaskId,
  });

  List<TimerSessionState> list();
  TimerSessionState? state(String sessionId);
  Future<TimerSessionState> start(String sessionId);
  Future<TimerSessionState> pause(String sessionId);
  Future<TimerSessionState> resume(String sessionId);
  Future<TimerSessionState> restart(String sessionId);
  Future<TimerSessionState> stop(
    String sessionId, {
    Future<void> Function()? beforeCommit,
  });
  Future<TimerSessionState> toggleWorkBreak(
    String sessionId, {
    Future<void> Function()? beforeCommit,
  });
  Future<TimerSessionState> selectTask(
    String sessionId,
    String? taskId, {
    Future<void> Function()? beforeCommit,
  });
  Future<TimerSessionState> updateSettings(String sessionId, TimerSessionSettings settings);
  Future<void> shutdown();
}
