import 'package:drift/drift.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:domain/features/tasks/models/recurrence_configuration.dart';
import 'dart:convert';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/domain_log_components.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';

/// Handles conversion between database rows and Task entities.
class TaskDataMapper {
  /// Converts a dynamic value to DateTime, handling various storage formats.
  DateTime? convertToDateTime(dynamic value, {String? fieldName}) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is int) {
      // Drift stores dates as seconds since epoch, not milliseconds
      // Multiply by 1000 to convert seconds to milliseconds
      // Always use UTC timezone for storage
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    if (value is String) {
      // Try to parse ISO 8601 string and ensure UTC
      final dateTime = DateTime.tryParse(value);
      if (dateTime != null) return dateTime.toUtc();
      DomainLogger.warning(
        'TaskDataMapper: Failed to parse DateTime from string: "$value"${fieldName != null ? " for field $fieldName" : ""}',
      );
      return null;
    }

    DomainLogger.warning(
      'TaskDataMapper: Unexpected DateTime value type: ${value.runtimeType} with value "$value"${fieldName != null ? " for field $fieldName" : ""}',
    );
    return null;
  }

  /// Maps a database row to a Task entity.
  Task mapTaskFromRow(Map<String, dynamic> data) {
    // Convert dates
    final plannedDate = convertToDateTime(data['planned_date']);
    final deadlineDate = convertToDateTime(data['deadline_date']);

    // Create a task with the base data
    final task = Task(
      id: data['id'] as String,
      createdDate: convertToDateTime(data['created_date']) ?? DateTime.now().toUtc(),
      modifiedDate: convertToDateTime(data['modified_date']),
      deletedDate: convertToDateTime(data['deleted_date']),
      title: data['title'] as String,
      description: data['description'] as String?,
      plannedDate: plannedDate,
      deadlineDate: deadlineDate,
      priority: data['priority'] != null ? EisenhowerPriority.values[data['priority'] as int] : null,
      estimatedTime: data['estimated_time'] as int?,
      completedAt: convertToDateTime(data['completed_at']),
      parentTaskId: data['parent_task_id'] as String?,
      order: (data['order'] is num) ? (data['order'] as num).toDouble() : 0.0,
      plannedDateReminderCustomOffset: data['planned_date_reminder_custom_offset'] as int?,
      deadlineDateReminderCustomOffset: data['deadline_date_reminder_custom_offset'] as int?,
    );

    // Explicitly set reminder values
    if (data['planned_date_reminder_time'] != null) {
      final reminderTimeValue = data['planned_date_reminder_time'] as int;
      if (reminderTimeValue >= 0 && reminderTimeValue < ReminderTime.values.length) {
        task.plannedDateReminderTime = ReminderTime.values[reminderTimeValue];
      }
    }

    if (data['deadline_date_reminder_time'] != null) {
      final reminderTimeValue = data['deadline_date_reminder_time'] as int;
      if (reminderTimeValue >= 0 && reminderTimeValue < ReminderTime.values.length) {
        task.deadlineDateReminderTime = ReminderTime.values[reminderTimeValue];
      }
    }

    // Set recurrence values
    if (data['recurrence_type'] != null) {
      final recurrenceTypeValue = data['recurrence_type'] as int;
      if (recurrenceTypeValue >= 0 && recurrenceTypeValue < RecurrenceType.values.length) {
        task.recurrenceType = RecurrenceType.values[recurrenceTypeValue];
      }
    }

    task.recurrenceInterval = data['recurrence_interval'] as int?;
    task.recurrenceDaysString = data['recurrence_days_string'] as String?;
    task.recurrenceStartDate = convertToDateTime(data['recurrence_start_date']);
    task.recurrenceEndDate = convertToDateTime(data['recurrence_end_date']);
    task.recurrenceCount = data['recurrence_count'] as int?;
    task.recurrenceParentId = data['recurrence_parent_id'] as String?;

    // RecurrenceConfiguration
    if (data['recurrence_configuration'] != null && (data['recurrence_configuration'] as String).isNotEmpty) {
      try {
        task.recurrenceConfiguration = RecurrenceConfiguration.fromJson(
            jsonDecode(data['recurrence_configuration'] as String) as Map<String, dynamic>);
      } catch (e, stackTrace) {
        DomainLogger.error(
          'Failed to deserialize RecurrenceConfiguration for task ${data['id']} - task will be loaded without recurrence configuration [$TaskErrorIds.recurrenceConfigInvalidJson]',
          error: e,
          stackTrace: stackTrace,
          component: DomainLogComponents.task,
        );
        // Continue loading the task without recurrence configuration
        // The task can still be viewed and edited, just won't recur
      }
    }

    return task;
  }

  /// Converts a Task entity to a database companion for insertion/update.
  TaskTableCompanion toCompanion(Task entity) {
    // Ensure all DateTime values are in UTC format
    DateTime? plannedDate = entity.plannedDate?.toUtc();
    DateTime? deadlineDate = entity.deadlineDate?.toUtc();
    DateTime? recurrenceStartDate = entity.recurrenceStartDate?.toUtc();
    DateTime? recurrenceEndDate = entity.recurrenceEndDate?.toUtc();

    return TaskTableCompanion.insert(
      id: entity.id,
      parentTaskId: Value(entity.parentTaskId),
      title: entity.title,
      description: Value(entity.description),
      priority: Value(entity.priority),
      plannedDate: Value(plannedDate),
      deadlineDate: Value(deadlineDate),
      estimatedTime: Value(entity.estimatedTime),
      completedAt: Value(entity.completedAt),
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      order: Value(entity.order),
      plannedDateReminderTime: Value(entity.plannedDateReminderTime),
      plannedDateReminderCustomOffset: Value(entity.plannedDateReminderCustomOffset),
      deadlineDateReminderTime: Value(entity.deadlineDateReminderTime),
      deadlineDateReminderCustomOffset: Value(entity.deadlineDateReminderCustomOffset),
      recurrenceType: Value(entity.recurrenceType),
      recurrenceInterval: Value(entity.recurrenceInterval),
      recurrenceDaysString: Value(entity.recurrenceDaysString),
      recurrenceStartDate: Value(recurrenceStartDate),
      recurrenceEndDate: Value(recurrenceEndDate),
      recurrenceCount: Value(entity.recurrenceCount),
      recurrenceParentId: Value(entity.recurrenceParentId),
      recurrenceConfiguration: Value(entity.recurrenceConfiguration),
    );
  }
}
