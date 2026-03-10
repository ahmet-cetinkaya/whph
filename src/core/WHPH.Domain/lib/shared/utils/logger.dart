/// Domain layer logging abstraction.
///
/// The domain layer cannot depend on infrastructure or application layer services.
/// This interface provides a logging abstraction that can be implemented by the application layer.
/// Domain entities use this interface for logging without creating dependencies.
///
/// Usage:
/// ```dart
/// // In domain entities, use DomainLogger.instance:
/// DomainLogger.debug('Debug message', component: 'Task');
/// DomainLogger.error('Error message', error: e, stackTrace: st, component: 'Task');
///
/// // The application layer should provide an implementation:
/// DomainLogger.initialize(AppDomainLoggerImplementation());
/// ```
abstract class IDomainLogger {
  void debug(String message, {String? component, Object? error, StackTrace? stackTrace});
  void info(String message, {String? component, Object? error, StackTrace? stackTrace});
  void warning(String message, {String? component, Object? error, StackTrace? stackTrace});
  void error(String message, {Object? error, StackTrace? stackTrace, String? component});
  void fatal(String message, {Object? error, StackTrace? stackTrace, String? component});
}

/// Static accessor for domain logging.
///
/// The application layer must initialize this with a concrete implementation
/// before domain entities can log messages.
class DomainLogger {
  DomainLogger._();

  static IDomainLogger? _instance;

  /// Initialize the domain logger with a concrete implementation from the application layer
  static void initialize(IDomainLogger logger) {
    _instance = logger;
  }

  /// Logs a debug message
  static void debug(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _instance?.debug(message, component: component, error: error, stackTrace: stackTrace);
  }

  /// Logs an info message
  static void info(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _instance?.info(message, component: component, error: error, stackTrace: stackTrace);
  }

  /// Logs a warning message
  static void warning(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _instance?.warning(message, component: component, error: error, stackTrace: stackTrace);
  }

  /// Logs an error message
  static void error(String message, {Object? error, StackTrace? stackTrace, String? component}) {
    _instance?.error(message, error: error, stackTrace: stackTrace, component: component);
  }

  /// Logs a fatal error message
  static void fatal(String message, {Object? error, StackTrace? stackTrace, String? component}) {
    _instance?.fatal(message, error: error, stackTrace: stackTrace, component: component);
  }
}
