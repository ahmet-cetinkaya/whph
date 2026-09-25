import 'package:drift/drift.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(SyncDevice)
class SyncDeviceTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get fromIp => text()();
  TextColumn get toIp => text()();
  TextColumn get fromDeviceId => text()();
  TextColumn get toDeviceId => text()();
  TextColumn get name => text().nullable()();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftSyncDeviceRepository extends DriftBaseRepository<SyncDevice, String, SyncDeviceTable>
    implements ISyncDeviceRepository {
  DriftSyncDeviceRepository() : super(AppDatabase.instance(), AppDatabase.instance().syncDeviceTable);

  DriftSyncDeviceRepository.withDatabase(AppDatabase database) : super(database, database.syncDeviceTable);

  @override
  Expression<String> getPrimaryKey(SyncDeviceTable t) {
    return t.id;
  }

  @override
  Insertable<SyncDevice> toCompanion(SyncDevice entity) {
    return SyncDeviceTableCompanion.insert(
      id: entity.id,
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      fromIp: entity.fromIp,
      toIp: entity.toIp,
      fromDeviceId: entity.fromDeviceId,
      toDeviceId: entity.toDeviceId,
      lastSyncDate: Value(entity.lastSyncDate),
      name: Value(entity.name),
    );
  }

  @override
  Future<SyncDevice?> getByFromToIp(String fromIp, String toIp) async {
    return await (database.select(table)
          ..where((t) =>
              (t.fromIp.equals(fromIp) & t.toIp.equals(toIp) | t.fromIp.equals(toIp) & t.toIp.equals(fromIp)) &
              t.deletedDate.isNull()))
        .getSingleOrNull();
  }

  @override
  Future<DateTime?> updateIfRevision(SyncDevice device, DateTime expectedRevision) async {
    final nextRevision = nextDatabaseRevision(expectedRevision);
    final affectedRows = await database.customUpdate(
      '''
        UPDATE sync_device_table
        SET from_ip = ?, to_ip = ?, from_device_id = ?, to_device_id = ?,
            name = ?, last_sync_date = ?, modified_date = ?, deleted_date = NULL
        WHERE id = ? AND deleted_date IS NULL
          AND (modified_date = ? OR (modified_date IS NULL AND created_date = ?))
      ''',
      variables: [
        Variable<String>(device.fromIp),
        Variable<String>(device.toIp),
        Variable<String>(device.fromDeviceId),
        Variable<String>(device.toDeviceId),
        Variable<String>(device.name),
        Variable<DateTime>(device.lastSyncDate),
        Variable.withDateTime(nextRevision),
        Variable<String>(device.id),
        Variable.withDateTime(expectedRevision),
        Variable.withDateTime(expectedRevision),
      ],
      updates: {table},
    );
    return affectedRows == 1 ? nextRevision : null;
  }

  @override
  Future<DateTime?> deleteIfRevision(String id, DateTime expectedRevision) async {
    final deletedAt = nextDatabaseRevision(expectedRevision);
    final affectedRows = await database.customUpdate(
      '''
        UPDATE sync_device_table
        SET deleted_date = ?
        WHERE id = ? AND deleted_date IS NULL
          AND (modified_date = ? OR (modified_date IS NULL AND created_date = ?))
      ''',
      variables: [
        Variable.withDateTime(deletedAt),
        Variable<String>(id),
        Variable.withDateTime(expectedRevision),
        Variable.withDateTime(expectedRevision),
      ],
      updates: {table},
    );
    return affectedRows == 1 ? deletedAt : null;
  }
}
