/// Interface for single instance application management
abstract class ISingleInstanceService {
  /// Check if another instance of the application is already running
  Future<bool> isAnotherInstanceRunning();

  /// Lock the current instance to prevent multiple instances
  Future<bool> lockInstance();

  /// Release the instance lock
  Future<void> releaseInstance();

  /// Send a command to the existing instance
  Future<bool> sendCommandToExistingInstance(String command);

  /// Start listening for commands from new instances
  Future<void> startListeningForCommands(Function(String command) onCommandReceived);

  /// Stop listening for commands
  Future<void> stopListeningForCommands();
}
