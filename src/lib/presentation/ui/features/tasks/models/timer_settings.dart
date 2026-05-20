import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';

/// Value object bundling all timer settings together.
/// Reduces parameter count in [TimerController.updateSettings] and [_handleSettingsChanged].
class TimerSettings {
  final TimerMode timerMode;
  final int workDuration;
  final int breakDuration;
  final int longBreakDuration;
  final int sessionsCount;
  final bool autoStartBreak;
  final bool autoStartWork;
  final bool tickingEnabled;
  final bool keepScreenAwake;
  final int tickingVolume;
  final int tickingSpeed;

  const TimerSettings({
    required this.timerMode,
    required this.workDuration,
    required this.breakDuration,
    required this.longBreakDuration,
    required this.sessionsCount,
    required this.autoStartBreak,
    required this.autoStartWork,
    required this.tickingEnabled,
    required this.keepScreenAwake,
    required this.tickingVolume,
    required this.tickingSpeed,
  });

  TimerSettings copyWith({
    TimerMode? timerMode,
    int? workDuration,
    int? breakDuration,
    int? longBreakDuration,
    int? sessionsCount,
    bool? autoStartBreak,
    bool? autoStartWork,
    bool? tickingEnabled,
    bool? keepScreenAwake,
    int? tickingVolume,
    int? tickingSpeed,
  }) {
    return TimerSettings(
      timerMode: timerMode ?? this.timerMode,
      workDuration: workDuration ?? this.workDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      autoStartBreak: autoStartBreak ?? this.autoStartBreak,
      autoStartWork: autoStartWork ?? this.autoStartWork,
      tickingEnabled: tickingEnabled ?? this.tickingEnabled,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      tickingVolume: tickingVolume ?? this.tickingVolume,
      tickingSpeed: tickingSpeed ?? this.tickingSpeed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimerSettings &&
        other.timerMode == timerMode &&
        other.workDuration == workDuration &&
        other.breakDuration == breakDuration &&
        other.longBreakDuration == longBreakDuration &&
        other.sessionsCount == sessionsCount &&
        other.autoStartBreak == autoStartBreak &&
        other.autoStartWork == autoStartWork &&
        other.tickingEnabled == tickingEnabled &&
        other.keepScreenAwake == keepScreenAwake &&
        other.tickingVolume == tickingVolume &&
        other.tickingSpeed == tickingSpeed;
  }

  @override
  int get hashCode => Object.hash(
        timerMode,
        workDuration,
        breakDuration,
        longBreakDuration,
        sessionsCount,
        autoStartBreak,
        autoStartWork,
        tickingEnabled,
        keepScreenAwake,
        tickingVolume,
        tickingSpeed,
      );
}
