import 'package:flutter/foundation.dart';
import 'package:acore/acore.dart';

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

  static ILogger? _logger;
  static IContainer? _container;

  /// Initialize the Logger with a container instance
  static void initialize(IContainer container) {
    _container = container;
    _logger = null; // Reset logger to force re-resolution
  }

  /// Gets the logger instance from the container, if available
  static ILogger? get _instance {
    if (_logger != null) return _logger;

    if (_container == null) return null;

    try {
      _logger = _container!.resolve<ILogger>();
      return _logger!;
    } catch (e) {
      // Container not yet ready or logger not registered
      return null;
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
