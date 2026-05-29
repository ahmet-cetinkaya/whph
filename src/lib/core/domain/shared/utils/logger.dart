import 'package:flutter/foundation.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/shared/services/abstraction/i_logger_service.dart';

/// Static utility class for centralized logging.
///
/// Requires initialization with a container before use.
/// Falls back to debugPrint in debug mode when logger is not available.
class Logger {
  Logger._();

  static IContainer? _container;

  static void initialize(IContainer container) {
    _container = container;
  }

  /// Always resolves fresh to ensure we get the current configured logger
  static ILogger? get _instance {
    if (_container == null) return null;

    try {
      final loggerService = _container!.resolve<ILoggerService>();
      return loggerService.logger;
    } catch (e) {
      try {
        return _container!.resolve<ILogger>();
      } catch (e2) {
        return null;
      }
    }
  }

  static String _formatMessage(String message, String? component) {
    if (component != null && component.isNotEmpty) {
      return '[$component] $message';
    }
    return message;
  }

  static void _safeLog(String level, String message, {String? component, Object? error, StackTrace? stackTrace}) {
    final logger = _instance;

    if (logger != null) {
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
      final formattedMessage = _formatMessage(message, component);
      debugPrint('[$level] $formattedMessage');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  static void debug(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _safeLog('debug', message, component: component, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _safeLog('info', message, component: component, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _safeLog('warning', message, component: component, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _safeLog('error', message, component: component, error: error, stackTrace: stackTrace);
  }

  static void fatal(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    _safeLog('fatal', message, component: component, error: error, stackTrace: stackTrace);
  }
}
