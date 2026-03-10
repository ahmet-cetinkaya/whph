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
}
