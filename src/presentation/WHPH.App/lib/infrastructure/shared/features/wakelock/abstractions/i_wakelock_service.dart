/// Interface for managing device wakelock functionality
abstract class IWakelockService {
  /// Enable wakelock to keep the screen awake
  Future<void> enable();

  /// Disable wakelock to allow the screen to sleep
  Future<void> disable();

  /// Check if wakelock is currently enabled
  Future<bool> isEnabled();

  /// Toggle wakelock state based on the provided flag
  Future<void> setEnabled(bool enabled);
}
