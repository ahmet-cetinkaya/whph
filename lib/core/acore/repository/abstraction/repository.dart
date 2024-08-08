import '../../repository/models/paginated_list.dart';

abstract class RepositoryAbstract<T> {
  Future<PaginatedList<T>> getList(int pageIndex, int pageSize);
  Future<T?> getById(String id);
  Future<void> add(T item);
  Future<void> update(String id, T item);
  Future<void> delete(String id);
}
