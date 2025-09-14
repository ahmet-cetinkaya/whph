import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class HabitTimeRecord extends BaseEntity<String> {
  String habitId;
  int duration;

  HabitTimeRecord({
    required super.id,
    required this.habitId,
    required this.duration,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'habitId': habitId,
        'duration': duration,
      };

  factory HabitTimeRecord.fromJson(Map<String, dynamic> json) {
    // Handle duration: might come as int, double, or num
    int duration = 0;
    final durationValue = json['duration'];
    if (durationValue is num) {
      duration = durationValue.toInt();
    }

    return HabitTimeRecord(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      habitId: json['habitId'] as String,
      duration: duration,
    );
  }
}
