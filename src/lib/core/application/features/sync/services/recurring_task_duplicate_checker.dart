import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Utility for checking and handling recurring task duplicates during sync.
///
/// Consolidates the duplicate detection logic used in both typed and dynamic
/// processing paths.
class RecurringTaskDuplicateChecker {
  const RecurringTaskDuplicateChecker();

  /// Check for recurring task duplicates (typed version)
  Future<T?> checkForDuplicate<T extends BaseEntity<String>>(
    T entity,
    IRepository<T, String> repository,
  ) async {
    // Only check for Task entities with recurrence information
    if (entity is! Task || entity.recurrenceParentId == null || entity.plannedDate == null) {
      return null;
    }

    // Only check tasks repository - cast after type check is safe
    if (repository is! ITaskRepository) {
      return null;
    }

    final taskRepo = repository as ITaskRepository;
    return await _findDuplicateTask(taskRepo, entity) as T?;
  }

  /// Check for recurring task duplicates (dynamic version)
  Future<dynamic> checkForDuplicateDynamic(
    BaseEntity<String> entity,
    IRepository repository,
  ) async {
    // Only check for Task entities with recurrence information
    if (entity is! Task || entity.recurrenceParentId == null || entity.plannedDate == null) {
      return null;
    }

    // Only check tasks repository
    if (repository is! ITaskRepository) {
      return null;
    }

    return await _findDuplicateTask(repository, entity);
  }

  Future<Task?> _findDuplicateTask(ITaskRepository taskRepo, Task entity) async {
    try {
      // Query for existing tasks with same recurrenceParentId and plannedDate
      final existingTasks = await taskRepo.getList(
        0, // page
        10, // pageSize
        customWhereFilter: CustomWhereFilter(
          'recurrence_parent_id = ? AND DATE(planned_date) = DATE(?) AND deleted_date IS NULL AND id != ?',
          [entity.recurrenceParentId!, entity.plannedDate!.toIso8601String(), entity.id],
        ),
      );

      if (existingTasks.items.isNotEmpty) {
        Logger.debug(
            'Found duplicate recurring task: ${existingTasks.items.first.id} for parent ${entity.recurrenceParentId}');
        return existingTasks.items.first;
      }

      return null;
    } catch (e) {
      Logger.error('Error checking for recurring task duplicates: $e');
      return null;
    }
  }
}
