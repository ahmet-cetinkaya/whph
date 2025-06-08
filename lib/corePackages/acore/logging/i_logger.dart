/// Abstract logger interface that defines the contract for logging implementations.
///
/// This abstraction allows for different logging implementations while maintaining
/// a consistent interface throughout the application.
abstract class ILogger {
  /// Logs debug messages - used for detailed information during development
  void debug(String message, [Object? error, StackTrace? stackTrace]);

  /// Logs informational messages - general information about application flow
  void info(String message, [Object? error, StackTrace? stackTrace]);

  /// Logs warning messages - potentially harmful situations that are not errors
  void warning(String message, [Object? error, StackTrace? stackTrace]);

  /// Logs error messages - error events that might still allow the application to continue
  void error(String message, [Object? error, StackTrace? stackTrace]);

  /// Logs fatal/critical messages - very severe error events that might lead to termination
  void fatal(String message, [Object? error, StackTrace? stackTrace]);
}
