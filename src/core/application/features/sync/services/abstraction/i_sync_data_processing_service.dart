import 'package:acore/acore.dart' hide IRepository;
import 'package:application/features/sync/models/sync_data.dart';
import 'package:application/shared/services/abstraction/i_repository.dart';

/// Service responsible for processing sync data with conflict resolution and deduplication
abstract class ISyncDataProcessingService {
  /// Processes a batch of sync data with proper conflict resolution
  ///
  /// Returns the number of successfully processed items
  Future<int> processSyncDataBatch<T extends BaseEntity<String>>(
    SyncData<T> syncData,
    IRepository<T, String> repository,
  );

  /// Processes sync data dynamically without generic type constraints
  ///
  /// Returns the number of successfully processed items
  Future<int> processSyncDataBatchDynamic(
    SyncData syncData,
    IRepository repository,
  );

  /// Processes a list of items with yielding to prevent UI blocking
  ///
  /// Returns the number of successfully processed items
  Future<int> processItemsWithMaximumYielding<T extends BaseEntity<String>>(
    List<T> items,
    IRepository<T, String> repository,
    String operationType, // 'create', 'update', or 'delete'
  );

  /// Processes a single item with proper yielding and conflict resolution
  ///
  /// Returns 1 if successful, 0 if failed
  Future<int> processSingleItemWithMaximumYielding<T extends BaseEntity<String>>(
    T item,
    IRepository<T, String> repository,
    String operationType,
  );

  /// Checks for duplicate recurring tasks to prevent sync conflicts
  ///
  /// Returns the existing duplicate if found, null otherwise
  Future<T?> checkForRecurringTaskDuplicate<T extends BaseEntity<String>>(
    T entity,
    IRepository<T, String> repository,
  );

  /// Validates entity data before processing
  ///
  /// Returns true if entity is valid for processing
  bool validateEntityForProcessing<T extends BaseEntity<String>>(T entity);

  /// Cleans up soft-deleted entities that are older than the specified date
  ///
  /// This helps maintain database performance by removing old deleted records
  Future<void> cleanupSoftDeletedData(DateTime oldestLastSyncDate);

  /// Yields execution to the UI thread to prevent blocking
  ///
  /// This is critical for maintaining responsive UI during large sync operations
  Future<void> yieldToUIThread();
}
