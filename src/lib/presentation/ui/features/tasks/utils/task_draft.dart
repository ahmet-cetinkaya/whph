import 'package:whph/core/domain/features/tasks/task.dart';

/// Initial values for creating a new task from a UI surface (e.g. board column
/// add-to-group, quick-add dialog, immediate creation).
///
/// All fields are optional; missing fields fall back to the platform default
/// (e.g. a default priority, an empty title, no tags).
class TaskDraft {
  final String? title;
  final List<String>? tagIds;
  final DateTime? plannedDate;
  final DateTime? deadlineDate;
  final EisenhowerPriority? priority;
  final int? estimatedTime;
  final bool? completed;
  final String? parentTaskId;

  const TaskDraft({
    this.title,
    this.tagIds,
    this.plannedDate,
    this.deadlineDate,
    this.priority,
    this.estimatedTime,
    this.completed,
    this.parentTaskId,
  });

  bool get isEmpty =>
      title == null &&
      tagIds == null &&
      plannedDate == null &&
      deadlineDate == null &&
      priority == null &&
      estimatedTime == null &&
      completed == null &&
      parentTaskId == null;
}
