import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart' as app;

abstract class ITaskTimeRecordRepository extends app.IRepository<TaskTimeRecord, String> {
  Future<int> getTotalDurationByTaskId(
    String taskId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<TaskTimeRecord>> getByTaskId(String taskId);
}
