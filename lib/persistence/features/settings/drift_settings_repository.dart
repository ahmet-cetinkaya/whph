import 'package:drift/drift.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(Setting)
class SettingTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get valueType => intEnum<SettingValueType>()();
}

class DriftSettingRepository extends DriftBaseRepository<Setting, int, SettingTable> implements ISettingRepository {
  DriftSettingRepository() : super(AppDatabase.instance(), AppDatabase.instance().settingTable);

  @override
  Expression<int> getPrimaryKey(SettingTable t) {
    return t.id;
  }

  @override
  Insertable<Setting> toCompanion(Setting entity) {
    return SettingTableCompanion.insert(
      id: entity.id > 0 ? Value(entity.id) : const Value.absent(),
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      key: entity.key,
      value: entity.value,
      valueType: entity.valueType,
    );
  }

  @override
  Future<Setting?> getByKey(String key) async {
    return await (database.select(table)..where((t) => t.key.equals(key))).getSingleOrNull();
  }
}
