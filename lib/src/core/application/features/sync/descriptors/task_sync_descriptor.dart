import 'package:whph/src/core/application/features/sync/models/v2/sync_entity_descriptor.dart';
import 'package:whph/src/core/application/features/sync/models/v2/sync_data.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

/// Sync descriptor for Task entities
class TaskSyncDescriptor extends SyncEntityDescriptor<Task> {
  final ITaskRepository _taskRepository;

  TaskSyncDescriptor(this._taskRepository);

  @override
  String get entityType => 'Task';

  @override
  ITaskRepository get repository => _taskRepository;

  @override
  int get syncPriority => 50; // Medium priority

  @override
  Map<String, dynamic> serialize(Task task) {
    Logger.debug('🔄 TaskSyncDescriptor: Serializing task ${task.id}');
    return task.toJson();
  }

  @override
  Task deserialize(Map<String, dynamic> data) {
    Logger.debug('🔄 TaskSyncDescriptor: Deserializing task ${data['id']}');
    return Task.fromJson(data);
  }

  @override
  Future<SyncData<Task>> getPaginatedSyncData(
    DateTime lastSyncDate, {
    required int pageIndex,
    required int pageSize,
  }) async {
    Logger.debug('🔄 TaskSyncDescriptor: Getting paginated sync data - page $pageIndex, size $pageSize, lastSync: $lastSyncDate');
    
    try {
      // Get paginated sync data from repository
      final paginatedData = await _taskRepository.getPaginatedSyncData(
        lastSyncDate,
        pageIndex: pageIndex,
        pageSize: pageSize,
        entityType: entityType,
      );

      // Convert to new format
      final syncData = SyncData.fromRepository(
        creates: paginatedData.data.createSync,
        updates: paginatedData.data.updateSync,
        deletes: paginatedData.data.deleteSync,
        pageIndex: pageIndex,
        pageSize: pageSize,
        totalItems: paginatedData.totalItems,
        entityType: entityType,
      );

      Logger.debug('🔄 TaskSyncDescriptor: Retrieved ${syncData.itemCount} tasks (creates: ${syncData.createSync.length}, updates: ${syncData.updateSync.length}, deletes: ${syncData.deleteSync.length})');
      
      return syncData;
    } catch (e, stackTrace) {
      Logger.error('🔄 TaskSyncDescriptor: Error getting paginated sync data: $e');
      Logger.error('StackTrace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> processSyncData(SyncData<Task> syncData) async {
    Logger.info('🔄 TaskSyncDescriptor: Processing ${syncData.itemCount} tasks from sync');
    
    try {
      // Process creates
      for (final task in syncData.createSync) {
        if (isValid(task)) {
          await _taskRepository.add(task);
          Logger.debug('🔄 TaskSyncDescriptor: Created task ${task.id}');
        } else {
          Logger.warning('🔄 TaskSyncDescriptor: Skipping invalid task for creation: ${task.id}');
        }
      }

      // Process updates
      for (final task in syncData.updateSync) {
        if (isValid(task)) {
          await _taskRepository.update(task);
          Logger.debug('🔄 TaskSyncDescriptor: Updated task ${task.id}');
        } else {
          Logger.warning('🔄 TaskSyncDescriptor: Skipping invalid task for update: ${task.id}');
        }
      }

      // Process deletes
      for (final task in syncData.deleteSync) {
        await _taskRepository.delete(task);
        Logger.debug('🔄 TaskSyncDescriptor: Deleted task ${task.id}');
      }

      Logger.info('🔄 TaskSyncDescriptor: Successfully processed ${syncData.itemCount} tasks');
    } catch (e, stackTrace) {
      Logger.error('🔄 TaskSyncDescriptor: Error processing sync data: $e');
      Logger.error('StackTrace: $stackTrace');
      rethrow;
    }
  }

  @override
  bool isValid(Task task) {
    // Basic validation
    if (task.id.isEmpty) {
      Logger.warning('🔄 TaskSyncDescriptor: Task validation failed - empty ID');
      return false;
    }
    
    if (task.title.isEmpty) {
      Logger.warning('🔄 TaskSyncDescriptor: Task validation failed - empty title for ${task.id}');
      return false;
    }

    return true;
  }

  @override
  String toString() => 'TaskSyncDescriptor(priority: $syncPriority)';
}