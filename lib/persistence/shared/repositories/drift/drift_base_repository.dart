import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/persistence/shared/repositories/abstraction/i_repository.dart';

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
  Future<PaginatedList<TEntity>> getList(int pageIndex, int pageSize,
      {bool includeDeleted = false, CustomWhereFilter? customWhereFilter, List<CustomOrder>? customOrder}) async {
    List<String> whereClauses = [
      if (customWhereFilter != null) "(${customWhereFilter.query})",
      if (!includeDeleted) 'deleted_date IS NULL',
    ];
    String? whereClause = whereClauses.isNotEmpty ? " WHERE ${whereClauses.join(' AND ')} " : null;

    String? orderByClause = customOrder?.isNotEmpty == true
        ? ' ORDER BY ${customOrder!.map((order) => '${order.field} ${order.ascending ? 'ASC' : 'DESC'}').join(', ')} '
        : null;

    final query = database.customSelect(
      "SELECT * FROM ${table.actualTableName}${whereClause ?? ''}${orderByClause ?? ''}LIMIT ? OFFSET ?",
      variables: [
        if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => _convertToQueryVariable(e)),
        Variable.withInt(pageSize),
        Variable.withInt(pageIndex * pageSize)
      ],
      readsFrom: {table},
    ).map((row) => table.map(row.data));
    final result = await query.get();

    final count = await ((database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName}${whereClause ?? ''}',
      variables: [
        if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => _convertToQueryVariable(e)),
      ],
    )).getSingleOrNull());
    final totalCount = count?.data['count'] as int? ?? 0;

    return PaginatedList(
      items: await Future.wait(result.map((entity) => entity is Future<TEntity> ? entity : Future.value(entity))),
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
      totalPageCount: (totalCount / pageSize).ceil(),
    );
  }

  @override
  Future<TEntity?> getById(TEntityId id) async {
    final result = await database.customSelect(
      'SELECT * FROM ${table.actualTableName} WHERE id = ?',
      variables: [Variable.withString(id.toString())],
      readsFrom: {table},
    ).getSingleOrNull();

    return result != null ? table.map(result.data) : null;
  }

  @override
  Future<TEntity?> getFirst(CustomWhereFilter customWhereFilter) {
    return database
        .customSelect(
          'SELECT * FROM ${table.actualTableName} WHERE ${customWhereFilter.query} LIMIT 1',
          variables: customWhereFilter.variables.map((e) => _convertToQueryVariable(e)).toList(),
          readsFrom: {table},
        )
        .getSingleOrNull()
        .then((value) => value != null ? table.map(value.data) : null);
  }

  @override
  Future<void> add(TEntity item) async {
    item.createdDate = DateTime.now().toUtc();
    TEntity insertedItem = await database.into(table).insertReturning(toCompanion(item));
    item.id = insertedItem.id;
  }

  @override
  Future<void> update(TEntity item) async {
    item.modifiedDate = DateTime.now().toUtc();
    await (database.update(table)..where((t) => getPrimaryKey(t).equals(item.id))).write(toCompanion(item));
  }

  @override
  Future<void> delete(TEntity item) async {
    item.deletedDate = DateTime.now().toUtc();
    await (database.update(table)..where((t) => getPrimaryKey(t).equals(item.id))).write(toCompanion(item));
  }

  @override
  Future<SyncData<TEntity>> getSyncData(DateTime lastSyncDate) async {
    Future<List<TEntity>> queryToGetSyncData(String columnName) async {
      var a = database.customSelect(
        'SELECT * FROM ${table.actualTableName} WHERE $columnName > ?',
        variables: [Variable.withDateTime(lastSyncDate)],
        readsFrom: {table},
      );
      var b = a.map((row) => table.map(row.data));
      var c = b.asyncMap(
        (entity) async => entity is Future<TEntity> ? await entity : entity,
      );
      var d = await c.get();
      return d;
    }

    return SyncData(
      createSync: await queryToGetSyncData('created_date'),
      updateSync: await queryToGetSyncData('modified_date'),
      deleteSync: await queryToGetSyncData('deleted_date'),
    );
  }

  Variable<Object> _convertToQueryVariable(dynamic object) {
    if (object is String) {
      return Variable.withString(object);
    } else if (object is int) {
      return Variable.withInt(object);
    } else if (object is double) {
      return Variable.withReal(object);
    } else if (object is DateTime) {
      return Variable.withDateTime(object);
    } else if (object is bool) {
      return Variable.withBool(object);
    } else if (object is Uint8List) {
      return Variable.withBlob(object);
    } else if (object is bool) {
      return Variable.withBool(object);
    } else if (object is BigInt) {
      return Variable.withBigInt(object);
    } else {
      throw Exception('Unsupported variable type');
    }
  }
}
