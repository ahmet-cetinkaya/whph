import 'package:whph/core/acore/repository/models/base_entity.dart';

import '../models/paginated_list.dart';

abstract class IRepository<T extends BaseEntity, TId> {
  Future<PaginatedList<T>> getList(int pageIndex, int pageSize, {bool includeDeleted = false});
  Future<T?> getById(TId id);
  Future<void> add(T item);
  Future<void> update(T item);
  Future<void> delete(T id);
}
