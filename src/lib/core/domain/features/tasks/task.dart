import 'dart:convert';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/shared/constants/domain_log_components.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/core/domain/features/tasks/models/recurrence_configuration.dart';

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
  custom,
}

/// Extension for ReminderTime enum to provide parsing functionality
extension ReminderTimeExtension on ReminderTime {
  /// Parses a string value into a ReminderTime enum.
  /// Returns the default reminder time if the value is invalid or not found.
  static ReminderTime fromString(String? value) {
    return ReminderTime.values.firstWhere(
      (e) => e.name == value || e.toString() == value,
      orElse: () => TaskConstants.defaultReminderTime,
    );
  }
}

/// Recurrence type options for recurring tasks
enum RecurrenceType {
  none,
  daily,
  daysOfWeek,
  weekly,
  monthly,
  yearly,
  hourly,
  minutely,
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

  // Custom reminder offsets (in minutes)
  int? plannedDateReminderCustomOffset;
  int? deadlineDateReminderCustomOffset;

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

  // Advanced Recurrence Configuration
  RecurrenceConfiguration? recurrenceConfiguration;

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
    this.plannedDateReminderCustomOffset,
    this.deadlineDateReminderCustomOffset,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceInterval,
    this.recurrenceDaysString,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
    this.recurrenceCount,
    this.recurrenceParentId,
    this.recurrenceConfiguration,
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
        'plannedDateReminderTime': plannedDateReminderTime.name,
        'deadlineDateReminderTime': deadlineDateReminderTime.name,
        'plannedDateReminderCustomOffset': plannedDateReminderCustomOffset,
        'deadlineDateReminderCustomOffset': deadlineDateReminderCustomOffset,
        'recurrenceType': recurrenceType.toString(),
        'recurrenceInterval': recurrenceInterval,
        'recurrenceDaysString': recurrenceDaysString,
        'recurrenceStartDate': recurrenceStartDate?.toIso8601String(),
        'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
        'recurrenceCount': recurrenceCount,
        'recurrenceParentId': recurrenceParentId,
        'recurrenceConfiguration':
            recurrenceConfiguration != null ? JsonMapper.serialize(recurrenceConfiguration) : null,
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
    int? plannedDateReminderCustomOffset,
    int? deadlineDateReminderCustomOffset,
    RecurrenceType? recurrenceType,
    int? recurrenceInterval,
    String? recurrenceDaysString,
    DateTime? recurrenceStartDate,
    DateTime? recurrenceEndDate,
    int? recurrenceCount,
    String? recurrenceParentId,
    RecurrenceConfiguration? recurrenceConfiguration,
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
      plannedDateReminderCustomOffset: plannedDateReminderCustomOffset ?? this.plannedDateReminderCustomOffset,
      deadlineDateReminderCustomOffset: deadlineDateReminderCustomOffset ?? this.deadlineDateReminderCustomOffset,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceDaysString: recurrenceDaysString ?? this.recurrenceDaysString,
      recurrenceStartDate: recurrenceStartDate ?? this.recurrenceStartDate,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      recurrenceParentId: recurrenceParentId ?? this.recurrenceParentId,
      recurrenceConfiguration: recurrenceConfiguration ?? this.recurrenceConfiguration,
    );
  }

  // Helper method to parse enums with error handling
  static T _parseEnum<T>(List<T> values, String? value, T defaultValue, String enumName) {
    if (value == null) return defaultValue;
    return values.firstWhere(
      (e) {
        if (e.toString() == value) return true;
        try {
          return (e as dynamic).name == value;
        } catch (_) {
          return false;
        }
      },
      orElse: () {
        // Only log warning if the value is strictly invalid (not just a mismatch that leads to default)
        // AND it's not one of the expected "empty/none" values that might be passed casually.
        // For "none" specifically, it's often used as a string equivalent for RecurrenceType.none or ReminderTime.none
        // so we shouldn't warn if it simply resolves to the default which is also none.
        bool matchesName = false;
        try {
          matchesName = value == (defaultValue as dynamic).name;
        } catch (_) {}

        final isDefaultOrNone = value == 'none' ||
            value == 'RecurrenceType.none' ||
            value == 'ReminderTime.none' ||
            value == defaultValue.toString() ||
            matchesName;

        if (!isDefaultOrNone) {
          Logger.warning('Invalid $enumName value "$value", defaulting to $defaultValue',
              component: DomainLogComponents.task);
        }
        return defaultValue;
      },
    );
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

      // Handle custom reminder offsets with validation
      int? plannedDateReminderCustomOffset;
      final plannedOffsetValue = json['plannedDateReminderCustomOffset'];
      if (plannedOffsetValue is num) {
        plannedDateReminderCustomOffset = plannedOffsetValue.toInt();
        if (!ReminderOffsets.isValidCustomOffset(plannedDateReminderCustomOffset)) {
          Logger.warning(
              'Invalid plannedDateReminderCustomOffset value "$plannedDateReminderCustomOffset", ignoring value',
              component: DomainLogComponents.task);
          plannedDateReminderCustomOffset = null;
        }
      }

      int? deadlineDateReminderCustomOffset;
      final deadlineOffsetValue = json['deadlineDateReminderCustomOffset'];
      if (deadlineOffsetValue is num) {
        deadlineDateReminderCustomOffset = deadlineOffsetValue.toInt();
        if (!ReminderOffsets.isValidCustomOffset(deadlineDateReminderCustomOffset)) {
          Logger.warning(
              'Invalid deadlineDateReminderCustomOffset value "$deadlineDateReminderCustomOffset", ignoring value',
              component: DomainLogComponents.task);
          deadlineDateReminderCustomOffset = null;
        }
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

      // Handle recurrence configuration deserialization manually
      RecurrenceConfiguration? recurrenceConfiguration;
      if (json['recurrenceConfiguration'] != null) {
        try {
          if (json['recurrenceConfiguration'] is String && (json['recurrenceConfiguration'] as String).isNotEmpty) {
            final Map<String, dynamic> decodedJson = jsonDecode(json['recurrenceConfiguration'] as String);
            recurrenceConfiguration = RecurrenceConfiguration.fromJson(decodedJson);
          } else if (json['recurrenceConfiguration'] is Map) {
            recurrenceConfiguration =
                RecurrenceConfiguration.fromJson(json['recurrenceConfiguration'] as Map<String, dynamic>);
          }
        } on FormatException catch (e, stackTrace) {
          Logger.error(
            'Invalid JSON in task recurrenceConfiguration [$TaskErrorIds.recurrenceConfigInvalidJson]',
            error: e,
            stackTrace: stackTrace,
            component: DomainLogComponents.task,
          );
          rethrow;
        } on TypeError catch (e, stackTrace) {
          Logger.error(
            'Invalid task recurrenceConfiguration data structure [$TaskErrorIds.recurrenceConfigInvalidStructure]',
            error: e,
            stackTrace: stackTrace,
            component: DomainLogComponents.task,
          );
          rethrow;
        } catch (e, stackTrace) {
          Logger.error(
            'Unexpected error deserializing task recurrenceConfiguration [$TaskErrorIds.recurrenceConfigDeserializeError]',
            error: e,
            stackTrace: stackTrace,
            component: DomainLogComponents.task,
          );
          rethrow;
        }
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
        plannedDateReminderCustomOffset: plannedDateReminderCustomOffset,
        deadlineDateReminderCustomOffset: deadlineDateReminderCustomOffset,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        recurrenceDaysString: json['recurrenceDaysString'] as String?,
        recurrenceStartDate:
            json['recurrenceStartDate'] != null ? DateTime.parse(json['recurrenceStartDate'] as String) : null,
        recurrenceEndDate:
            json['recurrenceEndDate'] != null ? DateTime.parse(json['recurrenceEndDate'] as String) : null,
        recurrenceCount: recurrenceCount,
        recurrenceParentId: json['recurrenceParentId'] as String?,
        recurrenceConfiguration: recurrenceConfiguration,
      );
    } catch (e, stackTrace) {
      Logger.error('CRITICAL ERROR in Task.fromJson. JSON data keys: ${json.keys.toList()}',
          error: e, stackTrace: stackTrace, component: DomainLogComponents.task);
      rethrow;
    }
  }
}

/// Constants for reminder offset values and validation
class ReminderOffsets {
  static const int fiveMinutes = 5;
  static const int fifteenMinutes = 15;
  static const int oneHour = 60;
  static const int oneDay = 1440; // 24 * 60
  static const int oneWeek = 10080; // 7 * 24 * 60

  // Validation bounds
  static const int minCustomOffset = 1; // 1 minute minimum
  static const int maxCustomOffset = 525600; // 1 year maximum (60 * 24 * 365)

  /// Validates if a custom offset is within acceptable range
  static bool isValidCustomOffset(int? offset) {
    return offset != null && offset >= minCustomOffset && offset <= maxCustomOffset;
  }
}
