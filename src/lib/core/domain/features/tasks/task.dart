import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/shared/utils/logger.dart';

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
  DateTime? completedAt;
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

  // Computed getter for backward compatibility
  bool get isCompleted => completedAt != null;

  // Convenience method to mark task as completed
  void markCompleted() {
    completedAt = DateTime.now().toUtc();
  }

  // Convenience method to mark task as not completed
  void markNotCompleted() {
    completedAt = null;
  }

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
    this.completedAt,
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
        'completedAt': completedAt?.toIso8601String(),
        'isCompleted': isCompleted, // Backward compatibility
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

  /// Creates a copy of this Task with specified fields replaced by the new values.
  /// The id field is preserved by default unless explicitly changed.
  Task copyWith({
    String? id,
    DateTime? createdDate,
    DateTime? modifiedDate,
    DateTime? deletedDate,
    String? title,
    String? description,
    EisenhowerPriority? priority,
    DateTime? plannedDate,
    DateTime? deadlineDate,
    int? estimatedTime,
    DateTime? completedAt,
    String? parentTaskId,
    double? order,
    ReminderTime? plannedDateReminderTime,
    ReminderTime? deadlineDateReminderTime,
    RecurrenceType? recurrenceType,
    int? recurrenceInterval,
    String? recurrenceDaysString,
    DateTime? recurrenceStartDate,
    DateTime? recurrenceEndDate,
    int? recurrenceCount,
    String? recurrenceParentId,
  }) {
    return Task(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      plannedDate: plannedDate ?? this.plannedDate,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      completedAt: completedAt ?? this.completedAt,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      order: order ?? this.order,
      plannedDateReminderTime: plannedDateReminderTime ?? this.plannedDateReminderTime,
      deadlineDateReminderTime: deadlineDateReminderTime ?? this.deadlineDateReminderTime,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceDaysString: recurrenceDaysString ?? this.recurrenceDaysString,
      recurrenceStartDate: recurrenceStartDate ?? this.recurrenceStartDate,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      recurrenceParentId: recurrenceParentId ?? this.recurrenceParentId,
    );
  }

  // Helper method to parse enums with error handling
  static T _parseEnum<T>(List<T> values, String? value, T defaultValue, String enumName) {
    if (value == null) return defaultValue;
    try {
      return values.firstWhere((e) => e.toString() == value);
    } catch (e) {
      Logger.warning('⚠️ Task.fromJson: Invalid $enumName value "$value", defaulting to $defaultValue');
      return defaultValue;
    }
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    try {
      // CRITICAL FIX: Handle type conversion for numeric fields that might come as different types
      // This ensures robust deserialization regardless of JSON source (database, API, sync, etc.)

      // Handle estimatedTime: might come as int, double, or null
      int? estimatedTime;
      final estimatedTimeValue = json['estimatedTime'];
      if (estimatedTimeValue is num) {
        estimatedTime = estimatedTimeValue.toInt();
      }

      // Handle order: might come as int, double, or null
      double order = 0.0;
      final orderValue = json['order'];
      if (orderValue is num) {
        order = orderValue.toDouble();
      }

      // Handle recurrenceInterval: ensure it's int
      int? recurrenceInterval;
      final intervalValue = json['recurrenceInterval'];
      if (intervalValue is num) {
        recurrenceInterval = intervalValue.toInt();
      }

      // Handle recurrenceCount: ensure it's int
      int? recurrenceCount;
      final countValue = json['recurrenceCount'];
      if (countValue is num) {
        recurrenceCount = countValue.toInt();
      }

      // Handle enum parsing with better error handling
      final priority = json['priority'] != null
          ? _parseEnum<EisenhowerPriority?>(EisenhowerPriority.values, json['priority'], null, 'priority')
          : null;

      final plannedDateReminderTime = _parseEnum(
          ReminderTime.values, json['plannedDateReminderTime'], ReminderTime.none, 'plannedDateReminderTime');

      final deadlineDateReminderTime = _parseEnum(
          ReminderTime.values, json['deadlineDateReminderTime'], ReminderTime.none, 'deadlineDateReminderTime');

      final recurrenceType =
          _parseEnum(RecurrenceType.values, json['recurrenceType'], RecurrenceType.none, 'recurrenceType');

      // Handle backward compatibility for isCompleted -> completedAt migration
      DateTime? completedAt;
      if (json['completedAt'] != null) {
        completedAt = DateTime.parse(json['completedAt'] as String);
      } else if (json['isCompleted'] == true) {
        // Migrate old isCompleted=true to a default completed timestamp
        completedAt = json['modifiedDate'] != null
            ? DateTime.parse(json['modifiedDate'] as String)
            : json['createdDate'] != null
                ? DateTime.parse(json['createdDate'] as String)
                : DateTime.now();
      }

      return Task(
        id: json['id'] as String,
        createdDate: DateTime.parse(json['createdDate'] as String),
        modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
        deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
        title: json['title'] as String,
        description: json['description'] as String?,
        priority: priority,
        plannedDate: json['plannedDate'] != null ? DateTime.parse(json['plannedDate'] as String) : null,
        deadlineDate: json['deadlineDate'] != null ? DateTime.parse(json['deadlineDate'] as String) : null,
        estimatedTime: estimatedTime,
        completedAt: completedAt,
        parentTaskId: json['parentTaskId'] as String?,
        order: order,
        plannedDateReminderTime: plannedDateReminderTime,
        deadlineDateReminderTime: deadlineDateReminderTime,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        recurrenceDaysString: json['recurrenceDaysString'] as String?,
        recurrenceStartDate:
            json['recurrenceStartDate'] != null ? DateTime.parse(json['recurrenceStartDate'] as String) : null,
        recurrenceEndDate:
            json['recurrenceEndDate'] != null ? DateTime.parse(json['recurrenceEndDate'] as String) : null,
        recurrenceCount: recurrenceCount,
        recurrenceParentId: json['recurrenceParentId'] as String?,
      );
    } catch (e, stackTrace) {
      Logger.error('❌ CRITICAL ERROR in Task.fromJson: $e');
      Logger.error('❌ JSON data keys: ${json.keys.toList()}');
      Logger.error('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }
}
