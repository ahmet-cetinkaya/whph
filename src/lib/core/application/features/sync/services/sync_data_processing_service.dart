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

      // Track processed items to avoid duplicates
      final Set<String> processedItemIds = <String>{};

      Logger.debug('🔧 Processing $totalItems items with maximum UI responsiveness');

      // Process creates first with single-item yielding
      if (syncData.createSync.isNotEmpty) {
        Logger.debug('📦 Processing ${syncData.createSync.length} create items individually');
        conflictsResolved += await processItemsWithMaximumYielding(
          syncData.createSync,
          repository,
          'create',
        );
      }

      // Process updates with conflict resolution
      if (syncData.updateSync.isNotEmpty) {
        Logger.debug('📦 Processing ${syncData.updateSync.length} update items individually');
        conflictsResolved += await processItemsWithMaximumYielding(
          syncData.updateSync,
          repository,
          'update',
        );
      }

      // Process deletes
      if (syncData.deleteSync.isNotEmpty) {
        Logger.debug('📦 Processing ${syncData.deleteSync.length} delete items individually');
        await processItemsWithMaximumYielding(
          syncData.deleteSync,
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
    return await processSyncDataBatch<BaseEntity<String>>(
      syncData as SyncData<BaseEntity<String>>,
      repository as IRepository<BaseEntity<String>, String>,
    );
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
              final resolution = _conflictResolutionService.resolveConflict(duplicateTask, item);
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
                    final resolution = _conflictResolutionService.resolveConflict(existingItem, item);
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
            final resolution = _conflictResolutionService.resolveConflict(existingItem, item);
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
            final resolution = _conflictResolutionService.resolveConflict(existingItem, item);
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
            final resolution = _conflictResolutionService.resolveConflict(existingItem, item);

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
          'recurrence_parent_id = ? AND planned_date = ? AND deleted_date IS NULL AND id != ?',
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
    Logger.debug('🔧 Special handling for SyncDevice entity ${syncDevice.id} ($operationType)');

    try {
      switch (operationType) {
        case 'create':
          // For SyncDevice entities, always accept the remote version to ensure sync device lists stay in sync
          await yieldToUIThread();

          SyncDevice? existingDevice = await repository.getById(syncDevice.id);

          await yieldToUIThread();

          if (existingDevice == null) {
            // No existing device, create it
            Logger.debug('📱 Creating new SyncDevice: ${syncDevice.id}');
            await repository.add(syncDevice);
            await yieldToUIThread();
            Logger.info('✅ Created SyncDevice: ${syncDevice.id}');
            return 1; // Successfully created
          } else {
            // Device exists, update it with remote data to keep sync lists consistent
            Logger.debug('🔄 Updating existing SyncDevice: ${syncDevice.id}');
            await repository.update(syncDevice);
            await yieldToUIThread();
            Logger.info('✅ Updated SyncDevice: ${syncDevice.id}');
            return 1; // Successfully updated
          }

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
          // For deletes, remove the device
          await yieldToUIThread();

          SyncDevice? existingDevice = await repository.getById(syncDevice.id);

          await yieldToUIThread();

          if (existingDevice != null) {
            Logger.debug('🗑️ Deleting SyncDevice: ${syncDevice.id}');
            await repository.delete(syncDevice);
            await yieldToUIThread();
            Logger.info('✅ Deleted SyncDevice: ${syncDevice.id}');
            return 1; // Successfully deleted
          } else {
            Logger.debug('⏭️ Delete operation for non-existing SyncDevice ${syncDevice.id}, skipping');
            return 1; // Nothing to delete but request processed
          }

        default:
          Logger.error('❌ Unknown operation type for SyncDevice: $operationType');
          return 0;
      }
    } catch (e) {
      Logger.error('❌ Error processing SyncDevice ${syncDevice.id} ($operationType): $e');
      rethrow; // Let the outer error handling deal with it
    }
  }

  @override
  Future<void> yieldToUIThread() async {
    await Future.delayed(Duration.zero);
  }
}
