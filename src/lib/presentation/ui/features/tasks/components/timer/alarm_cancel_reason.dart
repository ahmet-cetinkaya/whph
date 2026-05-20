/// Reasons for cancelling the timer system alarm.
/// Provides type-safe debug context for alarm cancellation tracking.
enum AlarmCancelReason {
  pause,
  stop,
  disposal,
  settingsUpdate,
  workBreakToggle,
  periodicTickError,
  naturalCompletion,
}
