import 'package:acore/acore.dart';

/// Service for managing and configuring the application's logging system
abstract class ILoggerService {
  /// Gets the current logger instance
  ILogger get logger;

  /// Configures the logger based on current settings
  /// This method reads the debug logs setting and creates the appropriate logger configuration
  Future<void> configureLogger();

  /// Forces a flush of all log buffers (useful before app shutdown or log export)
  Future<void> flush();

  /// Gets the path to the current log file (if file logging is enabled)
  Future<String?> getLogFilePath();

  /// Gets all logs from memory as a string
  String getMemoryLogs();

  /// Clears all logs from memory
  void clearMemoryLogs();

  /// Stream of log entries for real-time monitoring
  Stream<String> get logStream;
}
