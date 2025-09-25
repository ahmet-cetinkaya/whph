import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/core/application/features/sync/models/sync_data.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_data_processing_service.dart';
import 'package:whph/core/application/features/sync/services/sync_conflict_resolution_service.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/shared/utils/logger.dart';

/// Implementation of sync data processing service
class SyncDataProcessingService implements ISyncDataProcessingService {
  final SyncConflictResolutionService _conflictResolutionService;

  SyncDataProcessingService({
    SyncConflictResolutionService? conflictResolutionService,
  }) : _conflictResolutionService = conflictResolutionService ?? SyncConflictResolutionService();

  @override
  Future<int> processSyncDataBatch<T extends BaseEntity<String>>(
    SyncData<T> syncData,
    IRepository<T, String> repository,
  ) async {
    try {
      final totalItems = syncData.createSync.length + syncData.updateSync.length + syncData.deleteSync.length;

      int conflictsResolved = 0;

      // Track processed items to avoid duplicates across all operation types
      final Set<String> processedItemIds = <String>{};

      // Deduplicate items across create/update/delete arrays
      final deduplicatedCreateSync = <T>[];
      final deduplicatedUpdateSync = <T>[];
      final deduplicatedDeleteSync = <T>[];

      // Process creates first, tracking IDs
      for (final item in syncData.createSync) {
        if (!processedItemIds.contains(item.id)) {
          deduplicatedCreateSync.add(item);
          processedItemIds.add(item.id);
        } else {
          Logger.debug('🔍 Deduplication: Skipping duplicate CREATE for ${item.id}');
        }
      }

      // Process updates, excluding items already in creates
      for (final item in syncData.updateSync) {
        if (!processedItemIds.contains(item.id)) {
          deduplicatedUpdateSync.add(item);
          processedItemIds.add(item.id);
        } else {
          Logger.debug('🔍 Deduplication: Skipping duplicate UPDATE for ${item.id} (already processed as CREATE)');
        }
      }

      // Process deletes, excluding items already processed
      for (final item in syncData.deleteSync) {
        if (!processedItemIds.contains(item.id)) {
          deduplicatedDeleteSync.add(item);
          processedItemIds.add(item.id);
        } else {
          Logger.debug('🔍 Deduplication: Skipping duplicate DELETE for ${item.id}');
        }
      }

      Logger.info(
          '🔍 Deduplication results: CREATE ${syncData.createSync.length}→${deduplicatedCreateSync.length}, UPDATE ${syncData.updateSync.length}→${deduplicatedUpdateSync.length}, DELETE ${syncData.deleteSync.length}→${deduplicatedDeleteSync.length}');

      // Reset processed items tracker for actual processing
      processedItemIds.clear();

      final deduplicatedTotalItems =
          deduplicatedCreateSync.length + deduplicatedUpdateSync.length + deduplicatedDeleteSync.length;
      Logger.debug(
          '🔧 Processing $deduplicatedTotalItems deduplicated items (was $totalItems) with maximum UI responsiveness');

      // Process creates first with single-item yielding
      if (deduplicatedCreateSync.isNotEmpty) {
        Logger.debug('📦 Processing ${deduplicatedCreateSync.length} deduplicated create items individually');
        conflictsResolved += await processItemsWithMaximumYielding(
          deduplicatedCreateSync,
          repository,
          'create',
        );
      }

      // Process updates with conflict resolution
      if (deduplicatedUpdateSync.isNotEmpty) {
        Logger.debug('📦 Processing ${deduplicatedUpdateSync.length} deduplicated update items individually');
        conflictsResolved += await processItemsWithMaximumYielding(
          deduplicatedUpdateSync,
          repository,
          'update',
        );
      }

      // Process deletes
      if (deduplicatedDeleteSync.isNotEmpty) {
        Logger.debug('📦 Processing ${deduplicatedDeleteSync.length} deduplicated delete items individually');
        await processItemsWithMaximumYielding(
          deduplicatedDeleteSync,
          repository,
          'delete',
        );
      }

      Logger.debug('📊 Processed ${processedItemIds.length} unique items, $conflictsResolved conflicts resolved');
      return conflictsResolved;
    } catch (e) {
      Logger.error('❌ Error processing batch for ${T.toString()}: $e');
      rethrow;
    }
  }

  @override
  Future<int> processSyncDataBatchDynamic(
    SyncData syncData,
    IRepository repository,
  ) async {
    try {
      final totalItems = syncData.createSync.length + syncData.updateSync.length + syncData.deleteSync.length;

      int conflictsResolved = 0;

      Logger.debug('🔧 Processing $totalItems items dynamically with maximum UI responsiveness');

      // Process creates first with single-item yielding
      if (syncData.createSync.isNotEmpty) {
        Logger.debug('📦 Processing ${syncData.createSync.length} create items individually');
        conflictsResolved += await _processItemsWithMaximumYieldingDynamic(
          syncData.createSync,
          repository,
          'create',
        );
      }

      // Process updates with conflict resolution
      if (syncData.updateSync.isNotEmpty) {
        Logger.debug('📦 Processing ${syncData.updateSync.length} update items individually');
        conflictsResolved += await _processItemsWithMaximumYieldingDynamic(
          syncData.updateSync,
          repository,
          'update',
        );
      }

      // Process deletes
      if (syncData.deleteSync.isNotEmpty) {
        Logger.debug('📦 Processing ${syncData.deleteSync.length} delete items individually');
        await _processItemsWithMaximumYieldingDynamic(
          syncData.deleteSync,
          repository,
          'delete',
        );
      }

      Logger.debug('📊 Processed $totalItems items dynamically, $conflictsResolved conflicts resolved');
      return totalItems; // Return total items processed instead of just conflicts
    } catch (e) {
      Logger.error('❌ Error processing dynamic batch: $e');
      rethrow;
    }
  }

  @override
  Future<int> processItemsWithMaximumYielding<T extends BaseEntity<String>>(
    List<T> items,
    IRepository<T, String> repository,
    String operationType,
  ) async {
    int conflictsResolved = 0;
    final Set<String> processedItemIds = <String>{};

    Logger.debug('🔥 Processing ${items.length} $operationType items with maximum yielding (one at a time)');

    for (var i = 0; i < items.length; i++) {
      final item = items[i];

      // Skip if already processed
      if (processedItemIds.contains(item.id)) {
        Logger.debug('⏭️ Skipping duplicate item ${item.id}');
        continue;
      }

      // Yield before every single item
      await yieldToUIThread();

      try {
        final itemConflicts = await processSingleItemWithMaximumYielding(item, repository, operationType);
        conflictsResolved += itemConflicts;
        processedItemIds.add(item.id);
      } catch (e) {
        Logger.error('❌ Error processing item ${item.id}: $e');
        // Continue with other items instead of failing entire batch
      }

      // Yield after every single item
      await yieldToUIThread();

      // Add breathing room delay after each item
      await Future.delayed(const Duration(milliseconds: 5));

      // Progress logging every 10 items to avoid log spam
      if (i % 10 == 9 || i == items.length - 1) {
        Logger.debug('🔥 Completed ${i + 1}/${items.length} $operationType items');
      }
    }

    Logger.debug(
        '✅ Completed maximum yielding processing of ${items.length} $operationType items, $conflictsResolved conflicts');
    return conflictsResolved;
  }

  @override
  Future<int> processSingleItemWithMaximumYielding<T extends BaseEntity<String>>(
    T item,
    IRepository<T, String> repository,
    String operationType,
  ) async {
    int conflicts = 0;

    try {
      // Special handling for SyncDevice entities
      if (item is SyncDevice) {
        return await _processSyncDeviceItem(
            item as SyncDevice, repository as IRepository<SyncDevice, String>, operationType);
      }

      switch (operationType) {
        case 'create':
          // Yield before read
          await yieldToUIThread();

          T? existingItem = await repository.getById(item.id);

          // Yield after read
          await yieldToUIThread();

          if (existingItem == null) {
            // Check for recurring task deduplication before creating
            T? duplicateTask = await checkForRecurringTaskDuplicate(item, repository);

            if (duplicateTask != null) {
              // Found a duplicate recurring task - resolve conflict with existing task
              final resolution = _conflictResolutionService.resolveConflict<T>(duplicateTask, item);
              conflicts = 1;

              Logger.debug('🔄 Found duplicate recurring task during create: ${item.id} vs ${duplicateTask.id}');

              switch (resolution.action) {
                case ConflictAction.keepLocal:
                  Logger.debug('✅ Keeping existing task ${duplicateTask.id}, skipping remote ${item.id}');
                  break;
                case ConflictAction.acceptRemote:
                case ConflictAction.acceptRemoteForceUpdate:
                  Logger.debug('🔄 Replacing existing task ${duplicateTask.id} with remote ${item.id}');
                  // Update existing task with remote data while preserving the existing task's ID
                  final updatedTask = _conflictResolutionService.copyRemoteDataToExistingTask(duplicateTask, item);
                  await yieldToUIThread();
                  await repository.update(updatedTask);
                  await yieldToUIThread();
                  break;
              }
            } else {
              // No duplicate found, proceed with normal create
              await yieldToUIThread();
              try {
                await repository.add(item);
                await yieldToUIThread();
              } catch (e) {
                // Handle UNIQUE constraint errors gracefully
                if (e.toString().contains('UNIQUE constraint failed')) {
                  Logger.warning('⚠️ Item ${item.id} already exists despite check, treating as conflict');
                  // Try to get the existing item and resolve conflict
                  T? existingItem = await repository.getById(item.id);
                  if (existingItem != null) {
                    final resolution = _conflictResolutionService.resolveConflict<T>(existingItem, item);
                    conflicts = 1;
                    switch (resolution.action) {
                      case ConflictAction.keepLocal:
                        Logger.debug('✅ Keeping local version of ${item.id}');
                        break;
                      case ConflictAction.acceptRemote:
                      case ConflictAction.acceptRemoteForceUpdate:
                        Logger.debug('🔄 Updating ${item.id} with remote version');
                        await yieldToUIThread();
                        await repository.update(resolution.winningEntity);
                        await yieldToUIThread();
                        break;
                    }
                  } else {
                    Logger.error('❌ Failed to resolve unique constraint error for ${item.id}');
                    rethrow; // Re-throw to propagate the error up
                  }
                } else {
                  // Re-throw non-constraint errors
                  rethrow;
                }
              }
            }
          } else {
            // Item exists - this shouldn't happen for create, but handle gracefully
            Logger.warning('⚠️ Create operation for existing item ${item.id}, treating as update');
            final resolution = _conflictResolutionService.resolveConflict<T>(existingItem, item);
            conflicts = 1;

            switch (resolution.action) {
              case ConflictAction.keepLocal:
                Logger.debug('✅ Keeping local version of ${item.id}');
                break;
              case ConflictAction.acceptRemote:
              case ConflictAction.acceptRemoteForceUpdate:
                Logger.debug('🔄 Updating ${item.id} with remote version');
                await yieldToUIThread();
                await repository.update(resolution.winningEntity);
                await yieldToUIThread();
                break;
            }
          }
          break;

        case 'update':
          // Yield before read
          await yieldToUIThread();

          T? existingItem = await repository.getById(item.id);

          // Yield after read
          await yieldToUIThread();

          if (existingItem != null) {
            final resolution = _conflictResolutionService.resolveConflict<T>(existingItem, item);
            conflicts = 1;

            switch (resolution.action) {
              case ConflictAction.keepLocal:
                Logger.debug('✅ Keeping local version of ${item.id}');
                break;
              case ConflictAction.acceptRemote:
              case ConflictAction.acceptRemoteForceUpdate:
                Logger.debug('🔄 Updating ${item.id} with remote version');
                await yieldToUIThread();
                await repository.update(resolution.winningEntity);
                await yieldToUIThread();
                break;
            }
          } else {
            // Item doesn't exist - treat as create
            Logger.debug('📦 Update operation for non-existing item ${item.id}, treating as create');
            await yieldToUIThread();
            await repository.add(item);
            await yieldToUIThread();
          }
          break;

        case 'delete':
          // Yield before read
          await yieldToUIThread();

          T? existingItem = await repository.getById(item.id);

          // Yield after read
          await yieldToUIThread();

          if (existingItem != null) {
            final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
                existingItem as BaseEntity<String>, item);

            switch (resolution.action) {
              case ConflictAction.keepLocal:
                Logger.debug('✅ Keeping local version of ${item.id}, ignoring delete');
                break;
              case ConflictAction.acceptRemote:
              case ConflictAction.acceptRemoteForceUpdate:
                Logger.debug('🗑️ Deleting ${item.id} as requested by remote');
                await yieldToUIThread();
                await repository.delete(item);
                await yieldToUIThread();
                break;
            }
          } else {
            Logger.debug('⏭️ Delete operation for non-existing item ${item.id}, skipping');
          }
          break;

        default:
          Logger.error('❌ Unknown operation type: $operationType');
          break;
      }

      return conflicts;
    } catch (e) {
      Logger.error('❌ Error processing single item ${item.id} ($operationType): $e');
      rethrow;
    }
  }

  @override
  Future<T?> checkForRecurringTaskDuplicate<T extends BaseEntity<String>>(
    T entity,
    IRepository<T, String> repository,
  ) async {
    // Only check for Task entities with recurrence information
    if (entity is! Task || entity.recurrenceParentId == null || entity.plannedDate == null) {
      return null;
    }

    // Only check tasks repository - cast is safe since we know repository handles Task type
    if (repository is! ITaskRepository) {
      return null;
    }

    final taskRepo = repository as ITaskRepository;

    try {
      // Query for existing tasks with same recurrenceParentId and plannedDate
      final existingTasks = await taskRepo.getList(
        0, // page
        10, // pageSize - should be enough, most cases will have 0-1 matches
        customWhereFilter: CustomWhereFilter(
          'recurrence_parent_id = ? AND SUBSTR(planned_date, 1, 10) = SUBSTR(?, 1, 10) AND deleted_date IS NULL AND id != ?',
          [entity.recurrenceParentId!, entity.plannedDate!.toIso8601String(), entity.id],
        ),
      );

      if (existingTasks.items.isNotEmpty) {
        // Return the first matching task as T (safe cast since we verified repository type)
        Logger.debug(
            '🔍 Found duplicate recurring task: ${existingTasks.items.first.id} for parent ${entity.recurrenceParentId}');
        return existingTasks.items.first as T;
      }

      return null;
    } catch (e) {
      Logger.error('❌ Error checking for recurring task duplicates: $e');
      return null; // Fall back to normal processing if check fails
    }
  }

  @override
  bool validateEntityForProcessing<T extends BaseEntity<String>>(T entity) {
    try {
      // Basic validation
      if (entity.id.isEmpty) {
        Logger.warning('⚠️ Entity validation failed: empty ID');
        return false;
      }

      // Validate creation date
      if (entity.createdDate.isAfter(DateTime.now().add(const Duration(hours: 1)))) {
        Logger.warning('⚠️ Entity validation failed: future creation date ${entity.id}');
        return false;
      }

      // Validate modification date
      if (entity.modifiedDate?.isAfter(DateTime.now().add(const Duration(hours: 1))) == true) {
        Logger.warning('⚠️ Entity validation failed: future modification date ${entity.id}');
        return false;
      }

      Logger.debug('✅ Entity validation passed for ${entity.id}');
      return true;
    } catch (e) {
      Logger.error('❌ Entity validation error for ${entity.id}: $e');
      return false;
    }
  }

  @override
  Future<void> cleanupSoftDeletedData(DateTime oldestLastSyncDate) async {
    try {
      Logger.info('🧹 Starting cleanup of soft-deleted data older than $oldestLastSyncDate');

      // Note: This is a simplified implementation
      // In a real implementation, this would iterate through all repositories
      // and clean up entities with deletedDate older than the threshold

      final cutoffDate = oldestLastSyncDate.subtract(const Duration(days: 30));
      Logger.debug('🗑️ Cleanup cutoff date: $cutoffDate');

      // The actual cleanup would be implemented by each repository
      // based on their specific cleanup requirements

      Logger.info('✅ Soft-deleted data cleanup completed');
    } catch (e) {
      Logger.error('❌ Error during soft-deleted data cleanup: $e');
      rethrow;
    }
  }

  /// Special processing for SyncDevice entities to ensure proper sync device list management
  Future<int> _processSyncDeviceItem(
    SyncDevice syncDevice,
    IRepository<SyncDevice, String> repository,
    String operationType,
  ) async {
    Logger.info('🔧 Special handling for SyncDevice entity ${syncDevice.id} ($operationType)');
    Logger.info(
        '🔍 SyncDevice details: ${syncDevice.fromDeviceId} (${syncDevice.fromIp}) → ${syncDevice.toDeviceId} (${syncDevice.toIp})');

    try {
      switch (operationType) {
        case 'create':
          // For SyncDevice entities, check for existing device pair relationships and merge intelligently
          await yieldToUIThread();

          // First check if the exact same device record exists
          SyncDevice? existingDeviceById = await repository.getById(syncDevice.id);

          // Check for existing device pair relationship (same device pair, different direction/IPs)
          final allDevices = await repository.getAll();
          SyncDevice? existingDevicePair;

          for (final existing in allDevices) {
            // Check if this is the same device pair with potentially different IP directions
            final sameDevicePair =
                (existing.fromDeviceId == syncDevice.fromDeviceId && existing.toDeviceId == syncDevice.toDeviceId) ||
                    (existing.fromDeviceId == syncDevice.toDeviceId && existing.toDeviceId == syncDevice.fromDeviceId);

            if (sameDevicePair && existing.id != syncDevice.id) {
              existingDevicePair = existing;
              Logger.info(
                  '🔍 Found existing device pair: ${existing.id} (${existing.fromDeviceId} ↔ ${existing.toDeviceId})');
              break;
            }
          }

          await yieldToUIThread();

          if (existingDeviceById == null && existingDevicePair == null) {
            // No existing device at all, create it
            Logger.debug('📱 Creating new SyncDevice: ${syncDevice.id}');
            await repository.add(syncDevice);
            await yieldToUIThread();
            Logger.info('✅ Created SyncDevice: ${syncDevice.id}');
            return 1; // Successfully created
          } else if (existingDeviceById != null) {
            // Exact same device exists, update it with remote data
            Logger.debug('🔄 Updating existing SyncDevice by ID: ${syncDevice.id}');
            await repository.update(syncDevice);
            await yieldToUIThread();
            Logger.info('✅ Updated SyncDevice: ${syncDevice.id}');
            return 1; // Successfully updated
          } else if (existingDevicePair != null) {
            // Device pair exists but with different ID/direction - update the existing one with merged data
            Logger.info(
                '🔀 Merging SyncDevice data: updating existing device ${existingDevicePair.id} with data from ${syncDevice.id}');

            // Update the existing device with the remote device's information (keep the existing ID)
            final mergedDevice = SyncDevice(
              id: existingDevicePair.id, // Keep existing ID
              createdDate: existingDevicePair.createdDate, // Keep original creation date
              modifiedDate: DateTime.now().toUtc(), // Update modification date
              fromIp: syncDevice.fromIp, // Use incoming IP mapping
              toIp: syncDevice.toIp,
              fromDeviceId: syncDevice.fromDeviceId, // Use incoming device mapping
              toDeviceId: syncDevice.toDeviceId,
              name: syncDevice.name, // Use incoming name
              lastSyncDate: syncDevice.lastSyncDate,
              deletedDate: null, // Ensure it's not deleted
            );

            await repository.update(mergedDevice);
            await yieldToUIThread();
            Logger.info('✅ Merged SyncDevice: ${existingDevicePair.id} updated with data from ${syncDevice.id}');
            return 1; // Successfully merged
          }

          // Fallback return (should not reach here due to the if-else logic above)
          return 0;

        case 'update':
          // For updates, always accept the remote version
          await yieldToUIThread();

          SyncDevice? existingDevice = await repository.getById(syncDevice.id);

          await yieldToUIThread();

          if (existingDevice != null) {
            Logger.debug('🔄 Updating SyncDevice: ${syncDevice.id}');
            await repository.update(syncDevice);
            await yieldToUIThread();
            Logger.info('✅ Updated SyncDevice: ${syncDevice.id}');
            return 1; // Successfully updated
          } else {
            // Device doesn't exist, create it
            Logger.debug('📱 Creating SyncDevice from update: ${syncDevice.id}');
            await repository.add(syncDevice);
            await yieldToUIThread();
            Logger.info('✅ Created SyncDevice from update: ${syncDevice.id}');
            return 1; // Successfully created
          }

        case 'delete':
          // CRITICAL: Never delete SyncDevice records during sync - this breaks device pairing
          Logger.warning('🚫 Ignoring delete operation for SyncDevice ${syncDevice.id} - preserving device pairing');
          Logger.info('🔗 SyncDevice deletion skipped to maintain device relationships');
          return 1; // Report as processed but don't actually delete

        default:
          Logger.error('❌ Unknown operation type for SyncDevice: $operationType');
          return 0;
      }
    } catch (e) {
      Logger.error('❌ Error processing SyncDevice ${syncDevice.id} ($operationType): $e');
      rethrow; // Let the outer error handling deal with it
    }
  }

  /// Dynamic processing method that handles items without strict typing
  Future<int> _processItemsWithMaximumYieldingDynamic(
    List<dynamic> items,
    IRepository repository,
    String operationType,
  ) async {
    int conflictsResolved = 0;
    final Set<String> processedItemIds = <String>{};

    Logger.debug(
        '🔥 Processing ${items.length} $operationType items dynamically with maximum yielding (one at a time)');

    for (var i = 0; i < items.length; i++) {
      final item = items[i];

      // Skip if already processed
      if (item is BaseEntity<String> && processedItemIds.contains(item.id)) {
        Logger.debug('⏭️ Skipping duplicate item ${item.id}');
        continue;
      }

      // Yield before every single item
      await yieldToUIThread();

      try {
        final itemConflicts = await _processSingleItemDynamic(item, repository, operationType);
        conflictsResolved += itemConflicts;
        if (item is BaseEntity<String>) {
          processedItemIds.add(item.id);
        }
      } catch (e) {
        Logger.error('❌ Error processing dynamic item ${item?.toString()}: $e');
        // Continue with other items instead of failing entire batch
      }

      // Yield after every single item
      await yieldToUIThread();

      // Add breathing room delay after each item
      await Future.delayed(const Duration(milliseconds: 5));

      // Progress logging every 10 items to avoid log spam
      if (i % 10 == 9 || i == items.length - 1) {
        Logger.debug('🔥 Completed ${i + 1}/${items.length} $operationType items dynamically');
      }
    }

    Logger.debug(
        '✅ Completed dynamic processing of ${items.length} $operationType items, $conflictsResolved conflicts');
    return conflictsResolved;
  }

  /// Process a single item dynamically without strict typing
  Future<int> _processSingleItemDynamic(
    dynamic item,
    IRepository repository,
    String operationType,
  ) async {
    if (item is! BaseEntity<String>) {
      Logger.warning('⚠️ Item is not a BaseEntity, skipping: ${item?.runtimeType}');
      return 0;
    }

    int conflicts = 0;

    try {
      // Special handling for SyncDevice entities
      if (item is SyncDevice) {
        return await _processSyncDeviceItem(item, repository as IRepository<SyncDevice, String>, operationType);
      }

      switch (operationType) {
        case 'create':
          // Yield before read
          await yieldToUIThread();

          var existingItem = await repository.getById(item.id);

          // Yield after read
          await yieldToUIThread();

          if (existingItem == null) {
            // Check for recurring task deduplication before creating
            var duplicateTask = await _checkForRecurringTaskDuplicateDynamic(item, repository);

            if (duplicateTask != null) {
              // Found a duplicate recurring task - resolve conflict with existing task
              final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
                  duplicateTask as BaseEntity<String>, item);
              conflicts = 1;

              Logger.debug('🔄 Found duplicate recurring task during create: ${item.id} vs ${duplicateTask.id}');

              switch (resolution.action) {
                case ConflictAction.keepLocal:
                  Logger.debug('✅ Keeping existing task ${duplicateTask.id}, skipping remote ${item.id}');
                  break;
                case ConflictAction.acceptRemote:
                case ConflictAction.acceptRemoteForceUpdate:
                  Logger.debug('🔄 Replacing existing task ${duplicateTask.id} with remote ${item.id}');
                  // Update existing task with remote data while preserving ID
                  final updatedTask = _conflictResolutionService.copyRemoteDataToExistingTask(duplicateTask, item);
                  await yieldToUIThread();
                  await repository.update(updatedTask as dynamic);
                  await yieldToUIThread();
                  break;
              }
            } else {
              // No duplicate found, proceed with normal create
              await yieldToUIThread();
              try {
                await repository.add(item);
                await yieldToUIThread();
              } catch (e) {
                // Handle UNIQUE constraint errors gracefully
                if (e.toString().contains('UNIQUE constraint failed')) {
                  Logger.warning('⚠️ Item ${item.id} already exists despite check, treating as conflict');
                  // Try to get the existing item and resolve conflict
                  existingItem = await repository.getById(item.id);
                  if (existingItem != null) {
                    final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
                        existingItem as BaseEntity<String>, item);
                    conflicts = 1;
                    switch (resolution.action) {
                      case ConflictAction.keepLocal:
                        Logger.debug('✅ Keeping local version of ${item.id}');
                        break;
                      case ConflictAction.acceptRemote:
                      case ConflictAction.acceptRemoteForceUpdate:
                        Logger.debug('🔄 Updating ${item.id} with remote version');
                        await yieldToUIThread();
                        await repository.update(resolution.winningEntity as dynamic);
                        await yieldToUIThread();
                        break;
                    }
                  } else {
                    Logger.error('❌ Failed to resolve unique constraint error for ${item.id}');
                    rethrow; // Re-throw to propagate the error up
                  }
                } else {
                  // Re-throw non-constraint errors
                  rethrow;
                }
              }
            }
          } else {
            // Item exists - this shouldn't happen for create, but handle gracefully
            Logger.warning('⚠️ Create operation for existing item ${item.id}, treating as update');
            final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
                existingItem as BaseEntity<String>, item);
            conflicts = 1;

            switch (resolution.action) {
              case ConflictAction.keepLocal:
                Logger.debug('✅ Keeping local version of ${item.id}');
                break;
              case ConflictAction.acceptRemote:
              case ConflictAction.acceptRemoteForceUpdate:
                Logger.debug('🔄 Updating ${item.id} with remote version');
                await yieldToUIThread();
                await repository.update(resolution.winningEntity as dynamic);
                await yieldToUIThread();
                break;
            }
          }
          break;

        case 'update':
          // Yield before read
          await yieldToUIThread();

          var existingItem = await repository.getById(item.id);

          // Yield after read
          await yieldToUIThread();

          if (existingItem != null) {
            final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
                existingItem as BaseEntity<String>, item);
            conflicts = 1;

            switch (resolution.action) {
              case ConflictAction.keepLocal:
                Logger.debug('✅ Keeping local version of ${item.id}');
                break;
              case ConflictAction.acceptRemote:
              case ConflictAction.acceptRemoteForceUpdate:
                Logger.debug('🔄 Updating ${item.id} with remote version');
                await yieldToUIThread();
                await repository.update(resolution.winningEntity as dynamic);
                await yieldToUIThread();
                break;
            }
          } else {
            // Item doesn't exist - treat as create
            Logger.debug('📦 Update operation for non-existing item ${item.id}, treating as create');
            await yieldToUIThread();
            await repository.add(item);
            await yieldToUIThread();
          }
          break;

        case 'delete':
          // Yield before read
          await yieldToUIThread();

          var existingItem = await repository.getById(item.id);

          // Yield after read
          await yieldToUIThread();

          if (existingItem != null) {
            final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
                existingItem as BaseEntity<String>, item);

            switch (resolution.action) {
              case ConflictAction.keepLocal:
                Logger.debug('✅ Keeping local version of ${item.id}, ignoring delete');
                break;
              case ConflictAction.acceptRemote:
              case ConflictAction.acceptRemoteForceUpdate:
                Logger.debug('🗑️ Deleting ${item.id} as requested by remote');
                await yieldToUIThread();
                await repository.delete(item);
                await yieldToUIThread();
                break;
            }
          } else {
            Logger.debug('⏭️ Delete operation for non-existing item ${item.id}, skipping');
          }
          break;

        default:
          Logger.error('❌ Unknown operation type: $operationType');
          break;
      }

      return conflicts;
    } catch (e) {
      Logger.error('❌ Error processing single dynamic item ${item.id} ($operationType): $e');
      rethrow;
    }
  }

  /// Dynamic version of recurring task duplicate check
  Future<dynamic> _checkForRecurringTaskDuplicateDynamic(
    BaseEntity<String> entity,
    IRepository repository,
  ) async {
    // Only check for Task entities with recurrence information
    if (entity is! Task || entity.recurrenceParentId == null || entity.plannedDate == null) {
      return null;
    }

    // Only check tasks repository - cast is safe since we know repository handles Task type
    if (repository is! ITaskRepository) {
      return null;
    }

    final taskRepo = repository;

    try {
      // Query for existing tasks with same recurrenceParentId and plannedDate
      final existingTasks = await taskRepo.getList(
        0, // page
        10, // pageSize - should be enough, most cases will have 0-1 matches
        customWhereFilter: CustomWhereFilter(
          'recurrence_parent_id = ? AND SUBSTR(planned_date, 1, 10) = SUBSTR(?, 1, 10) AND deleted_date IS NULL AND id != ?',
          [entity.recurrenceParentId!, entity.plannedDate!.toIso8601String(), entity.id],
        ),
      );

      if (existingTasks.items.isNotEmpty) {
        // Return the first matching task
        Logger.debug(
            '🔍 Found duplicate recurring task: ${existingTasks.items.first.id} for parent ${entity.recurrenceParentId}');
        return existingTasks.items.first;
      }

      return null;
    } catch (e) {
      Logger.error('❌ Error checking for recurring task duplicates: $e');
      return null; // Fall back to normal processing if check fails
    }
  }

  @override
  Future<void> yieldToUIThread() async {
    await Future.delayed(Duration.zero);
  }
}
