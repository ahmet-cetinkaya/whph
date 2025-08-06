import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

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

  /// Set recurrence days from a list of WeekDay enum values
  void setRecurrenceDays(List<WeekDays>? days) {
    if (days == null || days.isEmpty) {
      recurrenceDaysString = null;
      return;
    }
    recurrenceDaysString = days.map((day) => day.toString().split('.').last).join(',');
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'title': title,
        'description': description,
        'priority': priority?.toString(),
        'plannedDate': plannedDate?.toIso8601String(),
        'deadlineDate': deadlineDate?.toIso8601String(),
        'estimatedTime': estimatedTime,
        'isCompleted': isCompleted,
        'parentTaskId': parentTaskId,
        'order': order,
        'plannedDateReminderTime': plannedDateReminderTime.toString(),
        'deadlineDateReminderTime': deadlineDateReminderTime.toString(),
        'recurrenceType': recurrenceType.toString(),
        'recurrenceInterval': recurrenceInterval,
        'recurrenceDaysString': recurrenceDaysString,
        'recurrenceStartDate': recurrenceStartDate?.toIso8601String(),
        'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
        'recurrenceCount': recurrenceCount,
        'recurrenceParentId': recurrenceParentId,
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    // CRITICAL FIX: Handle type conversion for numeric fields that might come as different types
    // This ensures robust deserialization regardless of JSON source (database, API, sync, etc.)

    // Handle estimatedTime: might come as int, double, or null
    int? estimatedTime;
    if (json['estimatedTime'] != null) {
      final estimatedTimeValue = json['estimatedTime'];
      if (estimatedTimeValue is int) {
        estimatedTime = estimatedTimeValue;
      } else if (estimatedTimeValue is double) {
        estimatedTime = estimatedTimeValue.toInt();
      } else if (estimatedTimeValue is num) {
        estimatedTime = estimatedTimeValue.toInt();
      }
      // If it's not a number type, estimatedTime remains null
    }

    // Handle order: might come as int, double, or null
    double order = 0.0;
    if (json['order'] != null) {
      final orderValue = json['order'];
      if (orderValue is double) {
        order = orderValue;
      } else if (orderValue is int) {
        order = orderValue.toDouble();
      } else if (orderValue is num) {
        order = orderValue.toDouble();
      }
    }

    // Handle recurrenceInterval: ensure it's int
    int? recurrenceInterval;
    if (json['recurrenceInterval'] != null) {
      final intervalValue = json['recurrenceInterval'];
      if (intervalValue is int) {
        recurrenceInterval = intervalValue;
      } else if (intervalValue is num) {
        recurrenceInterval = intervalValue.toInt();
      }
    }

    // Handle recurrenceCount: ensure it's int
    int? recurrenceCount;
    if (json['recurrenceCount'] != null) {
      final countValue = json['recurrenceCount'];
      if (countValue is int) {
        recurrenceCount = countValue;
      } else if (countValue is num) {
        recurrenceCount = countValue.toInt();
      }
    }

    return Task(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: json['priority'] != null
          ? EisenhowerPriority.values.firstWhere((e) => e.toString() == json['priority'])
          : null,
      plannedDate: json['plannedDate'] != null ? DateTime.parse(json['plannedDate'] as String) : null,
      deadlineDate: json['deadlineDate'] != null ? DateTime.parse(json['deadlineDate'] as String) : null,
      estimatedTime: estimatedTime,
      isCompleted: json['isCompleted'] as bool? ?? false,
      parentTaskId: json['parentTaskId'] as String?,
      order: order,
      plannedDateReminderTime: json['plannedDateReminderTime'] != null
          ? ReminderTime.values.firstWhere((e) => e.toString() == json['plannedDateReminderTime'])
          : ReminderTime.none,
      deadlineDateReminderTime: json['deadlineDateReminderTime'] != null
          ? ReminderTime.values.firstWhere((e) => e.toString() == json['deadlineDateReminderTime'])
          : ReminderTime.none,
      recurrenceType: json['recurrenceType'] != null
          ? RecurrenceType.values.firstWhere((e) => e.toString() == json['recurrenceType'])
          : RecurrenceType.none,
      recurrenceInterval: recurrenceInterval,
      recurrenceDaysString: json['recurrenceDaysString'] as String?,
      recurrenceStartDate:
          json['recurrenceStartDate'] != null ? DateTime.parse(json['recurrenceStartDate'] as String) : null,
      recurrenceEndDate: json['recurrenceEndDate'] != null ? DateTime.parse(json['recurrenceEndDate'] as String) : null,
      recurrenceCount: recurrenceCount,
      recurrenceParentId: json['recurrenceParentId'] as String?,
    );
  }
}
