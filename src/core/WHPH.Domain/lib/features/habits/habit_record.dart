import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';
import 'habit_record_status.dart';

@jsonSerializable
class HabitRecord extends BaseEntity<String> {
  String habitId;
  DateTime occurredAt;
  HabitRecordStatus status;

  HabitRecord({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.habitId,
    required this.occurredAt,
    this.status = HabitRecordStatus.complete,
  });

  /// Get the date part of the occurrence (without time)
  DateTime get recordDate {
    return DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'habitId': habitId,
        'occurredAt': occurredAt.toIso8601String(),
        'status': status.value,
      };

  factory HabitRecord.fromJson(Map<String, dynamic> json) {
    // Handle status field that can be either String (from JSON) or int (from database)
    final dynamic statusValue = json['status'];
    HabitRecordStatus status = HabitRecordStatus.complete;

    if (statusValue is int) {
      // Status is stored as int in database (enum index: 0=complete, 1=notDone, 2=skipped)
      if (statusValue >= 0 && statusValue < HabitRecordStatus.values.length) {
        status = HabitRecordStatus.values[statusValue];
      }
    } else if (statusValue is String) {
      // Status is a String from JSON serialization
      status = HabitRecordStatus.fromString(statusValue);
    }

    return HabitRecord(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      habitId: json['habitId'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      status: status,
    );
  }
}
