import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/core/acore/time/week_days.dart';

enum EisenhowerPriority {
  notUrgentNotImportant,
  urgentNotImportant,
  notUrgentImportant,
  urgentImportant,
}

/// Reminder time options for tasks
enum ReminderTime {
  none,
  atTime,
  fiveMinutesBefore,
  fifteenMinutesBefore,
  oneHourBefore,
  oneDayBefore,
}

/// Recurrence type options for recurring tasks
enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

@jsonSerializable
class Task extends BaseEntity<String> {
  String title;
  String? description;
  EisenhowerPriority? priority;
  DateTime? plannedDate;
  DateTime? deadlineDate;
  int? estimatedTime;
  bool isCompleted = false;
  String? parentTaskId;
  double order = 0;

  // Reminder settings
  @JsonProperty(defaultValue: 'ReminderTime.none')
  ReminderTime plannedDateReminderTime = ReminderTime.none;

  @JsonProperty(defaultValue: 'ReminderTime.none')
  ReminderTime deadlineDateReminderTime = ReminderTime.none;

  // Recurrence settings
  @JsonProperty(defaultValue: 'RecurrenceType.none')
  RecurrenceType recurrenceType = RecurrenceType.none;

  // For custom recurrence interval (e.g., every 3 days)
  int? recurrenceInterval;

  // For weekly recurrence on specific days - serialized as comma-separated list
  // e.g., "monday,friday"
  String? recurrenceDaysString;

  // Start and end date for recurrence
  DateTime? recurrenceStartDate;
  DateTime? recurrenceEndDate;

  // Number of occurrences (alternative to end date)
  int? recurrenceCount;

  // ID of the parent recurring task if this is an instance of a recurring task
  String? recurrenceParentId;

  Task({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.title,
    this.description,
    this.plannedDate,
    this.deadlineDate,
    this.priority,
    this.estimatedTime,
    required this.isCompleted,
    this.parentTaskId,
    this.order = 0.0,
    this.plannedDateReminderTime = ReminderTime.none,
    this.deadlineDateReminderTime = ReminderTime.none,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceInterval,
    this.recurrenceDaysString,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
    this.recurrenceCount,
    this.recurrenceParentId,
  });

  /// Returns the plannedDate value from entity in local time zone
  DateTime? getLocalPlannedDate() {
    return plannedDate != null ? DateTimeHelper.toLocalDateTime(plannedDate) : null;
  }

  /// Returns the deadlineDate value from entity in local time zone
  DateTime? getLocalDeadlineDate() {
    return deadlineDate != null ? DateTimeHelper.toLocalDateTime(deadlineDate) : null;
  }

  /// Formats the plannedDate value in local time zone and returns it as a string
  String getFormattedPlannedDate({String format = 'dd.MM.yyyy HH:mm'}) {
    return DateTimeHelper.formatDateTime(plannedDate, format: format);
  }

  /// Formats the deadlineDate value in local time zone and returns it as a string
  String getFormattedDeadlineDate({String format = 'dd.MM.yyyy HH:mm'}) {
    return DateTimeHelper.formatDateTime(deadlineDate, format: format);
  }

  /// Set recurrence days from a list of WeekDay enum values
  void setRecurrenceDays(List<WeekDays>? days) {
    if (days == null || days.isEmpty) {
      recurrenceDaysString = null;
      return;
    }
    recurrenceDaysString = days.map((day) => day.toString().split('.').last).join(',');
  }
}
