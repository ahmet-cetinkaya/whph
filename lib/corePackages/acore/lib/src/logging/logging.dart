/// Logging module providing flexible logging infrastructure.
///
/// This library provides a flexible logging system with:
/// - Abstract Logger interface for different implementations
/// - LogLevel enumeration for categorizing messages
/// - ConsoleLogger implementation for development and debugging
///
/// Example usage:
/// ```dart
/// import 'package:acore/acore.dart';
///
/// final logger = ConsoleLogger(
///   minLevel: LogLevel.info,
///   includeTimestamp: true,
/// );
///
/// logger.info('Application started');
/// logger.warning('This is a warning message');
/// logger.error('An error occurred', error, stackTrace);
/// ```
library;

export 'console_logger.dart';
export 'log_level.dart';
export 'i_logger.dart';
