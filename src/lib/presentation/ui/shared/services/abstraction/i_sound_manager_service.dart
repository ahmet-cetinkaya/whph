abstract class ISoundManagerService {
  Future<void> playTaskCompletion();
  Future<void> playHabitCompletion();
  Future<void> playTimerControl();
  Future<void> playTimerAlarm();
  Future<void> playTimerAlarmLoop();
  Future<void> stopTimerAlarmLoop();
  Future<void> playTimerTick();
  Future<void> playTimerTock();
  Future<void> stopAll();
  Future<void> setLoop(bool loop);
  void clearSettingsCache();
}
