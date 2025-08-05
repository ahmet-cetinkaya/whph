import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class TaskTimeRecord extends BaseEntity<String> {
  String taskId;
  int duration;

  TaskTimeRecord({
    required super.id,
    required this.taskId,
    required this.duration,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'taskId': taskId,
        'duration': duration,
      };

  factory TaskTimeRecord.fromJson(Map<String, dynamic> json) {
    // Handle duration: might come as int, double, or num
    int duration = 0;
    if (json['duration'] != null) {
      final durationValue = json['duration'];
      if (durationValue is int) {
        duration = durationValue;
      } else if (durationValue is double) {
        duration = durationValue.toInt();
      } else if (durationValue is num) {
        duration = durationValue.toInt();
      }
    }

    return TaskTimeRecord(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      taskId: json['taskId'] as String,
      duration: duration,
    );
  }
}
