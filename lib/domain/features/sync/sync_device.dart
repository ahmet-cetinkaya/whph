import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class SyncDevice extends BaseEntity<String> {
  String fromIp;
  String toIp;
  String? name;
  DateTime? lastSyncDate;

  SyncDevice({
    required super.id,
    required super.createdDate,
    required this.fromIp,
    required this.toIp,
    super.modifiedDate,
    super.deletedDate,
    this.name,
    this.lastSyncDate,
  });

  factory SyncDevice.fromJson(Map<String, dynamic> json) {
    return SyncDevice(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      fromIp: json['fromIp'] as String,
      toIp: json['toIp'] as String,
      name: json['name'] as String?,
      lastSyncDate: json['lastSyncDate'] != null ? DateTime.parse(json['lastSyncDate'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate?.toIso8601String(),
        'deletedDate': deletedDate?.toIso8601String(),
        'fromIp': fromIp,
        'toIp': toIp,
        'name': name,
        'lastSyncDate': lastSyncDate?.toIso8601String(),
      };
}
