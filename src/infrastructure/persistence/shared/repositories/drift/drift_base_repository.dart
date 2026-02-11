import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:application/features/sync/models/sync_data.dart';
import 'package:application/features/sync/models/paginated_sync_data.dart';
import 'package:acore/acore.dart' as acore;
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:application/shared/services/abstraction/i_repository.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

abstract class DriftBaseRepository<TEntity extends acore.BaseEntity<TEntityId>, TEntityId extends Object,
    TTable extends Table> implements IRepository<TEntity, TEntityId> {
  @protected
  final AppDatabase database;
  @protected
  final TableInfo<TTable, TEntity> table;

  DriftBaseRepository(this.database, this.table);

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
    String? whereClause = whereClauses.isNotEmpty ? " WHERE ${whereClauses.join(' AND ')} " : null;

    String? orderByClause = customOrder?.isNotEmpty == true
        ? ' ORDER BY ${customOrder!.map((order) => '`${order.field}` IS NULL, `${order.field}` ${order.direction == acore.SortDirection.asc ? 'ASC' : 'DESC'}').join(', ')} '
        : null;

    final query = database.customSelect(
      "SELECT * FROM ${table.actualTableName}${whereClause ?? ''}${orderByClause ?? ''}LIMIT ? OFFSET ?",
      variables: [
        if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => convertToQueryVariable(e)),
        Variable.withInt(pageSize),
        Variable.withInt(pageIndex * pageSize)
      ],
      readsFrom: {table},
    ).map((row) => table.map(row.data));
    final result = await query.get();

    final count = await ((database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName}${whereClause ?? ''}',
      variables: [
        if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => convertToQueryVariable(e)),
      ],
    )).getSingleOrNull());
    final totalCount = count?.data['count'] as int? ?? 0;

    return acore.PaginatedList(
      items: await Future.wait(result.map((entity) => entity is Future<TEntity> ? entity : Future.value(entity))),
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
    String? whereClause = whereClauses.isNotEmpty ? " WHERE ${whereClauses.join(' AND ')} " : null;
    String? orderByClause = customOrder?.isNotEmpty == true
        ? ' ORDER BY ${customOrder!.map((order) => '`${order.field}` IS NULL, `${order.field}` ${order.direction == acore.SortDirection.asc ? 'ASC' : 'DESC'}').join(', ')} '
        : null;

    const int chunkSize = 1000;
    List<TEntity> allResults = [];

    // Get total counts
    final countResult = await database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName}${whereClause ?? ''}',
      variables: [
        if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => convertToQueryVariable(e)),
      ],
    ).getSingleOrNull();
    final totalCount = countResult?.data['count'] as int? ?? 0;
    final totalPages = (totalCount / chunkSize).ceil();

    // Get all data in chunks
    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final query = database.customSelect(
        "SELECT * FROM ${table.actualTableName}${whereClause ?? ''}${orderByClause ?? ''} LIMIT ? OFFSET ?",
        variables: [
          if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => convertToQueryVariable(e)),
          Variable.withInt(chunkSize),
          Variable.withInt(pageIndex * chunkSize),
        ],
        readsFrom: {table},
      ).map((row) => table.map(row.data));
      final result = await query.get();

      allResults
          .addAll(await Future.wait(result.map((entity) => entity is Future<TEntity> ? entity : Future.value(entity))));
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
      DomainLogger.warning(
          'Multiple records found for ID $id in ${table.actualTableName}, returning most recent result');
    }

    return table.map(results.first.data);
  }

  @override
  Future<TEntity?> getFirst(acore.CustomWhereFilter customWhereFilter, {bool includeDeleted = false}) async {
    List<String> whereClauses = [
      customWhereFilter.query,
      if (!includeDeleted) 'deleted_date IS NULL',
    ];
    String whereClause = whereClauses.join(' AND ');

    return database
        .customSelect(
          'SELECT * FROM ${table.actualTableName} WHERE $whereClause LIMIT 1',
          variables: customWhereFilter.variables.map((e) => convertToQueryVariable(e)).toList(),
          readsFrom: {table},
        )
        .getSingleOrNull()
        .then((value) => value != null ? table.map(value.data) : null);
  }

  @override
  Future<void> add(TEntity item) async {
    try {
      item.createdDate = DateTime.now().toUtc();
      TEntity insertedItem = await database.into(table).insertReturning(toCompanion(item));
      item.id = insertedItem.id;
      DomainLogger.debug('Successfully added ${table.actualTableName} with id ${item.id}');
    } catch (e, stackTrace) {
      DomainLogger.error('Database error adding to ${table.actualTableName}: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> update(TEntity item) async {
    try {
      item.modifiedDate = DateTime.now().toUtc();
      final companion = toCompanion(item);
      await (database.update(table)..where((t) => getPrimaryKey(t).equals(item.id))).write(companion);
    } catch (e, stackTrace) {
      DomainLogger.error('Database error updating ${table.actualTableName}: $e\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> delete(TEntity item) async {
    try {
      item.deletedDate = DateTime.now().toUtc();
      final companion = toCompanion(item);
      await (database.update(table)..where((t) => getPrimaryKey(t).equals(item.id))).write(companion);
    } catch (e, stackTrace) {
      DomainLogger.error('Database error deleting from ${table.actualTableName}: $e\n$stackTrace');
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

  /// Gets paginated sync data for efficient memory usage and network transmission
  @override
  Future<PaginatedSyncData<TEntity>> getPaginatedSyncData(
    DateTime lastSyncDate, {
    int pageIndex = 0,
    int pageSize = SyncPaginationConfig.defaultDatabasePageSize,
    String? entityType,
  }) async {
    DomainLogger.debug('Getting paginated sync data for ${table.actualTableName} - Page $pageIndex, Size $pageSize');

    // Ensure page size doesn't exceed maximum
    pageSize = pageSize > SyncPaginationConfig.maxPageSize ? SyncPaginationConfig.maxPageSize : pageSize;

    // Handle null lastSyncDate by using a very early date for initial sync
    final effectiveLastSyncDate = lastSyncDate;
    DomainLogger.debug('Using lastSyncDate: $effectiveLastSyncDate for ${table.actualTableName}');

    // Check if this is an initial sync (lastSyncDate is very old, indicating first sync)
    final isInitialSync = effectiveLastSyncDate.isBefore(DateTime(2010));
    DomainLogger.debug('Initial sync detected: $isInitialSync for ${table.actualTableName}');

    // Get counts for each operation type
    final createCount = isInitialSync
        ? await _getCountForQuery(
            'SELECT COUNT(*) as count FROM ${table.actualTableName} WHERE deleted_date IS NULL',
            [],
          )
        : await _getCountForQuery(
            'SELECT COUNT(*) as count FROM ${table.actualTableName} WHERE created_date > ? AND deleted_date IS NULL',
            [Variable.withDateTime(effectiveLastSyncDate)],
          );

    final updateCount = isInitialSync
        ? 0 // No updates for initial sync, everything is treated as create
        : await _getCountForQuery(
            'SELECT COUNT(*) as count FROM ${table.actualTableName} WHERE modified_date IS NOT NULL AND modified_date > ? AND deleted_date IS NULL',
            [Variable.withDateTime(effectiveLastSyncDate)],
          );

    final deleteCount = isInitialSync
        ? 0 // No deletes for initial sync
        : await _getCountForQuery(
            'SELECT COUNT(*) as count FROM ${table.actualTableName} WHERE deleted_date IS NOT NULL AND deleted_date > ?',
            [Variable.withDateTime(effectiveLastSyncDate)],
          );

    // Debug: Also get total record count to compare
    final totalRecordsCount = await _getCountForQuery(
      'SELECT COUNT(*) as count FROM ${table.actualTableName} WHERE deleted_date IS NULL',
      [],
    );

    final totalItems = createCount + updateCount + deleteCount;
    final totalPages = totalItems > 0 ? ((totalItems / pageSize).ceil()) : 1;
    final isLastPage = pageIndex >= totalPages - 1;

    DomainLogger.info(
        'Sync data counts for ${table.actualTableName}: Create=$createCount, Update=$updateCount, Delete=$deleteCount, Total=$totalItems (isInitialSync: $isInitialSync)');
    DomainLogger.info(
        'Total records in ${table.actualTableName}: $totalRecordsCount (active records), using sync filter date: $effectiveLastSyncDate');

    // Calculate which items to fetch for this page
    final offset = pageIndex * pageSize;
    var remainingItems = pageSize;

    List<TEntity> createSync = [];
    List<TEntity> updateSync = [];
    List<TEntity> deleteSync = [];

    // Distribute items across create, update, delete operations
    if (offset < createCount && remainingItems > 0) {
      final createOffset = offset;
      final createLimit = remainingItems > (createCount - createOffset) ? (createCount - createOffset) : remainingItems;

      createSync = isInitialSync
          ? await _getPaginatedQueryResults(
              'SELECT * FROM ${table.actualTableName} WHERE deleted_date IS NULL ORDER BY created_date ASC LIMIT ? OFFSET ?',
              [Variable.withInt(createLimit), Variable.withInt(createOffset)],
            )
          : await _getPaginatedQueryResults(
              'SELECT * FROM ${table.actualTableName} WHERE created_date > ? AND deleted_date IS NULL ORDER BY created_date ASC LIMIT ? OFFSET ?',
              [
                Variable.withDateTime(effectiveLastSyncDate),
                Variable.withInt(createLimit),
                Variable.withInt(createOffset)
              ],
            );
      remainingItems -= createSync.length;
    }

    if (offset + pageSize > createCount && remainingItems > 0) {
      final updateOffset = offset > createCount ? offset - createCount : 0;
      final updateLimit = remainingItems > (updateCount - updateOffset) ? (updateCount - updateOffset) : remainingItems;

      if (updateLimit > 0) {
        updateSync = await _getPaginatedQueryResults(
          'SELECT * FROM ${table.actualTableName} WHERE modified_date IS NOT NULL AND modified_date > ? AND deleted_date IS NULL ORDER BY modified_date ASC LIMIT ? OFFSET ?',
          [Variable.withDateTime(effectiveLastSyncDate), Variable.withInt(updateLimit), Variable.withInt(updateOffset)],
        );
        remainingItems -= updateSync.length;
      }
    }

    if (offset + pageSize > createCount + updateCount && remainingItems > 0) {
      final deleteOffset = offset > (createCount + updateCount) ? offset - (createCount + updateCount) : 0;
      final deleteLimit = remainingItems > (deleteCount - deleteOffset) ? (deleteCount - deleteOffset) : remainingItems;

      if (deleteLimit > 0) {
        deleteSync = await _getPaginatedQueryResults(
          'SELECT * FROM ${table.actualTableName} WHERE deleted_date IS NOT NULL AND deleted_date > ? ORDER BY deleted_date ASC LIMIT ? OFFSET ?',
          [Variable.withDateTime(effectiveLastSyncDate), Variable.withInt(deleteLimit), Variable.withInt(deleteOffset)],
        );
      }
    }

    final syncData = SyncData<TEntity>(
      createSync: createSync,
      updateSync: updateSync,
      deleteSync: deleteSync,
    );

    DomainLogger.debug(
        ' Page $pageIndex result: ${createSync.length} creates, ${updateSync.length} updates, ${deleteSync.length} deletes');

    return PaginatedSyncData<TEntity>(
      data: syncData,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalPages: totalPages,
      totalItems: totalItems,
      isLastPage: isLastPage,
      entityType: entityType ?? TEntity.toString(),
    );
  }

  /// Helper method to get count from a query
  Future<int> _getCountForQuery(String query, List<Variable> variables) async {
    final result = await database
        .customSelect(
          query,
          variables: variables,
        )
        .getSingleOrNull();

    return result?.data['count'] as int? ?? 0;
  }

  /// Helper method to get paginated query results
  Future<List<TEntity>> _getPaginatedQueryResults(String query, List<Variable> variables) async {
    final a = database.customSelect(
      query,
      variables: variables,
      readsFrom: {table},
    );
    final b = a.map((row) => table.map(row.data));
    final c = b.asyncMap(
      (entity) async => entity is Future<TEntity> ? await entity : entity,
    );
    final d = await c.get();

    return d;
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
