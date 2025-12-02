import 'dart:async';
import 'package:acore/acore.dart';

/// A logger implementation that streams log entries with standardized formatting.
class StreamLogger implements ILogger {
  final StreamController<String> _controller;
  final LogLevel _minLevel;
  final bool _includeTimestamp;
  final bool _includeStackTrace;

  StreamLogger(
    this._controller, {
    LogLevel minLevel = LogLevel.debug,
    bool includeTimestamp = true,
    bool includeStackTrace = true,
  })  : _minLevel = minLevel,
        _includeTimestamp = includeTimestamp,
        _includeStackTrace = includeStackTrace;

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.fatal, message, error, stackTrace);
  }

  void _log(LogLevel level, String message, Object? error, StackTrace? stackTrace) {
    if (!level.isAtLeast(_minLevel)) return;

    final buffer = StringBuffer();

    if (_includeTimestamp) {
      final now = DateTime.now();
      final timestamp = now.toIso8601String();
      buffer.write('[$timestamp] ');
    }

    // Standardized format: [LEVEL] [COMPONENT] message
    buffer.write('[${level.name.toUpperCase()}] ');
    buffer.write(message);

    if (error != null) {
      buffer.write(' | Error: $error');
    }

    if (_includeStackTrace && stackTrace != null) {
      buffer.write('\nStack trace:\n$stackTrace');
    }

    _controller.add(buffer.toString());
  }
}
