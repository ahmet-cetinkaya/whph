import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';
import 'package:path/path.dart' as path;
import 'package:whph/src/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_logger_service.dart';
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';

/// Default implementation of ILoggerService that manages dynamic logger configuration
class LoggerService implements ILoggerService {
  final IApplicationDirectoryService _applicationDirectoryService;
  final Mediator _mediator;

  ILogger _currentLogger;
  FileLogger? _fileLogger;
  final MemoryLogger _memoryLogger = MemoryLogger(
    maxEntries: 1000,
    includeTimestamp: true,
    includeStackTrace: true,
  );

  LoggerService({
    required IApplicationDirectoryService applicationDirectoryService,
    required Mediator mediator,
    required ILogger initialLogger,
  })  : _applicationDirectoryService = applicationDirectoryService,
        _mediator = mediator,
        _currentLogger = initialLogger;

  @override
  ILogger get logger => _currentLogger;

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
  }

  @override
  Future<String?> getLogFilePath() async {
    if (_fileLogger != null) {
      final appDirectory = await _applicationDirectoryService.getApplicationDirectory();
      return path.join(appDirectory.path, 'logs', 'whph.log');
    }
    return null;
  }

  @override
  String getMemoryLogs() {
    return _memoryLogger.getAllLogs();
  }

  @override
  void clearMemoryLogs() {
    _memoryLogger.clear();
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
    // Get the application directory
    final appDirectory = await _applicationDirectoryService.getApplicationDirectory();
    final logsDirectory = path.join(appDirectory.path, 'logs');
    final logFilePath = path.join(logsDirectory, 'whph.log');

    // Create file logger if it doesn't exist
    _fileLogger ??= FileLogger(
      filePath: logFilePath,
      minLevel: LogLevel.debug, // Enable all logs when debug logging is on
      includeTimestamp: true,
      includeStackTrace: true,
      maxFileSizeBytes: 5 * 1024 * 1024, // 5 MB
      maxBackupFiles: 3,
    );

    // Create composite logger with console, memory, and file logging
    _currentLogger = CompositeLogger([
      const ConsoleLogger(
        minLevel: LogLevel.info, // Keep console at info level to avoid spam
        includeTimestamp: true,
        includeStackTrace: true,
      ),
      _memoryLogger,
      _fileLogger!,
    ]);
    
    // Log that debug logging has been enabled
    _currentLogger.info('Debug logging enabled - writing logs to file');
  }

  Future<void> _disableFileLogging() async {
    // Log that debug logging is being disabled (before disposing the file logger)
    if (_fileLogger != null) {
      _currentLogger.info('Debug logging disabled - stopping file logging');
      await _fileLogger!.flush();
      _fileLogger!.dispose();
      _fileLogger = null;
    }

    // Use console and memory logger only
    _currentLogger = CompositeLogger([
      const ConsoleLogger(
        minLevel: LogLevel.info,
        includeTimestamp: true,
        includeStackTrace: true,
      ),
      _memoryLogger,
    ]);
  }
}
