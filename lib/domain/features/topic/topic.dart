import 'package:whph/core/acore/repository/models/base_entity.dart';

class Topic extends BaseEntity<int> {
  int? parentId;
  String name;

  Topic({required super.id, required super.createdDate, super.modifiedDate, this.parentId, required this.name});
}
