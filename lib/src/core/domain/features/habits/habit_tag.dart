import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

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
}
