import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/domain/features/tasks/task.dart';

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
    super.completedAt,
    super.estimatedTime,
    super.parentTaskId,
    super.order = 0,
    super.plannedDateReminderTime = ReminderTime.none,
    super.plannedDateReminderCustomOffset,
    super.deadlineDateReminderTime = ReminderTime.none,
    super.deadlineDateReminderCustomOffset,
    super.recurrenceType = RecurrenceType.none,
    super.recurrenceInterval,
    super.recurrenceDaysString,
    super.recurrenceStartDate,
    super.recurrenceEndDate,
    super.recurrenceCount,
    super.recurrenceParentId,
    super.recurrenceConfiguration,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
  });
}
