import 'package:whph/domain/features/habits/habit_tag.dart';
import 'package:whph/application/shared/services/abstraction/i_repository.dart';

abstract class IHabitTagsRepository extends IRepository<HabitTag, String> {
  Future<bool> anyByHabitIdAndTagId(String habitId, String tagId);
}
