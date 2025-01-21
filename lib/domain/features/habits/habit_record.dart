import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class HabitRecord extends BaseEntity<String> {
  String habitId;
  DateTime date;

  HabitRecord({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.habitId,
    required this.date,
  });
}
