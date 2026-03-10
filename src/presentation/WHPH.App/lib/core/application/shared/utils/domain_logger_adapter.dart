import 'package:whph_domain/shared/utils/logger.dart';
import 'package:whph/core/application/shared/utils/logger.dart' as app_logger;

/// Adapter that bridges the domain layer's IDomainLogger interface
/// with the application layer's concrete Logger implementation.
///
/// This allows the domain layer to log without depending on the application layer.
class DomainLoggerAdapter implements IDomainLogger {
  @override
  void debug(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    app_logger.Logger.debug(message, component: component, error: error, stackTrace: stackTrace);
  }

  @override
  void info(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    app_logger.Logger.info(message, component: component, error: error, stackTrace: stackTrace);
  }

  @override
  void warning(String message, {String? component, Object? error, StackTrace? stackTrace}) {
    app_logger.Logger.warning(message, component: component, error: error, stackTrace: stackTrace);
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace, String? component}) {
    app_logger.Logger.error(message, component: component, error: error, stackTrace: stackTrace);
  }

  @override
  void fatal(String message, {Object? error, StackTrace? stackTrace, String? component}) {
    app_logger.Logger.fatal(message, component: component, error: error, stackTrace: stackTrace);
  }
}
