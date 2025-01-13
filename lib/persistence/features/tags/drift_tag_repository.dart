import 'package:drift/drift.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(Tag)
class TagTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get name => text()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

class DriftTagRepository extends DriftBaseRepository<Tag, String, TagTable> implements ITagRepository {
  DriftTagRepository() : super(AppDatabase.instance(), AppDatabase.instance().tagTable);

  @override
  Expression<String> getPrimaryKey(TagTable t) {
    return t.id;
  }

  @override
  Insertable<Tag> toCompanion(Tag entity) {
    return TagTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      name: entity.name,
      isArchived: Value(entity.isArchived),
    );
  }
}
