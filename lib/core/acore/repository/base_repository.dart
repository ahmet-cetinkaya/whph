import '../repository/models/entity.dart';
import '../repository/models/paginated_list.dart';
import '../storage/abstraction/storage.dart';

import 'abstraction/repository.dart';

class BaseRepository<TEntity extends Entity> implements RepositoryAbstract<TEntity> {
  final StorageAbstract storage;
  final String _key;

  BaseRepository(this.storage, this._key);

  Future<List<TEntity>> _query() async {
    return storage.getValue<List<TEntity>?>(_key) ?? [];
  }

  @override
  @override
  Future<PaginatedList<TEntity>> getList(int pageIndex, int pageSize) async {
    List<TEntity> query = await _query();

    int totalItemCount = query.length;
    int totalPageCount = (totalItemCount / pageSize).ceil();
    int start = pageIndex * pageSize;
    int end = start + pageSize > totalItemCount ? totalItemCount : start + pageSize;
    List<TEntity> items = query.sublist(start, end);

    var list = PaginatedList<TEntity>(
      items: items,
      totalItemCount: totalItemCount,
      totalPageCount: totalPageCount,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
    return list;
  }

  @override
  Future<TEntity?> getById(String id) async {
    List<TEntity> query = await _query();

    TEntity? item = query.firstWhere((element) => element.id == id, orElse: () => null as TEntity);

    return item;
  }

  @override
  Future<void> add(TEntity item) async {
    List<TEntity> query = await _query();

    String id = item.id;
    if (query.any((element) => element.id == id)) {
      throw Exception('Item with id $id already exists');
    }

    query.add(item);
    await storage.setValue<List<TEntity>>(_key, query);
  }

  @override
  Future<void> update(String id, TEntity item) async {
    if (storage.getValue<TEntity>(id) == null) {
      throw Exception('Item with id $id not found');
    }

    await storage.setValue<TEntity>(id, item);
  }

  @override
  Future<void> delete(String id) async {
    await storage.removeValue(id);
  }
}
