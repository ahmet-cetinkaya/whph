import 'package:drift/drift.dart';
import 'package:whph/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/core/application/features/tags/models/tag_time_data.dart';

@UseRowClass(TaskTag)
class TaskTagTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get taskId => text()();
  TextColumn get tagId => text()();
}

class DriftTaskTagRepository extends DriftBaseRepository<TaskTag, String, TaskTagTable> implements ITaskTagRepository {
  DriftTaskTagRepository() : super(AppDatabase.instance(), AppDatabase.instance().taskTagTable);

  // Constructor for testing with custom database
  DriftTaskTagRepository.withDatabase(AppDatabase db) : super(db, db.taskTagTable);

  @override
  Expression<String> getPrimaryKey(TaskTagTable t) {
    return t.id;
  }

  @override
  Insertable<TaskTag> toCompanion(TaskTag entity) {
    return TaskTagTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      taskId: entity.taskId,
      tagId: entity.tagId,
    );
  }

  @override
  Future<bool> anyByTaskIdAndTagId(String taskId, String tagId) async {
    final query = database.select(table)
      ..where((t) => t.taskId.equals(taskId) & t.tagId.equals(tagId) & t.deletedDate.isNull());
    final result = await query.get();

    return result.isNotEmpty;
  }

  @override
  Future<List<TaskTag>> getByTaskId(String taskId) async {
    return (database.select(table)..where((t) => t.taskId.equals(taskId) & t.deletedDate.isNull())).get();
  }

  @override
  Future<List<TaskTag>> getByTagId(String tagId) async {
    return (database.select(table)..where((t) => t.tagId.equals(tagId) & t.deletedDate.isNull())).get();
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
            SELECT SUM(tr.duration)
            FROM task_tag_table tt
            JOIN task_time_record_table tr ON tr.task_id = tt.task_id
            WHERE tt.tag_id = t.id
            AND tt.deleted_date IS NULL
            AND tr.created_date BETWEEN ? AND ?
            AND tr.deleted_date IS NULL
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
        database.taskTagTable,
        database.taskTimeRecordTable,
      },
    );

    final results = await query.get();
    return results
        .map((row) => TagTimeData(
              tagId: row.read<String>('tag_id'),
              tagName: row.read<String>('tag_name'),
              duration: row.read<int>('total_duration'),
              category: TagTimeCategory.tasks,
              tagColor: row.read<String?>('tag_color'),
            ))
        .toList();
  }
}
