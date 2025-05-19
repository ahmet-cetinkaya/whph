import 'package:drift/drift.dart';
import 'package:whph/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/application/features/tags/models/tag_time_category.dart';
import 'package:whph/domain/features/habits/habit_tag.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/application/features/tags/models/tag_time_data.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';

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
  Future<bool> anyByHabitIdAndTagId(String habitId, String tagId) async {
    final query = database.select(table)
      ..where((t) => t.habitId.equals(habitId) & t.tagId.equals(tagId) & t.deletedDate.isNull());
    final result = await query.get();

    return result.isNotEmpty;
  }

  @override
  Future<PaginatedList<HabitTag>> getListByHabitId(String habitId, int pageIndex, int pageSize) async {
    final query = database.select(table)
      ..where((t) => t.habitId.equals(habitId) & t.deletedDate.isNull())
      ..limit(pageSize, offset: pageIndex * pageSize);
    final result = await query.get();

    final count = await ((database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName} WHERE habit_id = ? AND deleted_date IS NULL',
      variables: [Variable.withString(habitId)],
    )).getSingleOrNull());
    final totalCount = count?.data['count'] as int? ?? 0;

    return PaginatedList(
      items: result,
      totalItemCount: totalCount,
      totalPageCount: (totalCount / pageSize).ceil(),
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<TagTimeData>> getTopTagsByDuration(
    DateTime startDate,
    DateTime endDate, {
    int? limit,
    List<String>? filterByTags,
    bool filterByIsArchived = false,
  }) async {
    final query = database.customSelect(
      '''
      WITH duration_calc AS (
        SELECT
          t.id as tag_id,
          t.name as tag_name,
          t.color as tag_color,
          COALESCE((
            SELECT SUM(h.estimated_time * 60 * (
              SELECT COUNT(*)
              FROM habit_record_table hr
              WHERE hr.habit_id = h.id
              AND hr.date BETWEEN ? AND ?
              AND hr.deleted_date IS NULL
            ))
            FROM habit_tag_table ht
            JOIN habit_table h ON h.id = ht.habit_id
            WHERE ht.tag_id = t.id
            AND ht.deleted_date IS NULL
            AND h.deleted_date IS NULL
            AND h.estimated_time IS NOT NULL
          ), 0) as total_duration
        FROM tag_table t
        WHERE t.deleted_date IS NULL
        ${filterByTags != null && filterByTags.isNotEmpty ? 'AND t.id IN (${filterByTags.map((_) => '?').join(',')})' : ''}
        ${filterByIsArchived ? 'AND t.is_archived = 1' : 'AND (t.is_archived = 0 OR t.is_archived IS NULL)'}
      )
      SELECT *
      FROM duration_calc
      WHERE total_duration > 0
      ORDER BY total_duration DESC
      ${limit != null ? 'LIMIT ?' : ''}
      ''',
      variables: [
        Variable<DateTime>(startDate),
        Variable<DateTime>(endDate),
        if (filterByTags != null && filterByTags.isNotEmpty) ...filterByTags.map((id) => Variable<String>(id)),
        if (limit != null) Variable<int>(limit),
      ],
      readsFrom: {
        database.tagTable,
        database.habitTagTable,
        database.habitTable,
        database.habitRecordTable,
      },
    );

    final results = await query.get();
    return results
        .map((row) => TagTimeData(
              tagId: row.read<String>('tag_id'),
              tagName: row.read<String>('tag_name'),
              duration: row.read<int>('total_duration'),
              category: TagTimeCategory.habits,
              tagColor: row.read<String?>('tag_color'),
            ))
        .toList();
  }
}
