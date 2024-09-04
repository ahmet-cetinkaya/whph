import 'package:whph/core/acore/repository/models/base_entity.dart';

class Tag extends BaseEntity<int> {
  String name;

  Tag({required super.id, required super.createdDate, super.modifiedDate, required this.name});
}
