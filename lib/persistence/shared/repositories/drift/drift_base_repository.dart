import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:whph/core/acore/repository/abstraction/i_repository.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';

abstract class DriftBaseRepository<TEntity extends BaseEntity, TEntityId extends Object, TTable extends Table>
    implements IRepository<TEntity, TEntityId> {
  @protected
  final AppDatabase database;
  @protected
  final TableInfo<TTable, TEntity> table;

  DriftBaseRepository(this.database, this.table);

  Insertable<TEntity> toCompanion(TEntity entity);
  Expression<TEntityId> getPrimaryKey(TTable t);

  @override
  Future<PaginatedList<TEntity>> getList(int pageIndex, int pageSize) async {
    final query = database.select(table)..limit(pageSize, offset: pageIndex * pageSize);
    final result = await query.get();

    final count = await ((database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName}',
    )).getSingleOrNull());
    final totalCount = count?.data['count'] as int? ?? 0;

    return PaginatedList(
      items: result,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
      totalPageCount: (totalCount / pageSize).ceil(),
    );
  }

  @override
  Future<TEntity?> getById(TEntityId id) async {
    return await (database.select(table)..where((t) => getPrimaryKey(t).equals(id))).getSingleOrNull();
  }

  @override
  Future<void> add(TEntity item) async {
    item.createdDate = DateTime.now().toUtc();
    await database.into(table).insert(toCompanion(item));
  }

  @override
  Future<void> update(TEntity item) async {
    item.modifiedDate = DateTime.now().toUtc();
    await (database.update(table)..where((t) => getPrimaryKey(t).equals(item.id))).write(toCompanion(item));
  }

  @override
  Future<void> delete(TEntityId id) async {
    await (database.delete(table)..where((t) => getPrimaryKey(t).equals(id))).go();
  }
}
