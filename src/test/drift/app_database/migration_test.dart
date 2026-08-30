// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart' hide test, expect, setUpAll, group, tearDownAll;
import 'package:test/test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/migrations/migration_v35_to_v36.dart';
import 'generated/schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp();
    AppDatabase.testDirectory = tempDir;
    AppDatabase.isTestMode = true;
    verifier = SchemaVerifier(GeneratedHelper());
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    final versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  group('specific migration scenarios', () {
    test('migration from v29 to v30 sets default status to 0 (Complete)', () async {
      final schema29 = await verifier.schemaAt(29);
      // Use TestAppDatabase to enforce schema version 30 during this test
      final db = TestAppDatabase(schema29.newConnection(), 30);

      // Create a dummy record in v29.
      final habitId = 'habit_1';
      final recordId = 'record_1';
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert parent habit first to satisfy FK constraints if any (good practice)
      // Note: We use raw insert because the table object might be the latest version.
      await db.customStatement(
          'INSERT INTO habit_table (id, created_date, name, description, has_reminder, reminder_days, has_goal, target_frequency, period_days, "order") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [habitId, now, 'Test Habit', 'Desc', 0, '', 0, 1, 7, 0.0]);

      await db.customStatement(
          'INSERT INTO habit_record_table (id, created_date, habit_id, occurred_at) VALUES (?, ?, ?, ?)',
          [recordId, now, habitId, now]);

      // Migrate to v30
      await verifier.migrateAndValidate(db, 30);

      // Verify status
      final result = await db.customSelect('SELECT status FROM habit_record_table WHERE id = ?',
          variables: [Variable.withString(recordId)]).getSingle();

      expect(result.data['status'], 0, reason: 'Status should default to 0 (Complete)');

      await db.close();
    });

    test('v35 to v36 preserves legacy order, partitions, fields, and children', () async {
      final schema35 = await verifier.schemaAt(35);
      final db = TestAppDatabase(schema35.newConnection(), 35);
      addTearDown(db.close);
      const early = 1000;
      const late = 2000;

      await _insertHabit(db, 'habit-three', late, 3.0);
      await _insertHabit(db, 'habit-one', late, 1.0);
      await _insertHabit(db, 'habit-two', late, 2.0);
      await _insertHabit(db, 'habit-tie-b', early, 0.0);
      await _insertHabit(db, 'habit-tie-a', early, 0.0);
      await db.customStatement(
        'INSERT INTO habit_record_table '
        '(id, created_date, habit_id, occurred_at) VALUES (?, ?, ?, ?)',
        ['record-one', early, 'habit-one', early],
      );
      await db.customStatement(
        'INSERT INTO habit_record_table '
        '(id, created_date, habit_id, occurred_at) VALUES (?, ?, ?, ?)',
        ['record-two', late, 'habit-one', late],
      );
      await db.customStatement(
        'INSERT INTO habit_tag_table '
        '(id, created_date, habit_id, tag_id) VALUES (?, ?, ?, ?)',
        ['habit-tag-one', early, 'habit-one', 'tag-one'],
      );
      await db.customStatement(
        'INSERT INTO habit_time_record_table '
        '(id, created_date, habit_id, duration) VALUES (?, ?, ?, ?)',
        ['habit-time-one', early, 'habit-one', 60],
      );

      await _insertNote(db, 'note-two', late, 2.0);
      await _insertNote(db, 'note-one', early, 1.0);
      await _insertStatus(db, 'status-two', late, 2.0);
      await _insertStatus(db, 'status-one', early, 1.0);
      await _insertTask(db, id: 'parent', createdDate: early, order: 0.0);
      await _insertTask(db, id: 'root-two', createdDate: late, order: 2.0);
      await _insertTask(db, id: 'root-one', createdDate: late, order: 1.0);
      await _insertTask(db, id: 'child-two', createdDate: late, order: 2.0, parentTaskId: 'parent');
      await _insertTask(
        db,
        id: 'parent-two',
        createdDate: late,
        order: 3.0,
      );
      await _insertTask(
        db,
        id: 'second-child',
        createdDate: early,
        order: 0.0,
        parentTaskId: 'parent-two',
      );
      await _insertTask(
        db,
        id: 'child-one',
        createdDate: early,
        order: 1.0,
        parentTaskId: 'parent',
        statusId: 'status-one',
        plannedReminderTime: 2,
        deadlineReminderTime: 3,
        plannedOffset: 15,
        deadlineOffset: 30,
      );
      await db.customStatement(
        'INSERT INTO task_tag_table '
        '(id, created_date, task_id, tag_id) VALUES (?, ?, ?, ?)',
        ['task-tag-one', early, 'child-one', 'tag-one'],
      );
      await db.customStatement(
        'INSERT INTO task_time_record_table '
        '(id, created_date, task_id, duration) VALUES (?, ?, ?, ?)',
        ['task-time-one', early, 'child-one', 60],
      );

      final legacyOrders = await _legacyOrders(db);
      final legacyCounts = await _tableCounts(db);

      await _migrateV35ToV36(db);

      expect(await _columnType(db, 'habit_table', 'order'), 'TEXT');
      expect(await _columnType(db, 'note_table', 'order'), 'TEXT');
      expect(await _columnType(db, 'task_status_table', 'order'), 'TEXT');
      expect(await _columnType(db, 'task_table', 'order'), 'TEXT');

      expect(
        await _orderedIds(db, 'habit_table'),
        legacyOrders['habit_table'],
      );
      expect(await _orderedIds(db, 'note_table'), legacyOrders['note_table']);
      expect(
        await _orderedIds(db, 'task_status_table'),
        legacyOrders['task_status_table'],
      );
      expect(await _orderedTaskIds(db, null), legacyOrders['root_tasks']);
      expect(
        await _orderedTaskIds(db, 'parent'),
        legacyOrders['parent_tasks'],
      );
      expect(
        await _orderedTaskIds(db, 'parent-two'),
        legacyOrders['parent_two_tasks'],
      );
      expect(await _tableCounts(db), legacyCounts);
      await _expectCanonicalDistinctRanks(db, 'habit_table');
      await _expectCanonicalDistinctRanks(db, 'note_table');
      await _expectCanonicalDistinctRanks(db, 'task_status_table');
      await _expectCanonicalDistinctRanks(db, 'task_table');

      final child = await db.customSelect(
        'SELECT status_id, planned_date_reminder_time, deadline_date_reminder_time, '
        'planned_date_reminder_custom_offset, deadline_date_reminder_custom_offset '
        'FROM task_table WHERE id = ?',
        variables: [Variable.withString('child-one')],
      ).getSingle();
      expect(child.data, containsPair('status_id', 'status-one'));
      expect(child.data, containsPair('planned_date_reminder_time', 2));
      expect(child.data, containsPair('deadline_date_reminder_time', 3));
      expect(child.data, containsPair('planned_date_reminder_custom_offset', 15));
      expect(child.data, containsPair('deadline_date_reminder_custom_offset', 30));
      expect(await _count(db, 'habit_record_table'), 2);
      expect(await _count(db, 'habit_tag_table'), 1);
      expect(await _count(db, 'habit_time_record_table'), 1);
      expect(await _count(db, 'task_tag_table'), 1);
      expect(await _count(db, 'task_time_record_table'), 1);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    });

    test('v35 to v36 migration is a no-op when ranks are already text', () async {
      final schema35 = await verifier.schemaAt(35);
      final db = TestAppDatabase(schema35.newConnection(), 35);
      addTearDown(db.close);
      await _insertHabit(db, 'habit-two', 2000, 2.0);
      await _insertHabit(db, 'habit-one', 1000, 1.0);
      await _migrateV35ToV36(db);
      final before = await _rankMap(db, 'habit_table');

      await migrateV35ToV36(db, Migrator(db), Schema36(database: db));

      expect(await _rankMap(db, 'habit_table'), before);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    });

    test('v35 to v36 refuses to proceed when the four ranked tables disagree on column type', () async {
      // Simulates an interrupted or hand-edited database where habit_table
      // was converted to TEXT ranks but task_table was not — the idempotence
      // guard must not treat "habit_table is TEXT" as "everything is done"
      // and silently skip converting the rest.
      final schema35 = await verifier.schemaAt(35);
      final db = TestAppDatabase(schema35.newConnection(), 35);
      addTearDown(db.close);
      await _insertHabit(db, 'habit-one', 1000, 1.0);
      await _insertTask(db, id: 'task-one', createdDate: 1000, order: 1.0);

      await _migrateV35ToV36(db);
      expect(await _columnType(db, 'habit_table', 'order'), 'TEXT');
      expect(await _columnType(db, 'task_table', 'order'), 'TEXT');

      // Force task_table's order column back to REAL to simulate the
      // inconsistent state, bypassing the app's own migration path.
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customStatement('ALTER TABLE task_table RENAME COLUMN "order" TO "order_text"');
      await db.customStatement('ALTER TABLE task_table ADD COLUMN "order" REAL NOT NULL DEFAULT 0');
      await db.customStatement('ALTER TABLE task_table DROP COLUMN "order_text"');
      await db.customStatement('PRAGMA foreign_keys = ON');
      expect(await _columnType(db, 'task_table', 'order'), anyOf('REAL', 'NUM', 'NUMERIC'));

      Object? caught;
      try {
        await migrateV35ToV36(db, Migrator(db), Schema36(database: db));
      } catch (error) {
        caught = error;
      }
      expect(caught, isA<StateError>());
    });

    test('v35 to v36 rolls back entirely when the surrounding transaction fails', () async {
      // Mirrors the production pattern in drift_app_context.dart's onUpgrade:
      // migration steps and post-migration validation run inside one
      // db.transaction(). This proves that pattern actually protects the
      // user — if anything after the migration steps fails within that same
      // transaction, the schema and data revert to their pre-migration
      // state rather than being left half-converted.
      final schema35 = await verifier.schemaAt(35);
      final db = TestAppDatabase(schema35.newConnection(), 35);
      addTearDown(db.close);

      await _insertHabit(db, 'habit-three', 3000, 3.0);
      await _insertHabit(db, 'habit-one', 1000, 1.0);
      await _insertHabit(db, 'habit-two', 2000, 2.0);
      await _insertTask(db, id: 'root-a', createdDate: 1000, order: 1.0);
      await _insertTask(db, id: 'root-b', createdDate: 2000, order: 2.0);

      final ordersBefore = await _rankMap(db, 'habit_table');
      final taskOrdersBefore = await _rankMap(db, 'task_table');

      await db.customStatement('PRAGMA foreign_keys = OFF');
      Object? caught;
      try {
        await db.transaction(() async {
          await migrateV35ToV36(db, Migrator(db), Schema36(database: db));
          // Simulate a failure occurring after the migration's own steps
          // but still inside the same enclosing transaction, exactly as a
          // later _validateDataIntegrity() failure would in production.
          throw StateError('forced failure to prove rollback');
        });
      } catch (error) {
        caught = error;
      } finally {
        await db.customStatement('PRAGMA foreign_keys = ON');
      }

      expect(caught, isA<StateError>(), reason: 'the forced failure must propagate out of the transaction');

      // The schema must have reverted: the order column is REAL again, not
      // the TEXT type the migration would have left behind.
      expect(await _columnType(db, 'habit_table', 'order'), anyOf('REAL', 'NUM', 'NUMERIC'));
      expect(await _columnType(db, 'task_table', 'order'), anyOf('REAL', 'NUM', 'NUMERIC'));

      // The original numeric orders must be intact — not overwritten with
      // canonical rank strings, and not left as some partially-converted mix.
      expect(await _rankMap(db, 'habit_table'), ordersBefore);
      expect(await _rankMap(db, 'task_table'), taskOrdersBefore);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);

      // The database must remain usable: a subsequent clean migration must
      // still succeed after the failed attempt, proving no lingering
      // half-applied state blocks retry.
      await _migrateV35ToV36(db);
      expect(await _columnType(db, 'habit_table', 'order'), 'TEXT');
      await _expectCanonicalDistinctRanks(db, 'habit_table');
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    });

    test('v35 to v36 survives real-world scale and hostile legacy order values', () async {
      final schema35 = await verifier.schemaAt(35);
      final db = TestAppDatabase(schema35.newConnection(), 35);
      addTearDown(db.close);

      // A heavy user: more habits and tasks than any fixture so far, which
      // forces multi-digit rank widths rather than the single digit a handful
      // of rows would need.
      const habitCount = 500;
      for (var index = 0; index < habitCount; index++) {
        await _insertHabit(db, 'habit-${index.toString().padLeft(4, '0')}', 1000 + index, index.toDouble());
      }

      // Order values that real databases actually accumulate through sync,
      // legacy migrations and repeated midpoint insertion.
      const hostileOrders = <String, double>{
        'task-negative': -5000.0,
        'task-negative-small': -0.5,
        'task-zero': 0.0,
        'task-zero-twin': 0.0,
        'task-tiny': 0.000000001,
        'task-huge': 1e12,
        'task-max': double.maxFinite,
        'task-collapsed-a': 1.0000001,
        'task-collapsed-b': 1.0000002,
      };
      var createdDate = 5000;
      for (final entry in hostileOrders.entries) {
        await _insertTask(db, id: entry.key, createdDate: createdDate++, order: entry.value);
      }

      // A single large subtask partition: the ordered-task grouping path
      // that previously rebuilt its accumulator list on every row is only
      // exercised when one parent scope holds many rows, not by many
      // single-row partitions.
      const subtaskCount = 500;
      await _insertTask(db, id: 'parent-with-many-children', createdDate: 4000, order: 0.5);
      for (var index = 0; index < subtaskCount; index++) {
        await _insertTask(
          db,
          id: 'child-${index.toString().padLeft(4, '0')}',
          createdDate: 6000 + index,
          order: index.toDouble(),
          parentTaskId: 'parent-with-many-children',
        );
      }

      final legacyHabits = await _legacyOrderedIds(db, 'habit_table');
      final legacyRootTasks = await _legacyOrderedTaskIds(db, null);
      final legacyChildren = await _legacyOrderedTaskIds(db, 'parent-with-many-children');
      final legacyCounts = await _tableCounts(db);

      await _migrateV35ToV36(db);

      // The user's sequence must survive verbatim, at scale and through
      // negative, zero, denormal and overflow-prone legacy values.
      expect(await _orderedIds(db, 'habit_table'), legacyHabits);
      expect(await _orderedTaskIds(db, null), legacyRootTasks);
      expect(await _orderedTaskIds(db, 'parent-with-many-children'), legacyChildren);
      expect(await _tableCounts(db), legacyCounts);
      await _expectCanonicalDistinctRanks(db, 'habit_table');
      await _expectCanonicalDistinctRanksPerTaskParent(db);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);

      // Ranks must stay short enough that later drag-and-drop can still insert
      // between any two neighbours instead of hitting the length cap.
      final habitRanks = (await _rankMap(db, 'habit_table')).values;
      expect(habitRanks.every((rank) => rank.length <= 4), isTrue,
          reason: 'sequential ranks should stay compact at 500 rows');
    });
  });
}

Future<void> _insertHabit(AppDatabase db, String id, int createdDate, double order) => db.customStatement(
      'INSERT INTO habit_table '
      '(id, created_date, name, description, has_reminder, reminder_days, has_goal, '
      'target_frequency, period_days, "order") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, createdDate, id, '', 0, '', 0, 1, 7, order],
    );

Future<void> _insertNote(AppDatabase db, String id, int createdDate, double order) => db.customStatement(
      'INSERT INTO note_table (id, title, created_date, "order") VALUES (?, ?, ?, ?)',
      [id, id, createdDate, order],
    );

Future<void> _insertStatus(AppDatabase db, String id, int createdDate, double order) => db.customStatement(
      'INSERT INTO task_status_table (id, created_date, name, "order") VALUES (?, ?, ?, ?)',
      [id, createdDate, id, order],
    );

Future<void> _insertTask(
  AppDatabase db, {
  required String id,
  required int createdDate,
  required double order,
  String? parentTaskId,
  String? statusId,
  int plannedReminderTime = 0,
  int deadlineReminderTime = 0,
  int? plannedOffset,
  int? deadlineOffset,
}) =>
    db.customStatement(
      'INSERT INTO task_table '
      '(id, parent_task_id, title, status_id, created_date, "order", '
      'planned_date_reminder_time, deadline_date_reminder_time, '
      'planned_date_reminder_custom_offset, deadline_date_reminder_custom_offset) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        parentTaskId,
        id,
        statusId,
        createdDate,
        order,
        plannedReminderTime,
        deadlineReminderTime,
        plannedOffset,
        deadlineOffset,
      ],
    );

Future<List<String>> _orderedIds(AppDatabase db, String table) async {
  final rows = await db.customSelect('SELECT id FROM $table ORDER BY "order" ASC').get();
  return rows.map((row) => row.read<String>('id')).toList();
}

Future<List<String>> _orderedTaskIds(AppDatabase db, String? parentTaskId) async {
  final predicate = parentTaskId == null ? 'parent_task_id IS NULL' : 'parent_task_id = ?';
  final variables = parentTaskId == null ? const <Variable>[] : [Variable.withString(parentTaskId)];
  final rows = await db
      .customSelect(
        'SELECT id FROM task_table WHERE $predicate ORDER BY "order" ASC',
        variables: variables,
      )
      .get();
  return rows.map((row) => row.read<String>('id')).toList();
}

Future<void> _expectCanonicalDistinctRanks(AppDatabase db, String table) async {
  final rows = await db.customSelect('SELECT "order" FROM $table ORDER BY "order" ASC').get();
  final ranks = rows.map((row) => row.read<String>('order')).toList();
  expect(ranks.toSet(), hasLength(ranks.length));
  expect(ranks, everyElement(matches(RegExp(r'^[0-9A-Za-z]*[1-9A-Za-z]$'))));
}

/// Like [_expectCanonicalDistinctRanks], but scoped per parent partition:
/// task_table ranks are only guaranteed distinct among true siblings, so two
/// tasks under different parents may legitimately share a rank.
Future<void> _expectCanonicalDistinctRanksPerTaskParent(AppDatabase db) async {
  final rows =
      await db.customSelect('SELECT parent_task_id, "order" FROM task_table ORDER BY parent_task_id ASC').get();
  final ranksByParent = <String?, List<String>>{};
  for (final row in rows) {
    ranksByParent.putIfAbsent(row.readNullable<String>('parent_task_id'), () => []).add(row.read<String>('order'));
  }
  for (final ranks in ranksByParent.values) {
    expect(ranks.toSet(), hasLength(ranks.length));
    expect(ranks, everyElement(matches(RegExp(r'^[0-9A-Za-z]*[1-9A-Za-z]$'))));
  }
}

Future<int> _count(AppDatabase db, String table) async {
  final row = await db.customSelect('SELECT COUNT(*) AS count FROM $table').getSingle();
  return row.read<int>('count');
}

Future<Map<String, String>> _rankMap(AppDatabase db, String table) async {
  final rows = await db.customSelect('SELECT id, "order" FROM $table').get();
  return {for (final row in rows) row.read<String>('id'): row.read<String>('order')};
}

Future<void> _migrateV35ToV36(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  try {
    await db.transaction(() => migrateV35ToV36(db, Migrator(db), Schema36(database: db)));
  } finally {
    await db.customStatement('PRAGMA foreign_keys = ON');
  }
}

Future<String?> _columnType(AppDatabase db, String table, String column) async {
  final columns = await db.customSelect('PRAGMA table_info($table)').get();
  return columns.where((row) => row.read<String>('name') == column).map((row) => row.read<String>('type')).firstOrNull;
}

Future<Map<String, List<String>>> _legacyOrders(AppDatabase db) async => {
      'habit_table': await _legacyOrderedIds(db, 'habit_table'),
      'note_table': await _legacyOrderedIds(db, 'note_table'),
      'task_status_table': await _legacyOrderedIds(db, 'task_status_table'),
      'root_tasks': await _legacyOrderedTaskIds(db, null),
      'parent_tasks': await _legacyOrderedTaskIds(db, 'parent'),
      'parent_two_tasks': await _legacyOrderedTaskIds(db, 'parent-two'),
    };

Future<List<String>> _legacyOrderedIds(AppDatabase db, String table) async {
  final rows = await db.customSelect('SELECT id FROM $table ORDER BY "order" ASC, created_date ASC, id ASC').get();
  return rows.map((row) => row.read<String>('id')).toList();
}

Future<List<String>> _legacyOrderedTaskIds(AppDatabase db, String? parentTaskId) async {
  final predicate = parentTaskId == null ? 'parent_task_id IS NULL' : 'parent_task_id = ?';
  final variables = parentTaskId == null ? const <Variable>[] : [Variable.withString(parentTaskId)];
  final rows = await db
      .customSelect(
        'SELECT id FROM task_table WHERE $predicate '
        'ORDER BY "order" ASC, created_date ASC, id ASC',
        variables: variables,
      )
      .get();
  return rows.map((row) => row.read<String>('id')).toList();
}

Future<Map<String, int>> _tableCounts(AppDatabase db) async => {
      for (final table in _preservedTables) table: await _count(db, table),
    };

const _preservedTables = [
  'habit_table',
  'note_table',
  'task_status_table',
  'task_table',
  'habit_record_table',
  'habit_tag_table',
  'habit_time_record_table',
  'task_tag_table',
  'task_time_record_table',
];

class TestAppDatabase extends AppDatabase {
  int targetVersion;

  TestAppDatabase(super.e, this.targetVersion);

  @override
  int get schemaVersion => targetVersion;
}
