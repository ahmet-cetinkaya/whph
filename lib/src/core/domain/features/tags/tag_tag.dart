import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class TagTag extends BaseEntity<String> {
  String primaryTagId;
  String secondaryTagId;

  TagTag(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      super.deletedDate,
      required this.primaryTagId,
      required this.secondaryTagId});
}
