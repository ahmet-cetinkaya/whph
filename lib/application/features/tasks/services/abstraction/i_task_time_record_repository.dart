import 'package:whph/domain/features/tasks/task_time_record.dart';
import 'package:whph/persistence/shared/repositories/abstraction/i_repository.dart';

abstract class ITaskTimeRecordRepository extends IRepository<TaskTimeRecord, String> {
  Future<int> getTotalDurationByTaskId(
    String taskId, {
    DateTime? startDate,
    DateTime? endDate,
  });
}
