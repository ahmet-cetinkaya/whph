class SyncPaginationConstants {
  // Cleanup settings
  static const int maxEntityTypesToRemoveOnCleanup = 10;
  static const int maxPendingDataItems = 50;
  static const int cleanupThreshold = 30;
  static const Duration staleDataThreshold = Duration(minutes: 10);

  // Pagination settings
  static const int defaultNetworkPageSize = 50;
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  static const int maxAdditionalPagesToRequest = 10;

  // Performance settings
  static const int batchSize = 100;
  static const int concurrentProcessingLimit = 5;
  static const Duration processingTimeout = Duration(minutes: 5);

  // Memory management
  static const int maxPendingResponsesPerEntity = 5;
  static const int maxConcurrentCallbacks = 3;

  // Logging settings
  static const int maxLogEntriesPerEntityType = 5;
  static const bool enableDetailedLogging = true;

  // Prevention
  SyncPaginationConstants._();
}