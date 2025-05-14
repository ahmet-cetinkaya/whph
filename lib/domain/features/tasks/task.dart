import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

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
}
