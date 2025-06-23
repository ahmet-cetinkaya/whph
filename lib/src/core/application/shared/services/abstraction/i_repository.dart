import 'package:whph/src/core/application/features/sync/models/sync_data.dart';
import 'package:acore/acore.dart' as acore;

abstract class IRepository<T extends acore.BaseEntity<TId>, TId> extends acore.IRepository<T, TId> {
  Future<SyncData<T>> getSyncData(DateTime lastSyncDate);
  Future<void> hardDeleteSoftDeleted(DateTime beforeDate);
  Future<void> truncate();
}
