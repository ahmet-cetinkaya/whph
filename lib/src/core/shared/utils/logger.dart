import 'package:flutter/foundation.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_logger_service.dart';

/// Static utility class for accessing the centralized logger throughout the application.
///
/// This class provides a convenient way to access the logger without requiring
/// dependency injection in every class. It requires initialization with a container
/// instance before use.
///
/// If the logger is not initialized, falls back to debugPrint in debug mode
/// or ignores the log in release mode.
///
/// Usage:
/// ```dart
/// // First initialize in main.dart or bootstrap service:
/// Logger.initialize(container);
///
/// // Then use throughout the app:
/// Logger.debug('Debug message');
/// Logger.info('Info message');
/// Logger.warning('Warning message');
/// Logger.error('Error message');
/// Logger.fatal('Fatal error message');
/// ```
class Logger {
  Logger._(); // Private constructor to prevent instantiation

  static IContainer? _container;

  /// Initialize the Logger with a container instance
  static void initialize(IContainer container) {
    _container = container;
  }

  /// Gets the logger instance from the logger service, if available
  /// Always resolves fresh to ensure we get the current configured logger
  static ILogger? get _instance {
    if (_container == null) return null;

    try {
      // Always get the current logger from the logger service (no caching)
      // This ensures we get the updated logger after configureLogger() is called
      final loggerService = _container!.resolve<ILoggerService>();
      return loggerService.logger;
    } catch (e) {
      try {
        // Fallback to direct logger resolution
        return _container!.resolve<ILogger>();
      } catch (e2) {
        // Container not yet ready or logger not registered
        return null;
      }
    }
  }

  /// Safely logs a message, falling back to debugPrint if logger is not available
  static void _safeLog(String level, String message) {
    final logger = _instance;
    if (logger != null) {
      switch (level) {
        case 'debug':
          logger.debug(message);
          break;
        case 'info':
          logger.info(message);
          break;
        case 'warning':
          logger.warning(message);
          break;
        case 'error':
          logger.error(message);
          break;
        case 'fatal':
          logger.fatal(message);
          break;
      }
    } else if (kDebugMode) {
      // Fallback to debugPrint in debug mode when logger is not available
      debugPrint('[$level] $message');
    }
    // In release mode, ignore logs when logger is not available
  }

  /// Logs a debug message
  static void debug(String message) {
    _safeLog('debug', message);
  }

  /// Logs an info message
  static void info(String message) {
    _safeLog('info', message);
  }

  /// Logs a warning message
  static void warning(String message) {
    _safeLog('warning', message);
  }

  /// Logs an error message
  static void error(String message) {
    _safeLog('error', message);
  }

  /// Logs a fatal error message
  static void fatal(String message) {
    _safeLog('fatal', message);
  }
}
