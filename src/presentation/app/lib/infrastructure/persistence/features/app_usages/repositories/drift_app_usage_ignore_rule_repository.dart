import 'package:drift/drift.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(AppUsageIgnoreRule)
class AppUsageIgnoreRuleTable extends Table {
  TextColumn get id => text()();
  TextColumn get pattern => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftAppUsageIgnoreRuleRepository extends DriftBaseRepository<AppUsageIgnoreRule, String, AppUsageIgnoreRuleTable>
    implements IAppUsageIgnoreRuleRepository {
  DriftAppUsageIgnoreRuleRepository() : super(AppDatabase.instance(), AppDatabase.instance().appUsageIgnoreRuleTable);

  @override
  Expression<String> getPrimaryKey(AppUsageIgnoreRuleTable t) {
    return t.id;
  }

  @override
  Insertable<AppUsageIgnoreRule> toCompanion(AppUsageIgnoreRule entity) {
    return AppUsageIgnoreRuleTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      pattern: entity.pattern,
      description: Value(entity.description),
    );
  }
}
