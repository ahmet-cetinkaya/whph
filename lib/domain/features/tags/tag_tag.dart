import 'package:whph/core/acore/repository/models/base_entity.dart';

class TagTag extends BaseEntity<int> {
  int primaryTagId;
  int secondaryTagId;

  TagTag(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      required this.primaryTagId,
      required this.secondaryTagId});
}
