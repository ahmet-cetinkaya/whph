import 'package:acore/acore.dart';

/// A test logger implementation that discards all log messages.
///
/// This logger is designed for use in unit tests where we don't want
/// actual logging output but need to provide an ILogger implementation
/// to services that require it.
class TestLogger implements ILogger {
  /// Creates a new test logger that silently discards all log messages.
  const TestLogger();

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    // Silently discard debug messages in tests
  }

  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    // Silently discard info messages in tests
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    // Silently discard warning messages in tests
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    // Silently discard error messages in tests
  }

  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    // Silently discard fatal messages in tests
  }
}
