/// Interface for single instance application management
abstract class ISingleInstanceService {
  /// Check if another instance of the application is already running
  Future<bool> isAnotherInstanceRunning();

  /// Lock the current instance to prevent multiple instances
  Future<bool> lockInstance();

  /// Release the instance lock
  Future<void> releaseInstance();

  /// Send a focus command to the existing instance
  Future<bool> sendFocusToExistingInstance();

  /// Start listening for focus commands from new instances
  Future<void> startListeningForFocusCommands(Function() onFocusRequested);

  /// Stop listening for focus commands
  Future<void> stopListeningForFocusCommands();
}