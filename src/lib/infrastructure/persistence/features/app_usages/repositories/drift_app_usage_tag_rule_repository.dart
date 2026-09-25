import 'package:drift/drift.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(AppUsageTagRule)
class AppUsageTagRuleTable extends Table {
  TextColumn get id => text()();
  TextColumn get pattern => text()();
  TextColumn get tagId => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftAppUsageTagRuleRepository extends DriftBaseRepository<AppUsageTagRule, String, AppUsageTagRuleTable>
    implements IAppUsageTagRuleRepository {
  DriftAppUsageTagRuleRepository() : super(AppDatabase.instance(), AppDatabase.instance().appUsageTagRuleTable);

  DriftAppUsageTagRuleRepository.withDatabase(AppDatabase database) : super(database, database.appUsageTagRuleTable);

  @override
  Expression<String> getPrimaryKey(AppUsageTagRuleTable t) {
    return t.id;
  }

  @override
  Insertable<AppUsageTagRule> toCompanion(AppUsageTagRule entity) {
    return AppUsageTagRuleTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      pattern: entity.pattern,
      tagId: entity.tagId,
      description: Value(entity.description),
    );
  }

  @override
  Future<DateTime?> deleteIfRevision(AppUsageTagRule rule, DateTime expectedRevision) async {
    final deletedAt = nextDatabaseRevision(expectedRevision);
    final affectedRows = await database.customUpdate(
      '''
        UPDATE app_usage_tag_rule_table
        SET deleted_date = ?, modified_date = ?
        WHERE id = ? AND deleted_date IS NULL
          AND (modified_date = ? OR (modified_date IS NULL AND created_date = ?))
      ''',
      variables: [
        Variable.withDateTime(deletedAt),
        Variable.withDateTime(deletedAt),
        Variable<String>(rule.id),
        Variable.withDateTime(expectedRevision),
        Variable.withDateTime(expectedRevision),
      ],
      updates: {table},
    );
    return affectedRows == 1 ? deletedAt : null;
  }
}
