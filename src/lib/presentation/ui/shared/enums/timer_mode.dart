enum TimerMode {
  pomodoro('pomodoro'),
  normal('normal'),
  stopwatch('stopwatch');

  const TimerMode(this.value);
  final String value;

  static TimerMode fromString(String value) {
    return TimerMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => TimerMode.pomodoro, // Default to pomodoro as requested
    );
  }
}