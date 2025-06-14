import 'package:whph/src/core/application/features/sync/models/sync_data.dart';
import 'package:whph/corePackages/acore/repository/abstraction/i_repository.dart' as core;
import 'package:whph/corePackages/acore/repository/models/base_entity.dart';

abstract class IRepository<T extends BaseEntity<TId>, TId> extends core.IRepository<T, TId> {
  Future<SyncData<T>> getSyncData(DateTime lastSyncDate);
  Future<void> hardDeleteSoftDeleted(DateTime beforeDate);
  Future<void> truncate();
}
