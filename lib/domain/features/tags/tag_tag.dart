import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class TagTag extends BaseEntity<String> {
  String primaryTagId;
  String secondaryTagId;

  TagTag(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      required this.primaryTagId,
      required this.secondaryTagId});

  void mapFromInstance(TagTag instance) {
    primaryTagId = instance.primaryTagId;
    secondaryTagId = instance.secondaryTagId;
  }
}
