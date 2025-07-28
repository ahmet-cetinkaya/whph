import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class AppUsageTimeRecord extends BaseEntity<String> {
  String appUsageId;
  int duration;
  DateTime usageDate;

  AppUsageTimeRecord({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.appUsageId,
    required this.duration,
    required this.usageDate,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'appUsageId': appUsageId,
        'duration': duration,
        'usageDate': usageDate.toIso8601String(),
      };

  factory AppUsageTimeRecord.fromJson(Map<String, dynamic> json) {
    return AppUsageTimeRecord(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      appUsageId: json['appUsageId'] as String,
      duration: json['duration'] as int,
      usageDate: DateTime.parse(json['usageDate'] as String),
    );
  }
}
