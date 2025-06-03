import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';

@jsonSerializable
class TaskWithTotalDuration extends Task {
  final int totalDuration;

  TaskWithTotalDuration({
    required super.id,
    required super.title,
    required this.totalDuration,
    super.priority,
    super.plannedDate,
    super.deadlineDate,
    super.isCompleted = false,
    super.estimatedTime,
    super.parentTaskId,
    super.order = 0,
    super.plannedDateReminderTime = ReminderTime.none,
    super.deadlineDateReminderTime = ReminderTime.none,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
  });
}
