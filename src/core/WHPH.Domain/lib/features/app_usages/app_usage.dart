import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class AppUsage extends BaseEntity<String> {
  String name;
  String? displayName;
  String? color;
  String? deviceName;

  AppUsage({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.name,
    this.displayName,
    this.color,
    this.deviceName,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'name': name,
        'displayName': displayName,
        'color': color,
        'deviceName': deviceName,
      };

  factory AppUsage.fromJson(Map<String, dynamic> json) {
    return AppUsage(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      name: json['name'] as String,
      displayName: json['displayName'] as String?,
      color: json['color'] as String?,
      deviceName: json['deviceName'] as String?,
    );
  }
}
