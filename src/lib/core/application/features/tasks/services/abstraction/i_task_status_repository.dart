import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;
import 'package:whph/core/domain/features/tasks/task_status.dart';

abstract class ITaskStatusRepository extends app.IRepository<TaskStatus, String> {
  /// Checks if a status truly exists in the database.
  /// Used to distinguish virtual builtin statuses from persisted ones.
  Future<bool> existsInDb(String id);
}
