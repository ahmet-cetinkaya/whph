import 'package:whph/src/core/application/features/sync/models/v2/sync_data.dart';

/// Describes how an entity participates in sync operations
abstract class SyncEntityDescriptor<T> {
  /// Unique entity type identifier (e.g., 'Task', 'Habit')
  String get entityType;
  
  /// Repository instance for data access
  dynamic get repository;
  
  /// Serializes entity data to sync format
  Map<String, dynamic> serialize(T entity);
  
  /// Deserializes sync data to entity
  T deserialize(Map<String, dynamic> data);
  
  /// Gets paginated data for sync
  Future<SyncData<T>> getPaginatedSyncData(
    DateTime lastSyncDate, {
    required int pageIndex,
    required int pageSize,
  });
  
  /// Processes incoming sync data
  Future<void> processSyncData(SyncData<T> syncData);
  
  /// Validates entity data
  bool isValid(T entity);
  
  /// Entity priority for sync ordering (lower = higher priority)
  int get syncPriority => 100;
}