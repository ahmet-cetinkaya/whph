import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart';
import 'package:mediatr/mediatr.dart';

abstract class ITaskRecurrenceService {
  /// Checks if the task is recurring based on its recurrence type
  bool isRecurring(Task task);

  /// Checks if the next instance of a recurring task can be created
  bool canCreateNextInstance(Task task);

  /// Creates the next instance of a recurring task
  DateTime calculateNextRecurrenceDate(Task task, DateTime currentDate);

  /// Creates the next recurrence instance of a task
  List<WeekDays>? getRecurrenceDays(Task task);

  /// Handles a completed task and creates the next recurrence if needed
  Future<String?> handleCompletedRecurringTask(String taskId, Mediator mediator);
}
