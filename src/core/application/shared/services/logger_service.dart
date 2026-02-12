import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:path/path.dart' as path;
import 'package:application/features/settings/queries/get_setting_query.dart';
import 'package:application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:application/shared/services/abstraction/i_logger_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:application/shared/services/stream_logger.dart';

/// Default implementation of ILoggerService that manages dynamic logger configuration
class LoggerService implements ILoggerService {
  final IApplicationDirectoryService _applicationDirectoryService;
  final Mediator _mediator;

  // Log file path constants
  static const String _logsDirectoryName = 'logs';
  static const String _logFileName = 'whph.log';

  ILogger _currentLogger;
  FileLogger? _fileLogger;

  final StreamController<String> _logStreamController = StreamController<String>.broadcast();
  late final StreamLogger _streamLogger;
  FileLogger? _tempFileLogger;

  LoggerService({
    required IApplicationDirectoryService applicationDirectoryService,
    required Mediator mediator,
    required ILogger initialLogger,
  })  : _applicationDirectoryService = applicationDirectoryService,
        _mediator = mediator,
        _currentLogger = initialLogger {
    _streamLogger = StreamLogger(_logStreamController);
    _initializeTempLogger();
  }

  Future<void> _initializeTempLogger() async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFilePath = path.join(tempDir.path, 'whph_temp.log');

      _tempFileLogger = FileLogger(
        filePath: tempFilePath,
        minLevel: LogLevel.debug,
        includeTimestamp: true,
        includeStackTrace: true,
        maxFileSizeBytes: 5 * 1024 * 1024, // 5 MB
        maxBackupFiles: 1,
      );

      // Reconfigure logger to include temp logger
      await configureLogger();
    } catch (e) {
      debugPrint('Failed to initialize temp logger: $e');
    }
  }

  /// Helper method to construct log file path consistently
  Future<String> _getLogFilePath() async {
    final appDirectory = await _applicationDirectoryService.getApplicationDirectory();
    return path.join(appDirectory.path, _logsDirectoryName, _logFileName);
  }

  @override
  ILogger get logger => _currentLogger;

  @override
  Stream<String> get logStream => _logStreamController.stream;

  @override
  Future<void> configureLogger() async {
    try {
      // Get the debug logs setting
      final isDebugLogsEnabled = await _getDebugLogsEnabled();

      if (isDebugLogsEnabled) {
        await _enableFileLogging();
      } else {
        await _disableFileLogging();
      }
    } catch (e) {
      // If there's an error reading settings, fall back to console logger only
      await _disableFileLogging();
    }
  }

  @override
  Future<void> flush() async {
    if (_fileLogger != null) {
      await _fileLogger!.flush();
    }
    if (_tempFileLogger != null) {
      await _tempFileLogger!.flush();
    }
  }

  @override
  Future<String?> getLogFilePath() async {
    if (_fileLogger != null) {
      return await _getLogFilePath();
    }
    // Return temp file path if persistent logging is disabled
    if (_tempFileLogger != null) {
      return _tempFileLogger!.filePath; // We need to expose filePath in FileLogger or store it
    }
    return null;
  }

  @override
  String getMemoryLogs() {
    // Deprecated: Memory logs are no longer stored in memory
    // We could read from temp file here, but it's async
    return "Logs are now stored in a temporary file. Use getLogFilePath() to access them.";
  }

  @override
  void clearMemoryLogs() {
    // Clear temp file
    // This is a bit tricky since FileLogger doesn't expose a clear method
    // We might need to implement it or just ignore for now
  }

  Future<bool> _getDebugLogsEnabled() async {
    try {
      final query = GetSettingQuery(key: SettingKeys.debugLogsEnabled);
      final response = await _mediator.send(query) as GetSettingQueryResponse?;
      return response?.getValue<bool>() ?? false;
    } catch (e) {
      // If setting doesn't exist or can't be read, default to false
      return false;
    }
  }

  Future<void> _enableFileLogging() async {
    // Get the log file path
    final logFilePath = await _getLogFilePath();

    // Create file logger if needed
    _fileLogger ??= FileLogger(
      filePath: logFilePath,
      minLevel: LogLevel.debug, // Enable all logs when debug logging is on
      includeTimestamp: true,
      includeStackTrace: true,
      maxFileSizeBytes: 5 * 1024 * 1024, // 5 MB
      maxBackupFiles: 3,
    );

    // Create composite logger with console, file, temp file, and stream logging
    final loggers = <ILogger>[
      const ConsoleLogger(
        minLevel: LogLevel.info, // Keep console at info level to avoid spam
        includeTimestamp: true,
        includeStackTrace: true,
      ),
      _fileLogger!,
      _streamLogger,
    ];

    if (_tempFileLogger != null) {
      loggers.add(_tempFileLogger!);
    }

    _currentLogger = CompositeLogger(loggers);
  }

  Future<void> _disableFileLogging() async {
    // Log that debug logging is being disabled (before disposing the file logger)
    if (_fileLogger != null) {
      _currentLogger.info('Debug logging disabled - stopping file logging');
      await _fileLogger!.flush();

      // Get the log file path before disposing the logger
      final logFilePath = await _getLogFilePath();
      final appDirectory = await _applicationDirectoryService.getApplicationDirectory();

      _fileLogger!.dispose();
      _fileLogger = null;

      // Delete the log file
      try {
        final logFile = File(logFilePath);
        if (await logFile.exists()) {
          await logFile.delete();
        }

        // Also try to delete the logs directory if it's empty
        final logsDirectory = Directory(path.join(appDirectory.path, _logsDirectoryName));
        if (await logsDirectory.exists()) {
          final contents = await logsDirectory.list().toList();
          if (contents.isEmpty) {
            await logsDirectory.delete();
          }
        }
      } catch (e) {
        // Log deletion failed, but continue - this is not critical
        debugPrint('Failed to delete log file: $e');
      }
    }

    // Use console, temp file, and stream logger
    final loggers = <ILogger>[
      const ConsoleLogger(
        minLevel: LogLevel.info,
        includeTimestamp: true,
        includeStackTrace: true,
      ),
      _streamLogger,
    ];

    if (_tempFileLogger != null) {
      loggers.add(_tempFileLogger!);
    }

    _currentLogger = CompositeLogger(loggers);
  }
}
