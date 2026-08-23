import 'package:acore/acore.dart';
import 'package:drift/drift.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';

/// Migrates entity order columns from legacy REAL values to sortable text ranks.
Future<void> migrateV35ToV36(AppDatabase db, Migrator m, Schema36 schema) async {
  final textRankStatus = <String, bool>{
    for (final table in _rankedTables) table: await _usesTextRanks(db, table),
  };
  final convertedCount = textRankStatus.values.where((converted) => converted).length;

  if (convertedCount == _rankedTables.length) return;

  if (convertedCount != 0) {
    // The four rank columns are only ever converted together inside one
    // transaction (see this function below), so a mix of TEXT and REAL
    // columns means an earlier attempt was interrupted outside that
    // transaction's protection or the schema was hand-edited. Continuing
    // would silently skip re-converting the tables that already look
    // done, potentially leaving mismatched rank formats across entities.
    final convertedTables = textRankStatus.entries.where((e) => e.value).map((e) => e.key).join(', ');
    throw StateError(
      'v35 to v36 order-column migration is in an inconsistent state: '
      '$convertedTables already use TEXT ranks but not all four ranked tables do. '
      'Refusing to proceed automatically — restore from a pre-migration backup.',
    );
  }

  Logger.info('Migrating entity orders from v35 to v36');
  try {
    final rowCounts = await _snapshotRowCounts(db);
    final habitIds = await _orderedIds(db, 'habit_table');
    final noteIds = await _orderedIds(db, 'note_table');
    final statusIds = await _orderedIds(db, 'task_status_table');
    final taskGroups = await _orderedTaskIds(db);

    await m.alterTable(TableMigration(
      schema.habitTable,
      columnTransformer: {schema.habitTable.order: const Constant('U')},
    ));
    await m.alterTable(TableMigration(
      schema.noteTable,
      columnTransformer: {schema.noteTable.order: const Constant('U')},
    ));
    await m.alterTable(TableMigration(
      schema.taskStatusTable,
      columnTransformer: {schema.taskStatusTable.order: const Constant('U')},
    ));
    await m.alterTable(TableMigration(
      schema.taskTable,
      columnTransformer: {schema.taskTable.order: const Constant('U')},
    ));

    await _assignRanks(db, 'habit_table', habitIds);
    await _assignRanks(db, 'note_table', noteIds);
    await _assignRanks(db, 'task_status_table', statusIds);
    for (final taskIds in taskGroups) {
      await _assignRanks(db, 'task_table', taskIds);
    }
    await _validateRowCounts(db, rowCounts);
    Logger.info('Migration from v35 to v36 completed');
  } catch (error, stackTrace) {
    Logger.error(
      'Failed to migrate db from v35 to v36.',
      error: error,
      stackTrace: stackTrace,
      component: 'migration_v35_to_v36',
    );
    rethrow;
  }
}

const _rankedTables = [
  'habit_table',
  'note_table',
  'task_status_table',
  'task_table',
];

const _preservedTables = [
  ..._rankedTables,
  'habit_record_table',
  'habit_tag_table',
  'habit_time_record_table',
  'task_tag_table',
  'task_time_record_table',
];

Future<Map<String, int>> _snapshotRowCounts(AppDatabase db) async => {
      for (final table in _preservedTables) table: await _rowCount(db, table),
    };

Future<void> _validateRowCounts(AppDatabase db, Map<String, int> expectedCounts) async {
  for (final entry in expectedCounts.entries) {
    final actualCount = await _rowCount(db, entry.key);
    if (actualCount != entry.value) {
      throw StateError(
        '${entry.key} row count changed from ${entry.value} to $actualCount during v35 to v36 migration',
      );
    }
  }
}

Future<int> _rowCount(AppDatabase db, String table) async {
  final row = await db.customSelect('SELECT COUNT(*) AS count FROM $table').getSingle();
  return row.read<int>('count');
}

Future<bool> _usesTextRanks(AppDatabase db, String table) async {
  final columns = await db.customSelect('PRAGMA table_info($table)').get();
  return columns.any((column) => column.data['name'] == 'order' && column.data['type'] == 'TEXT');
}

Future<List<String>> _orderedIds(AppDatabase db, String table) async {
  final rows = await db.customSelect('SELECT id FROM $table ORDER BY "order" ASC, created_date ASC, id ASC').get();
  return rows.map((row) => row.read<String>('id')).toList();
}

Future<List<List<String>>> _orderedTaskIds(AppDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT id, parent_task_id FROM task_table '
        'ORDER BY parent_task_id ASC, "order" ASC, created_date ASC, id ASC',
      )
      .get();
  final groups = <String?, List<String>>{};
  for (final row in rows) {
    final parentTaskId = row.readNullable<String>('parent_task_id');
    groups.putIfAbsent(parentTaskId, () => []).add(row.read<String>('id'));
  }
  return groups.values.toList();
}

Future<void> _assignRanks(AppDatabase db, String table, List<String> ids) async {
  final ranks = <String, String>{};
  OrderRank.assignSequential<String>(ids, setOrder: (id, rank) => ranks[id] = rank);
  await db.batch((batch) {
    for (final entry in ranks.entries) {
      batch.customStatement(
        'UPDATE $table SET "order" = ? WHERE id = ?',
        [entry.value, entry.key],
      );
    }
  });
}
