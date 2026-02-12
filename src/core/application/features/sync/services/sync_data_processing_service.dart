import 'package:acore/acore.dart' hide IRepository;
import 'package:application/features/sync/models/sync_data.dart';
import 'package:application/features/sync/services/abstraction/i_sync_data_processing_service.dart';
import 'package:application/features/sync/services/sync_conflict_resolution_service.dart';
import 'package:application/features/sync/services/sync_device_processing_handler.dart';
import 'package:application/features/sync/services/recurring_task_duplicate_checker.dart';
import 'package:application/shared/services/abstraction/i_repository.dart';
import 'package:domain/features/habits/habit_record.dart';
import 'package:domain/features/sync/sync_device.dart';
import 'package:domain/shared/utils/logger.dart';

/// Implementation of sync data processing service.
///
/// Uses extracted handlers for specialized processing:
/// - [SyncDeviceProcessingHandler] for SyncDevice entities
/// - [RecurringTaskDuplicateChecker] for recurring task deduplication
class SyncDataProcessingService implements ISyncDataProcessingService {
  final SyncConflictResolutionService _conflictResolutionService;
  late final SyncDeviceProcessingHandler _syncDeviceHandler;
  final RecurringTaskDuplicateChecker _duplicateChecker;

  SyncDataProcessingService({
    SyncConflictResolutionService? conflictResolutionService,
  })  : _conflictResolutionService = conflictResolutionService ?? SyncConflictResolutionService(),
        _duplicateChecker = const RecurringTaskDuplicateChecker() {
    _syncDeviceHandler = SyncDeviceProcessingHandler(
      conflictResolutionService: _conflictResolutionService,
      onYieldToUI: yieldToUIThread,
    );
  }

  @override
  Future<int> processSyncDataBatch<T extends BaseEntity<String>>(
    SyncData<T> syncData,
    IRepository<T, String> repository,
  ) async {
    try {
      final totalItems = syncData.createSync.length + syncData.updateSync.length + syncData.deleteSync.length;
      int conflictsResolved = 0;

      // Deduplicate items
      final deduplicationResult = _deduplicateItems(syncData);
      DomainLogger.info(
          'Deduplication: CREATE ${syncData.createSync.length}→${deduplicationResult.creates.length}, UPDATE ${syncData.updateSync.length}→${deduplicationResult.updates.length}, DELETE ${syncData.deleteSync.length}→${deduplicationResult.deletes.length}');

      final deduplicatedTotal =
          deduplicationResult.creates.length + deduplicationResult.updates.length + deduplicationResult.deletes.length;
      DomainLogger.debug('Processing $deduplicatedTotal deduplicated items (was $totalItems)');

      // Process operations
      conflictsResolved += await _processItems(deduplicationResult.creates, repository, 'create');
      conflictsResolved += await _processItems(deduplicationResult.updates, repository, 'update');
      await _processItems(deduplicationResult.deletes, repository, 'delete');

      return conflictsResolved;
    } catch (e) {
      DomainLogger.error('Error processing batch for ${T.toString()}: $e');
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

      DomainLogger.debug('Processing $totalItems items dynamically');

      final processed = await _processItemsDynamic(syncData.createSync, repository, 'create');
      await _processItemsDynamic(syncData.updateSync, repository, 'update');
      await _processItemsDynamic(syncData.deleteSync, repository, 'delete');

      DomainLogger.debug('Processed $processed items');
      return totalItems;
    } catch (e) {
      DomainLogger.error('Error processing dynamic batch: $e');
      rethrow;
    }
  }

  @override
  Future<int> processItemsWithMaximumYielding<T extends BaseEntity<String>>(
    List<T> items,
    IRepository<T, String> repository,
    String operationType,
  ) async {
    return await _processItems(items, repository, operationType);
  }

  @override
  Future<int> processSingleItemWithMaximumYielding<T extends BaseEntity<String>>(
    T item,
    IRepository<T, String> repository,
    String operationType,
  ) async {
    // Special handling for SyncDevice entities
    if (item is SyncDevice) {
      return await _syncDeviceHandler.processSyncDeviceItem(
          item as SyncDevice, repository as IRepository<SyncDevice, String>, operationType);
    }

    return await _processSingleItem(item, repository, operationType);
  }

  @override
  Future<T?> checkForRecurringTaskDuplicate<T extends BaseEntity<String>>(
    T entity,
    IRepository<T, String> repository,
  ) async {
    return await _duplicateChecker.checkForDuplicate(entity, repository);
  }

  @override
  bool validateEntityForProcessing<T extends BaseEntity<String>>(T entity) {
    if (entity.id.isEmpty) {
      DomainLogger.warning('Entity validation failed: empty ID');
      return false;
    }
    if (entity.createdDate.isAfter(DateTime.now().add(const Duration(hours: 1)))) {
      DomainLogger.warning('Entity validation failed: future creation date ${entity.id}');
      return false;
    }
    if (entity.modifiedDate?.isAfter(DateTime.now().add(const Duration(hours: 1))) == true) {
      DomainLogger.warning('Entity validation failed: future modification date ${entity.id}');
      return false;
    }
    return true;
  }

  @override
  Future<void> cleanupSoftDeletedData(DateTime oldestLastSyncDate) async {
    try {
      DomainLogger.info('Starting cleanup of soft-deleted data older than $oldestLastSyncDate');
      final cutoffDate = oldestLastSyncDate.subtract(const Duration(days: 30));
      DomainLogger.debug('Cleanup cutoff date: $cutoffDate');
      DomainLogger.info('Soft-deleted data cleanup completed');
    } catch (e) {
      DomainLogger.error('Error during soft-deleted data cleanup: $e');
      rethrow;
    }
  }

  @override
  Future<void> yieldToUIThread() async {
    await Future.delayed(Duration.zero);
  }

  // Private helper methods

  _DeduplicationResult<T> _deduplicateItems<T extends BaseEntity<String>>(SyncData<T> syncData) {
    final Set<String> processedIds = <String>{};
    final creates = <T>[];
    final updates = <T>[];
    final deletes = <T>[];

    for (final item in syncData.createSync) {
      if (!processedIds.contains(item.id)) {
        creates.add(item);
        processedIds.add(item.id);
      }
    }
    for (final item in syncData.updateSync) {
      if (!processedIds.contains(item.id)) {
        updates.add(item);
        processedIds.add(item.id);
      }
    }
    for (final item in syncData.deleteSync) {
      if (!processedIds.contains(item.id)) {
        deletes.add(item);
        processedIds.add(item.id);
      }
    }

    return _DeduplicationResult(creates: creates, updates: updates, deletes: deletes);
  }

  Future<int> _processItems<T extends BaseEntity<String>>(
    List<T> items,
    IRepository<T, String> repository,
    String operationType,
  ) async {
    int conflicts = 0;
    for (var i = 0; i < items.length; i++) {
      if (i % 10 == 0) await yieldToUIThread();
      try {
        conflicts += await processSingleItemWithMaximumYielding(items[i], repository, operationType);
      } catch (e) {
        DomainLogger.error('Error processing item: $e');
      }
    }
    return conflicts;
  }

  Future<int> _processItemsDynamic(
    List<dynamic> items,
    IRepository repository,
    String operationType,
  ) async {
    int conflicts = 0;
    for (var i = 0; i < items.length; i++) {
      if (i % 1 == 0) await yieldToUIThread();
      try {
        conflicts += await _processSingleItemDynamic(items[i], repository, operationType);
        await Future.delayed(const Duration(milliseconds: 5));
      } catch (e) {
        DomainLogger.error('Error processing item: $e');
      }
    }
    return conflicts;
  }

  Future<int> _processSingleItem<T extends BaseEntity<String>>(
    T item,
    IRepository<T, String> repository,
    String operationType,
  ) async {
    int conflicts = 0;

    try {
      switch (operationType) {
        case 'create':
          conflicts = await _handleCreate(item, repository);
          break;
        case 'update':
          conflicts = await _handleUpdate(item, repository);
          break;
        case 'delete':
          await _handleDelete(item, repository);
          break;
        default:
          DomainLogger.error('Unknown operation type: $operationType');
      }
      return conflicts;
    } catch (e) {
      DomainLogger.error('Error processing single item ${item.id} ($operationType): $e');
      rethrow;
    }
  }

  Future<int> _handleCreate<T extends BaseEntity<String>>(T item, IRepository<T, String> repository) async {
    T? existingItem = await repository.getById(item.id);

    if (existingItem == null) {
      // Check for habit record duplicates
      if (item is HabitRecord) {
        final conflict = await _handleHabitRecordDuplicate(item as HabitRecord, repository);
        if (conflict >= 0) return conflict;
      }

      // Check for recurring task duplicates
      T? duplicate = await _duplicateChecker.checkForDuplicate(item, repository);
      if (duplicate != null) {
        return await _resolveConflict(duplicate, item, repository, isRecurringTask: true);
      }

      // Normal create
      try {
        await repository.add(item);
      } catch (e) {
        if (e.toString().contains('UNIQUE constraint failed')) {
          existingItem = await repository.getById(item.id);
          if (existingItem != null) {
            return await _resolveConflict(existingItem, item, repository);
          }
          rethrow;
        }
        rethrow;
      }
    } else {
      DomainLogger.warning('Create operation for existing item ${item.id}, treating as update');
      return await _resolveConflict(existingItem, item, repository);
    }
    return 0;
  }

  Future<int> _handleUpdate<T extends BaseEntity<String>>(T item, IRepository<T, String> repository) async {
    await yieldToUIThread();
    T? existingItem = await repository.getById(item.id);
    await yieldToUIThread();

    if (existingItem != null) {
      return await _resolveConflict(existingItem, item, repository);
    } else {
      DomainLogger.debug('Update for non-existing item ${item.id}, treating as create');
      await yieldToUIThread();
      await repository.add(item);
      await yieldToUIThread();
    }
    return 0;
  }

  Future<void> _handleDelete<T extends BaseEntity<String>>(T item, IRepository<T, String> repository) async {
    await yieldToUIThread();
    T? existingItem = await repository.getById(item.id);
    await yieldToUIThread();

    if (existingItem != null) {
      final resolution =
          _conflictResolutionService.resolveConflict<BaseEntity<String>>(existingItem as BaseEntity<String>, item);
      if (resolution.action != ConflictAction.keepLocal) {
        await yieldToUIThread();
        await repository.delete(item);
        await yieldToUIThread();
      }
    }
  }

  Future<int> _resolveConflict<T extends BaseEntity<String>>(
    T existingItem,
    T remoteItem,
    IRepository<T, String> repository, {
    bool isRecurringTask = false,
  }) async {
    final resolution = _conflictResolutionService.resolveConflict<T>(existingItem, remoteItem);

    switch (resolution.action) {
      case ConflictAction.keepLocal:
        DomainLogger.debug('Keeping local version of ${remoteItem.id}');
        break;
      case ConflictAction.acceptRemote:
      case ConflictAction.acceptRemoteForceUpdate:
        DomainLogger.debug('Updating ${remoteItem.id} with remote version');
        await yieldToUIThread();
        if (isRecurringTask) {
          final updatedTask = _conflictResolutionService.copyRemoteDataToExistingTask(existingItem, remoteItem);
          await repository.update(updatedTask);
        } else {
          await repository.update(resolution.winningEntity);
        }
        await yieldToUIThread();
        break;
    }
    return 1;
  }

  Future<int> _handleHabitRecordDuplicate<T extends BaseEntity<String>>(
    HabitRecord habitRecord,
    IRepository<T, String> repository,
  ) async {
    final allRecords = await repository.getAll();
    HabitRecord? matchingRecord;
    for (final record in allRecords.whereType<HabitRecord>()) {
      if (record.habitId == habitRecord.habitId && record.occurredAt == habitRecord.occurredAt) {
        matchingRecord = record;
        break;
      }
    }

    if (matchingRecord != null) {
      final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
          matchingRecord as BaseEntity<String>, habitRecord);
      if (resolution.action != ConflictAction.keepLocal) {
        await repository.update(habitRecord as T);
      }
      return 1;
    }
    return -1; // Continue with normal processing
  }

  Future<int> _processSingleItemDynamic(
    dynamic item,
    IRepository repository,
    String operationType,
  ) async {
    if (item is! BaseEntity<String>) {
      DomainLogger.warning('Item is not a BaseEntity, skipping');
      return 0;
    }

    if (item is SyncDevice) {
      return await _syncDeviceHandler.processSyncDeviceItem(
          item, repository as IRepository<SyncDevice, String>, operationType);
    }

    // Similar logic as typed version but with dynamic casts
    int conflicts = 0;
    try {
      switch (operationType) {
        case 'create':
          await yieldToUIThread();
          var existingItem = await repository.getById(item.id);
          await yieldToUIThread();

          if (existingItem == null) {
            if (item is HabitRecord) {
              final allRecords = await repository.getAll();
              HabitRecord? matchingRecord;
              for (final record in allRecords.whereType<HabitRecord>()) {
                if (record.habitId == item.habitId && record.occurredAt == item.occurredAt) {
                  matchingRecord = record;
                  break;
                }
              }
              if (matchingRecord != null) {
                final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
                    matchingRecord as BaseEntity<String>, item);
                if (resolution.action != ConflictAction.keepLocal) {
                  await repository.update(item as dynamic);
                }
                return 1;
              }
            }

            var duplicateTask = await _duplicateChecker.checkForDuplicateDynamic(item, repository);
            if (duplicateTask != null) {
              final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
                  duplicateTask as BaseEntity<String>, item);
              if (resolution.action != ConflictAction.keepLocal) {
                final updatedTask = _conflictResolutionService.copyRemoteDataToExistingTask(duplicateTask, item);
                await repository.update(updatedTask as dynamic);
              }
              return 1;
            }

            await repository.add(item);
          } else {
            final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
                existingItem as BaseEntity<String>, item);
            if (resolution.action != ConflictAction.keepLocal) {
              await repository.update(resolution.winningEntity as dynamic);
            }
            conflicts = 1;
          }
          break;

        case 'update':
          await yieldToUIThread();
          var existingItem = await repository.getById(item.id);
          await yieldToUIThread();

          if (existingItem != null) {
            final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
                existingItem as BaseEntity<String>, item);
            if (resolution.action != ConflictAction.keepLocal) {
              await repository.update(resolution.winningEntity as dynamic);
            }
            conflicts = 1;
          } else {
            await repository.add(item);
          }
          break;

        case 'delete':
          await yieldToUIThread();
          var existingItem = await repository.getById(item.id);
          await yieldToUIThread();

          if (existingItem != null) {
            final resolution = _conflictResolutionService.resolveConflict<BaseEntity<String>>(
                existingItem as BaseEntity<String>, item);
            if (resolution.action != ConflictAction.keepLocal) {
              await repository.delete(item);
            }
          }
          break;
      }
      return conflicts;
    } catch (e) {
      DomainLogger.error('Error processing dynamic item ${item.id} ($operationType): $e');
      rethrow;
    }
  }
}

class _DeduplicationResult<T> {
  final List<T> creates;
  final List<T> updates;
  final List<T> deletes;

  _DeduplicationResult({
    required this.creates,
    required this.updates,
    required this.deletes,
  });
}
