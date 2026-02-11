import 'package:acore/acore.dart';

class DomainLogger {
  DomainLogger._();

  static ILogger _fallbackLogger = ConsoleLogger();

  static void setLogger(ILogger logger) {
    _fallbackLogger = logger;
  }

  static String _formatMessage(String message, String? component) {
    if (component != null && component.isNotEmpty) {
      return '[$component] $message';
    }
    return message;
  }

  static void _safeLog(String level, String message, {String? component, Object? error, StackTrace? stackTrace}) {
    final formattedMessage = _formatMessage(message, component);

    switch (level) {
      case 'debug':
        _fallbackLogger.debug(formattedMessage, error, stackTrace, component);
        break;
      case 'info':
        _fallbackLogger.info(formattedMessage, error, stackTrace, component);
        break;
      case 'warning':
        _fallbackLogger.warning(formattedMessage, error, stackTrace, component);
        break;
      case 'error':
        _fallbackLogger.error(formattedMessage, error, stackTrace, component);
        break;
      case 'fatal':
        _fallbackLogger.fatal(formattedMessage, error, stackTrace, component);
        break;
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
