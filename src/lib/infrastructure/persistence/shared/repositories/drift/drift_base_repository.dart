import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:acore/acore.dart' as acore;
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

abstract class DriftBaseRepository<
    TEntity extends acore.BaseEntity<TEntityId>,
    TEntityId extends Object,
    TTable extends Table> implements IRepository<TEntity, TEntityId> {
  @protected
  final AppDatabase database;
  @protected
  final TableInfo<TTable, TEntity> table;

  DriftBaseRepository(this.database, this.table);

  @protected
  DateTime nextDatabaseRevision(DateTime expectedRevision) {
    final minimumNextRevision = DateTime.fromMillisecondsSinceEpoch(
      ((expectedRevision.toUtc().millisecondsSinceEpoch ~/ 1000) + 1) * 1000,
      isUtc: true,
    );
    final now = DateTime.now().toUtc();
    final currentDatabaseSecond = DateTime.fromMillisecondsSinceEpoch(
      (now.millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );
    return currentDatabaseSecond.isAfter(minimumNextRevision)
        ? currentDatabaseSecond
        : minimumNextRevision;
  }

  Insertable<TEntity> toCompanion(TEntity entity);
  Expression<TEntityId> getPrimaryKey(TTable t);

  @override
  Future<acore.PaginatedList<TEntity>> getList(int pageIndex, int pageSize,
      {bool includeDeleted = false,
      acore.CustomWhereFilter? customWhereFilter,
      List<acore.CustomOrder>? customOrder}) async {
    List<String> whereClauses = [
      if (customWhereFilter != null) "(${customWhereFilter.query})",
      if (!includeDeleted) 'deleted_date IS NULL',
    ];
    String? whereClause = whereClauses.isNotEmpty
        ? " WHERE ${whereClauses.join(' AND ')} "
        : null;

    String? orderByClause = customOrder?.isNotEmpty == true
        ? ' ORDER BY ${customOrder!.map((order) => '`${order.field}` IS NULL, `${order.field}` ${order.direction == acore.SortDirection.asc ? 'ASC' : 'DESC'}').join(', ')} '
        : null;

    final query = database.customSelect(
      "SELECT * FROM ${table.actualTableName}${whereClause ?? ''}${orderByClause ?? ''}LIMIT ? OFFSET ?",
      variables: [
        if (customWhereFilter != null)
          ...customWhereFilter.variables.map((e) => convertToQueryVariable(e)),
        Variable.withInt(pageSize),
        Variable.withInt(pageIndex * pageSize)
      ],
      readsFrom: {table},
    ).map((row) => table.map(row.data));
    final result = await query.get();

    final count = await ((database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName}${whereClause ?? ''}',
      variables: [
        if (customWhereFilter != null)
          ...customWhereFilter.variables.map((e) => convertToQueryVariable(e)),
      ],
    )).getSingleOrNull());
    final totalCount = count?.data['count'] as int? ?? 0;

    return acore.PaginatedList(
      items: await Future.wait(result.map((entity) =>
          entity is Future<TEntity> ? entity : Future.value(entity))),
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
    );
  }

  @override
  Future<List<TEntity>> getAll(
      {bool includeDeleted = false,
      acore.CustomWhereFilter? customWhereFilter,
      List<acore.CustomOrder>? customOrder}) async {
    List<String> whereClauses = [
      if (customWhereFilter != null) "(${customWhereFilter.query})",
      if (!includeDeleted) 'deleted_date IS NULL',
    ];
    String? whereClause = whereClauses.isNotEmpty
        ? " WHERE ${whereClauses.join(' AND ')} "
        : null;
    String? orderByClause = customOrder?.isNotEmpty == true
        ? ' ORDER BY ${customOrder!.map((order) => '`${order.field}` IS NULL, `${order.field}` ${order.direction == acore.SortDirection.asc ? 'ASC' : 'DESC'}').join(', ')} '
        : null;

    const int chunkSize = 1000;
    List<TEntity> allResults = [];

    // Get total counts
    final countResult = await database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName}${whereClause ?? ''}',
      variables: [
        if (customWhereFilter != null)
          ...customWhereFilter.variables.map((e) => convertToQueryVariable(e)),
      ],
    ).getSingleOrNull();
    final totalCount = countResult?.data['count'] as int? ?? 0;
    final totalPages = (totalCount / chunkSize).ceil();

    // Get all data in chunks
    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final query = database.customSelect(
        "SELECT * FROM ${table.actualTableName}${whereClause ?? ''}${orderByClause ?? ''} LIMIT ? OFFSET ?",
        variables: [
          if (customWhereFilter != null)
            ...customWhereFilter.variables
                .map((e) => convertToQueryVariable(e)),
          Variable.withInt(chunkSize),
          Variable.withInt(pageIndex * chunkSize),
        ],
        readsFrom: {table},
      ).map((row) => table.map(row.data));
      final result = await query.get();

      allResults.addAll(await Future.wait(result.map((entity) =>
          entity is Future<TEntity> ? entity : Future.value(entity))));
    }

    return allResults;
  }

  @override
  Future<TEntity?> getById(TEntityId id, {bool includeDeleted = false}) async {
    List<String> whereClauses = [
      'id = ?',
      if (!includeDeleted) 'deleted_date IS NULL',
    ];
    String whereClause = whereClauses.join(' AND ');

    final results = await database.customSelect(
      'SELECT * FROM ${table.actualTableName} WHERE $whereClause ORDER BY created_date DESC LIMIT 1',
      variables: [Variable.withString(id.toString())],
      readsFrom: {table},
    ).get();

    if (results.isEmpty) return null;

    if (results.length > 1) {
      Logger.warning(
          'Multiple records found for ID $id in ${table.actualTableName}, returning most recent result');
    }

    return table.map(results.first.data);
  }

  @override
  Future<TEntity?> getFirst(acore.CustomWhereFilter customWhereFilter,
      {bool includeDeleted = false}) async {
    List<String> whereClauses = [
      customWhereFilter.query,
      if (!includeDeleted) 'deleted_date IS NULL',
    ];
    String whereClause = whereClauses.join(' AND ');

    return database
        .customSelect(
          'SELECT * FROM ${table.actualTableName} WHERE $whereClause LIMIT 1',
          variables: customWhereFilter.variables
              .map((e) => convertToQueryVariable(e))
              .toList(),
          readsFrom: {table},
        )
        .getSingleOrNull()
        .then((value) => value != null ? table.map(value.data) : null);
  }

  @override
  Future<void> add(TEntity item) async {
    try {
      item.createdDate = DateTime.now().toUtc();
      TEntity insertedItem =
          await database.into(table).insertReturning(toCompanion(item));
      item.id = insertedItem.id;
      Logger.debug(
          'Successfully added ${table.actualTableName} with id ${item.id}');
    } catch (e, stackTrace) {
      Logger.error(
          'Database error adding to ${table.actualTableName}: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> update(TEntity item) async {
    try {
      item.modifiedDate = DateTime.now().toUtc();
      final companion = toCompanion(item);
      final stmt = (database.update(table)
        ..where((t) => getPrimaryKey(t).equals(item.id)));
      final result = await stmt.write(companion);
      Logger.debug(
          'Updated ${table.actualTableName} id=${item.id}, rows affected: $result');
    } catch (e, stackTrace) {
      Logger.error(
          'Database error updating ${table.actualTableName}: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Updates multiple entities in a single transaction.
  /// This is more efficient than calling update() multiple times.
  @override
  Future<void> updateMultiple(List<TEntity> items) async {
    if (items.isEmpty) return;

    final now = DateTime.now().toUtc();
    for (final item in items) {
      item.modifiedDate = now;
    }

    try {
      await database.transaction(() async {
        for (final item in items) {
          final companion = toCompanion(item);
          await (database.update(table)
                ..where((t) => getPrimaryKey(t).equals(item.id)))
              .write(companion);
        }
      });
      Logger.debug(
          'Batch updated ${table.actualTableName}, count: ${items.length}');
    } catch (e, stackTrace) {
      Logger.error(
          'Database error batch updating ${table.actualTableName}: $e\n$stackTrace');
      rethrow;
    }
  }

  /// D5: `INSERT ... ON CONFLICT(id) DO UPDATE SET synced columns =
  /// their excluded values, deleted_date = NULL, created_date =
  /// excluded.created_date` for deterministic-id creation sites. The UPDATE
  /// trigger then writes cells for changed columns plus a `~` revival cell.
  @override
  Future<void> upsertRevive(TEntity item) async {
    try {
      // Keep the caller's createdDate (time buckets key on it); only the
      // revival bookkeeping below changes.
      item.modifiedDate = null;
      item.deletedDate = null;
      await database.into(table).insertOnConflictUpdate(toCompanion(item));
      Logger.debug(
          'Upserted (reviving) ${table.actualTableName} id=${item.id}');
    } catch (e, stackTrace) {
      Logger.error(
          'Database error upserting ${table.actualTableName} id=${item.id}: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> delete(TEntity item) async {
    try {
      item.deletedDate = DateTime.now().toUtc();
      final companion = toCompanion(item);
      await (database.update(table)
            ..where((t) => getPrimaryKey(t).equals(item.id)))
          .write(companion);
    } catch (e, stackTrace) {
      Logger.error(
          'Database error deleting from ${table.actualTableName}: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> hardDeleteSoftDeleted(DateTime beforeDate) async {
    final dateStr = beforeDate.toIso8601String();
    await (database.customStatement(
      'DELETE FROM ${table.actualTableName} WHERE deleted_date IS NOT NULL AND deleted_date < ?',
      [dateStr],
    ));
  }

  Variable<Object> convertToQueryVariable(dynamic object) {
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

  @override
  Future<void> truncate() async {
    await database.customStatement('DELETE FROM ${table.actualTableName}');
  }
}
