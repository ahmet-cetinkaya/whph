import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/shared/utils/logger.dart';

/// Service to manage database connection state and handle resets gracefully
class DatabaseConnectionManager {
  static DatabaseConnectionManager? _instance;
  static DatabaseConnectionManager get instance => _instance ??= DatabaseConnectionManager._();

  DatabaseConnectionManager._() {
    // Listen to connection state changes
    AppDatabase.onDatabaseReset.listen(_onDatabaseReset);
  }

  bool _isResetting = false;
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 5;

  bool get isResetting => _isResetting;
  bool get hasConnectionIssues => _consecutiveFailures >= _maxConsecutiveFailures;

  /// Initialize the connection manager to listen for database resets
  void initialize() {
    Logger.info('📡 Database connection manager initialized');
  }

  void _onDatabaseReset(void _) async {
    Logger.info('🔄 Database reset detected, marking as resetting');
    _isResetting = true;
    _consecutiveFailures = 0; // Reset failure count on successful reset

    // Give the database time to fully reinitialize
    await Future.delayed(const Duration(milliseconds: 200));

    _isResetting = false;
    Logger.info('✅ Database reset completed, connection ready');
  }

  /// Check if database operations can be performed safely
  bool canPerformOperations() {
    return !_isResetting;
  }

  /// Wait for database to be ready (useful for operations that might occur during reset)
  Future<void> waitForReady({Duration timeout = const Duration(seconds: 5)}) async {
    final stopwatch = Stopwatch()..start();

    while (_isResetting && stopwatch.elapsed < timeout) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (_isResetting) {
      Logger.warning('⚠️ Database reset timeout, operations may fail');
    }
  }

  /// Execute a database operation with retry logic for reset scenarios
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        // Wait for database to be ready if it's resetting
        await waitForReady();

        // Execute the operation
        final result = await operation();

        // Reset failure count on successful operation
        _consecutiveFailures = 0;
        return result;
      } catch (e, stackTrace) {
        attempts++;
        _consecutiveFailures++;

        // Check if this is a connection closed error
        if (_isConnectionError(e) && attempts < maxRetries) {
          final waitTime = delay * attempts; // Exponential backoff
          Logger.warning(
              '🔄 Database connection lost during operation, retrying... (attempt $attempts/$maxRetries, wait ${waitTime.inMilliseconds}ms)');

          await Future.delayed(waitTime);
          continue;
        }

        // Re-throw if it's not a connection error or we've exhausted retries
        Logger.error('❌ Database operation failed after $attempts attempts: $e\n$stackTrace');
        rethrow;
      }
    }

    throw StateError('Operation failed after $maxRetries attempts');
  }

  /// Check if an error is related to database connection issues
  bool _isConnectionError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('connection was closed') ||
        errorString.contains('bad state') ||
        errorString.contains('database is closed') ||
        errorString.contains('no such database') ||
        errorString.contains('database disk image is malformed');
  }

  /// Dispose the connection manager
  void dispose() {
    Logger.info('📡 Database connection manager disposed');
    _instance = null;
  }
}
