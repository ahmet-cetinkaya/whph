import 'dart:async';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';

/// Service responsible for managing sync pagination and progress tracking
abstract class ISyncPaginationService {
  /// Gets the progress stream for monitoring sync operations
  Stream<SyncProgress> get progressStream;

  /// Synchronizes a specific entity type with pagination support
  ///
  /// Returns true if sync completed successfully, false otherwise
  Future<bool> syncEntityWithPagination(
    PaginatedSyncConfig config,
    SyncDevice syncDevice,
    DateTime lastSyncDate, {
    String? targetDeviceId,
  });

  /// Updates the progress for a specific entity type
  void updateProgress({
    required String currentEntity,
    required int currentPage,
    required int totalPages,
    required double progressPercentage,
    required int entitiesCompleted,
    required int totalEntities,
    required String operation,
  });

  /// Resets progress tracking for a new sync operation
  void resetProgress();

  /// Gets the current progress for a specific entity type
  SyncProgress? getCurrentProgress(String entityType);

  /// Gets pagination metadata from server response
  ///
  /// Returns a map containing totalPages and totalItems for the entity type
  Map<String, int> getServerPaginationMetadata(String entityType);

  /// Updates server pagination metadata from sync response
  void updateServerPaginationMetadata(
    String entityType,
    int totalPages,
    int totalItems,
  );

  /// Calculates the overall sync progress across all entity types
  ///
  /// Returns a percentage (0.0 to 100.0) representing total sync completion
  double calculateOverallProgress();

  /// Checks if sync is currently in progress for any entity type
  bool get isSyncInProgress;

  /// Gets the list of entity types currently being synchronized
  List<String> get activeEntityTypes;

  /// Cancels ongoing sync operations
  Future<void> cancelSync();

  /// Gets all pending response data from bidirectional sync operations
  Map<String, PaginatedSyncDataDto> getPendingResponseData();

  /// Clears all pending response data (should be called after processing)
  void clearPendingResponseData();

  /// Validates and cleans up stale pending response data
  /// This should be called periodically to prevent memory leaks from orphaned data
  void validateAndCleanStalePendingData();

  /// Gets the last sent server page for a specific device and entity type
  int getLastSentServerPage(String deviceId, String entityType);

  /// Sets the last sent server page for a specific device and entity type
  void setLastSentServerPage(String deviceId, String entityType, int page);
}
