import 'package:whph/core/acore/repository/models/base_entity.dart';

class HabitRecord extends BaseEntity<String> {
  int habitId;
  DateTime date;

  HabitRecord({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    required this.habitId,
    required this.date,
  });
}
