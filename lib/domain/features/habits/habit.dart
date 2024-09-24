import 'package:whph/core/acore/repository/models/base_entity.dart';

class Habit extends BaseEntity<int> {
  String name;
  String description;

  Habit({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    required this.name,
    required this.description,
  });
}
