import 'package:drift/drift.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/src/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/src/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';

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
}
