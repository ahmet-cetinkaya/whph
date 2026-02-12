import 'package:drift/drift.dart';
import 'package:application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(Setting)
class SettingTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get valueType => intEnum<SettingValueType>()();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftSettingRepository extends DriftBaseRepository<Setting, String, SettingTable> implements ISettingRepository {
  DriftSettingRepository() : super(AppDatabase.instance(), AppDatabase.instance().settingTable);

  @override
  Expression<String> getPrimaryKey(SettingTable t) {
    return t.id;
  }

  @override
  Insertable<Setting> toCompanion(Setting entity) {
    return SettingTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      key: entity.key,
      value: entity.value,
      valueType: entity.valueType,
    );
  }

  @override
  Future<Setting?> getByKey(String key) async {
    final query = database.select(table)
      ..where((tbl) => tbl.key.equals(key))
      ..orderBy([(t) => OrderingTerm.desc(t.createdDate)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    return result;
  }
}
