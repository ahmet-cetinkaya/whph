import 'package:application/features/sync/models/paginated_sync_data.dart';
import 'package:acore/acore.dart' as acore;

abstract class IRepository<T extends acore.BaseEntity<TId>, TId> extends acore.IRepository<T, TId> {
  Future<PaginatedSyncData<T>> getPaginatedSyncData(
    DateTime lastSyncDate, {
    int pageIndex = 0,
    int pageSize = 200,
    String? entityType,
  });
  Future<void> hardDeleteSoftDeleted(DateTime beforeDate);
  Future<void> truncate();
}
