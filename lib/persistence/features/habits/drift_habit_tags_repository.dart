import 'package:drift/drift.dart';
import 'package:whph/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/domain/features/habits/habit_tag.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(HabitTag)
class HabitTagTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get habitId => text()();
  TextColumn get tagId => text()();
}

class DriftHabitTagRepository extends DriftBaseRepository<HabitTag, String, HabitTagTable>
    implements IHabitTagsRepository {
  DriftHabitTagRepository() : super(AppDatabase.instance(), AppDatabase.instance().habitTagTable);

  @override
  Expression<String> getPrimaryKey(HabitTagTable t) {
    return t.id;
  }

  @override
  Insertable<HabitTag> toCompanion(HabitTag entity) {
    return HabitTagTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      habitId: entity.habitId,
      tagId: entity.tagId,
    );
  }

  @override
  Future<bool> anyByHabitIdAndTagId(String habitId, String tagId) {
    final query = database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE habit_id = ? AND tag_id = ? AND deleted_date IS NULL',
      variables: [Variable.withString(habitId), Variable.withString(tagId)],
    );
    return query.map((row) => row.read<int>('count')).getSingle().then((value) => value > 0);
  }
}
