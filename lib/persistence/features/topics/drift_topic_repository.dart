import 'package:drift/drift.dart';
import 'package:whph/application/features/topics/services/abstraction/i_topic_repository.dart';
import 'package:whph/domain/features/topic/topic.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(Topic)
class TopicTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  IntColumn get parentId => integer().nullable().references(TopicTable, #id)();
  TextColumn get name => text()();
}

class DriftTopicRepository extends DriftBaseRepository<Topic, int, TopicTable> implements ITopicRepository {
  DriftTopicRepository() : super(AppDatabase.instance(), AppDatabase.instance().topicTable);

  @override
  Expression<int> getPrimaryKey(TopicTable t) {
    return t.id;
  }

  @override
  Insertable<Topic> toCompanion(Topic entity) {
    return TopicTableCompanion.insert(
      id: entity.id > 0 ? Value(entity.id) : const Value.absent(),
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      parentId: Value(entity.parentId),
      name: entity.name,
    );
  }
}
