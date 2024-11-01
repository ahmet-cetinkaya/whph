import 'package:drift/drift.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

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
    final query = database.select(table)..where((t) => t.taskId.equals(taskId) & t.taskId.equals(tagId));
    final result = await query.get();

    return result.isNotEmpty;
  }
}
