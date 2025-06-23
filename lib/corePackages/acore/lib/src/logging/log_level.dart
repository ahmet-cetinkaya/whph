/// Enumeration representing different log levels.
///
/// Used to categorize log messages by severity and importance.
enum LogLevel {
  /// Debug level - detailed information for development and troubleshooting
  debug(0, 'DEBUG'),

  /// Info level - general application flow information
  info(1, 'INFO'),

  /// Warning level - potentially harmful situations
  warning(2, 'WARNING'),

  /// Error level - error events that might still allow continuation
  error(3, 'ERROR'),

  /// Fatal level - very severe errors that might cause termination
  fatal(4, 'FATAL');

  const LogLevel(this.level, this.name);

  /// Numeric representation of the log level for comparison
  final int level;

  /// String representation of the log level for display
  final String name;

  /// Returns true if this log level is equal to or higher than the given level
  bool isAtLeast(LogLevel other) => level >= other.level;
}
