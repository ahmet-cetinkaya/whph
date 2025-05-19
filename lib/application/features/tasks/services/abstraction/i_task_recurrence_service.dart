import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/core/acore/time/week_days.dart';
import 'package:mediatr/mediatr.dart';

abstract class ITaskRecurrenceService {
  Task createNextRecurrenceInstance(Task task);
  bool isRecurring(Task task);
  bool canCreateNextInstance(Task task);
  DateTime calculateNextRecurrenceDate(Task task, DateTime currentDate);
  List<WeekDays>? getRecurrenceDays(Task task);

  /// Handles a completed task and creates the next recurrence if needed
  Future<String?> handleCompletedRecurringTask(String taskId, Mediator mediator);
}
