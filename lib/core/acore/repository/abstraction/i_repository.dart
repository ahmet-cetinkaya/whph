import 'package:whph/core/acore/repository/models/base_entity.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';

import '../models/paginated_list.dart';

abstract class IRepository<T extends BaseEntity, TId> {
  Future<PaginatedList<T>> getList(int pageIndex, int pageSize,
      {bool includeDeleted = false, CustomWhereFilter? customWhereFilter, List<CustomOrder>? customOrder});
  Future<List<T>> getAll(
      {bool includeDeleted = false, CustomWhereFilter? customWhereFilter, List<CustomOrder>? customOrder});
  Future<T?> getById(TId id, {bool includeDeleted = false});
  Future<T?> getFirst(CustomWhereFilter customWhereFilter, {bool includeDeleted = false});
  Future<void> add(T item);
  Future<void> update(T item);
  Future<void> delete(T id);
}
