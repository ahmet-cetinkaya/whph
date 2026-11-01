// dart format width=80
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_cascade_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_generator.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_installer.dart';

/// T14 acceptance 6 and 7: cascading deletes stamp child tombstones with the
/// root cause; the D5b trigger materializes the effective state when the
/// parent's `deleted_date` flips, writing 0 clock rows.
void main() {
  late AppDatabase db;
  late DriftSyncCascadeService cascade;

  Future<int> clockCount() async => (await db
          .customSelect('SELECT COUNT(*) AS n FROM sync_clock')
          .getSingle())
      .data['n'] as int;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.customSelect('SELECT 1').getSingle();
    for (final s
        in syncInternSeedStatements(nodeValue: 'n', originValue: 'o')) {
      await db.customStatement(s);
    }
    await installSyncTriggers(db);
    cascade = DriftSyncCascadeService(db);
  });

  tearDown(() async => db.close());

  Future<Map<String, Object?>> state(String table, String id) async =>
      (await db.customSelect(
              'SELECT deleted_date, modified_date FROM $table WHERE id = ?',
              variables: [Variable.withString(id)]).getSingle())
          .data;

  test('cause-scoped child delete stamps the parent as cause', () async {
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title) VALUES ('p1', 0, 'P')");
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title, parent_task_id) "
        "VALUES ('c1', 0, 'C', 'p1')");
    await db.customStatement(
        "INSERT INTO task_tag_table (id, created_date, task_id, tag_id) "
        "VALUES ('tt1', 0, 'p1', 'g1')");

    await cascade.withCause('task_table', 'p1', () async {
      await db.customStatement(
          "UPDATE task_table SET deleted_date = 5 WHERE id = 'c1'");
      await db.customStatement(
          "UPDATE task_tag_table SET deleted_date = 5 WHERE id = 'tt1'");
    });
    final st = await db
        .customSelect(
            "SELECT cascade_cause_tbl_id AS t, cascade_cause_pk AS p FROM sync_state WHERE id = 'singleton'")
        .getSingle();
    expect(st.data['t'], isNull);
    expect(st.data['p'], isNull);

    final causes = await db
        .customSelect(
            'SELECT r.tbl_id AS tbl, r.pk AS pk, c.cause_row_id AS cause '
            'FROM sync_clock c JOIN sync_row r ON c.key / 256 = r.id '
            'WHERE c.key % 256 = 0 AND c.cause_row_id IS NOT NULL')
        .get();
    expect(causes.length, 2, reason: 'child task + join row stamped');
    final parentRowId = (await db
            .customSelect(
                "SELECT id FROM sync_row WHERE tbl_id = 1 AND pk = 'p1'")
            .get())
        .map((r) => r.data['id']);
    for (final c in causes) {
      expect(parentRowId, contains(c.data['cause']));
    }
  });

  test('D5b: reviving a root revives subtasks whose cause is a deleted child',
      () async {
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title) VALUES ('root', 0, 'R')");
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title, parent_task_id) "
        "VALUES ('mid', 0, 'M', 'root')");
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title, parent_task_id) "
        "VALUES ('leaf', 0, 'L', 'mid')");
    await cascade.withCause('task_table', 'mid', () async {
      await db.customStatement(
          "UPDATE task_table SET deleted_date = 100 WHERE id = 'leaf'");
      await db.customStatement(
          "UPDATE task_table SET deleted_date = 100 WHERE id = 'mid'");
    });
    await cascade.withCause('task_table', 'root', () async {
      await db.customStatement(
          "UPDATE task_table SET deleted_date = 200 WHERE id = 'mid'");
      await db.customStatement(
          "UPDATE task_table SET deleted_date = 200 WHERE id = 'root'");
    });

    await db.customStatement(
        "UPDATE task_table SET deleted_date = NULL WHERE id = 'root'");

    expect((await state('task_table', 'mid'))['deleted_date'], isNull);
    expect((await state('task_table', 'leaf'))['deleted_date'], isNull);
  });

  test('D5b: reviving the parent revives cause-linked subtasks, 0 clock rows',
      () async {
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title) VALUES ('p1', 0, 'P')");
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title, parent_task_id, modified_date, deleted_date) "
        "VALUES ('c1', 0, 'C', 'p1', 100, 200)");

    await cascade.withCause('task_table', 'p1', () async {
      await db.customStatement(
          "UPDATE task_table SET deleted_date = 200 WHERE id = 'c1'");
      await db.customStatement(
          "UPDATE task_table SET deleted_date = 300 WHERE id = 'p1'");
    });
    await db.customStatement('DELETE FROM sync_clock');
    await db.customStatement('DELETE FROM sync_row');
    // Re-insert just the parent's row id so the cause check can resolve it.
    await db
        .customStatement("INSERT INTO sync_row (tbl_id, pk) VALUES (1, 'p1')");
    final parentId = (await db
            .customSelect(
                "SELECT id FROM sync_row WHERE tbl_id = 1 AND pk = 'p1'")
            .getSingle())
        .data['id'];
    await db.customStatement(
        'INSERT INTO sync_row (tbl_id, pk) VALUES (1, \'c1\')');
    final childId = (await db
            .customSelect(
                "SELECT id FROM sync_row WHERE tbl_id = 1 AND pk = 'c1'")
            .getSingle())
        .data['id'];
    await db.customStatement(
        'INSERT INTO sync_clock (key, hlc, node_id, origin_id, origin_seq, tomb_value, cause_row_id, recorded_at) '
        'VALUES ($childId * 256 + 0, 1, 1, 1, 1, 200, $parentId, 0)');

    // Revive via raw statement.
    await db.customStatement(
        "UPDATE task_table SET deleted_date = NULL WHERE id = 'p1'");
    var child = await state('task_table', 'c1');
    expect(child['deleted_date'], isNull);
    expect(child['modified_date'] as int, greaterThan(100));

    // Re-delete restores the tombstone value.
    await db.customStatement(
        "UPDATE task_table SET deleted_date = 400 WHERE id = 'p1'");
    child = await state('task_table', 'c1');
    expect(child['deleted_date'], 200);

    // The parent's own two flips captured 2 ~ cells; the child still has
    // exactly its one seeded tombstone cell - materialization added none.
    final childClockRows = await db.customSelect(
        'SELECT COUNT(*) AS n FROM sync_clock c JOIN sync_row r ON c.key / 256 = r.id '
        "WHERE r.pk = 'c1'").getSingle();
    expect(childClockRows.data['n'], 1);
    expect(await clockCount(), 2);
    final mode = await db.customSelect(
        "SELECT apply_mode AS m FROM sync_state WHERE id = 'singleton'")
        .getSingle();
    expect(mode.data['m'], 0);
  });

  test('D5b: re-deleting the parent keeps a subtask revived by a later edit',
      () async {
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title) VALUES ('p1', 0, 'P')");
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title, parent_task_id, modified_date) "
        "VALUES ('c1', 0, 'C', 'p1', 100)");
    await db.customStatement('DELETE FROM sync_clock');
    final parentId = (await db
            .customSelect("SELECT id FROM sync_row WHERE pk = 'p1'")
            .getSingle())
        .data['id'];
    final childId = (await db
            .customSelect("SELECT id FROM sync_row WHERE pk = 'c1'")
            .getSingle())
        .data['id'];
    // The child's cascade tombstone (hlc 1) is older than its title edit (hlc 2).
    await db.customStatement(
        'INSERT INTO sync_clock (key, hlc, node_id, origin_id, origin_seq, tomb_value, cause_row_id, recorded_at) '
        'VALUES ($childId * 256 + 0, 1, 1, 1, 1, 200, $parentId, 0)');
    await db.customStatement(
        'INSERT INTO sync_clock (key, hlc, node_id, origin_id, origin_seq, recorded_at) '
        'VALUES ($childId * 256 + 3, 2, 1, 1, 2, 0)');

    await db.customStatement(
        "UPDATE task_table SET deleted_date = 400 WHERE id = 'p1'");

    expect((await state('task_table', 'c1'))['deleted_date'], isNull);
  });
}
