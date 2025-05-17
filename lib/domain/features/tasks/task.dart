import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';

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

  Task(
      {required super.id,
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
      this.deadlineDateReminderTime = ReminderTime.none});

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
}
