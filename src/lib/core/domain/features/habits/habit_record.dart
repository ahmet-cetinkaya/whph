import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class HabitRecord extends BaseEntity<String> {
  String habitId;
  DateTime? occurredAt;

  HabitRecord({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.habitId,
    this.occurredAt,
  });

  /// Get the date part of the occurrence (without time)
  /// Falls back to createdDate if occurredAt is null (for backward compatibility during migration)
  DateTime get recordDate {
    final dateTime = occurredAt ?? createdDate;
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'habitId': habitId,
        'occurredAt': occurredAt?.toIso8601String(),
      };

  factory HabitRecord.fromJson(Map<String, dynamic> json) {
    return HabitRecord(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      habitId: json['habitId'] as String,
      occurredAt: json['occurredAt'] != null ? DateTime.parse(json['occurredAt'] as String) : null,
    );
  }
}
