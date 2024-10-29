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

  void mapFromInstance(SyncDevice instance) {
    fromIp = instance.fromIp;
    toIp = instance.toIp;
    name = instance.name;
    lastSyncDate = instance.lastSyncDate;
  }
}
