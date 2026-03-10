import 'package:flutter/foundation.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/shared/services/abstraction/i_logger_service.dart';

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
/// Logger.debug('Debug message', component: LogComponents.provides);
/// Logger.info('Info message', component: LogComponents.provides);
/// Logger.warning('Warning message', component: LogComponents.provides);
/// Logger.error('Error message', component: LogComponents.provides);
/// Logger.fatal('Fatal error message', component: LogComponents.Logger);
///
/// // With component identification:
/// Logger.debug('Debug message', component: 'ComponentName');
/// Logger.info('Info message', component: 'SyncService');
/// Logger.warning('Warning message', component: 'DatabaseService');
/// Logger.error('Error message', component: 'ApiService', error: exception, stackTrace: stackTrace);
/// Logger.fatal('Fatal error message', component: 'AppInitialization', component: LogComponents.provides);
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

  /// Formats a log message with component identification and standard structure
  static String _formatMessage(String message, String? component) {
    if (component != null && component.isNotEmpty) {
      return '[$component] $message';
    }
    return message;
  }

  /// Safely logs a message, falling back to debugPrint if logger is not available
  static void _safeLog(String level, String message, {String? component, Object? error, StackTrace? stackTrace}) {
    final logger = _instance;

    if (logger != null) {
      // Pass the formatted message to the logger
      switch (level) {
        case 'debug':
          logger.debug(_formatMessage(message, component), error, stackTrace);
          break;
        case 'info':
          logger.info(_formatMessage(message, component), error, stackTrace);
          break;
        case 'warning':
          logger.warning(_formatMessage(message, component), error, stackTrace);
          break;
        case 'error':
          logger.error(_formatMessage(message, component), error, stackTrace);
          break;
        case 'fatal':
          logger.fatal(_formatMessage(message, component), error, stackTrace);
          break;
      }
    } else if (kDebugMode) {
      // Fallback to debugPrint in debug mode when logger is not available
      // Include component in fallback logging as well
      final formattedMessage = _formatMessage(message, component);
      debugPrint('[$level] $formattedMessage');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
    // In release mode, ignore logs when logger is not available
  }

  /// Logs a debug message with optional component identification
  static void debug(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _safeLog('debug', message, component: component, error: error, stackTrace: stackTrace);
  }

  /// Logs an info message with optional component identification
  static void info(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _safeLog('info', message, component: component, error: error, stackTrace: stackTrace);
  }

  /// Logs a warning message with optional component identification
  static void warning(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _safeLog('warning', message, component: component, error: error, stackTrace: stackTrace);
  }

  /// Logs an error message with optional component identification
  static void error(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _safeLog('error', message, component: component, error: error, stackTrace: stackTrace);
  }

  /// Logs a fatal error message with optional component identification
  static void fatal(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _safeLog('fatal', message, component: component, error: error, stackTrace: stackTrace);
  }
}
