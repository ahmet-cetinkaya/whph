import 'package:drift/drift.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';

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

class DriftSettingRepository
    extends DriftBaseRepository<Setting, String, SettingTable>
    implements ISettingRepository {
  DriftSettingRepository()
      : super(AppDatabase.instance(), AppDatabase.instance().settingTable);

  DriftSettingRepository.withDatabase(AppDatabase database)
      : super(database, database.settingTable);

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

  @override
  Future<DateTime?> updateIfRevision(
      Setting setting, DateTime expectedRevision) async {
    final nextRevision = nextDatabaseRevision(expectedRevision);
    final affectedRows = await database.customUpdate(
      '''
        UPDATE setting_table
        SET key = ?, value = ?, value_type = ?, modified_date = ?
        WHERE id = ? AND deleted_date IS NULL
          AND (modified_date = ? OR (modified_date IS NULL AND created_date = ?))
      ''',
      variables: [
        Variable<String>(setting.key),
        Variable<String>(setting.value),
        Variable<int>(setting.valueType.index),
        Variable.withDateTime(nextRevision),
        Variable<String>(setting.id),
        Variable.withDateTime(expectedRevision),
        Variable.withDateTime(expectedRevision),
      ],
      updates: {table},
    );
    return affectedRows == 1 ? nextRevision : null;
  }
}
