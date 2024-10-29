import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class HabitTag extends BaseEntity<String> {
  String habitId;
  String tagId;

  HabitTag({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.habitId,
    required this.tagId,
  });

  void mapFromInstance(HabitTag instance) {
    habitId = instance.habitId;
    tagId = instance.tagId;
  }
}
