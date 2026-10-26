import 'package:flutter_test/flutter_test.dart';

import 'drift_sync_test_support.dart';

/// FR-006: an edit of an already deleted row must not out-rank its tombstone
/// on any peer, while a real revive (deleted_date back to NULL) must.
class _Family {
  final String name;
  final String table;
  final String insert;
  final String edit;
  const _Family(this.name, this.table, this.insert, this.edit);
}

const _families = [
  _Family(
      'tag link',
      'task_tag_table',
      "INSERT INTO task_tag_table (id, created_date, task_id, tag_id) VALUES ('x', 1, 't', 'g')",
      "UPDATE task_tag_table SET tag_order = 7 WHERE id = 'x'"),
  _Family(
      'time record',
      'task_time_record_table',
      "INSERT INTO task_time_record_table (id, created_date, task_id, duration) VALUES ('x', 1, 't', 300)",
      "UPDATE task_time_record_table SET duration = 999 WHERE id = 'x'"),
  _Family(
      'habit record',
      'habit_record_table',
      "INSERT INTO habit_record_table (id, created_date, habit_id, occurred_at) VALUES ('x', 1, 'h', 1)",
      "UPDATE habit_record_table SET occurred_at = 5 WHERE id = 'x'"),
  _Family(
      'rule',
      'app_usage_tag_rule_table',
      "INSERT INTO app_usage_tag_rule_table (id, created_date, pattern, tag_id) VALUES ('x', 1, 'p', 'g')",
      "UPDATE app_usage_tag_rule_table SET pattern = 'q' WHERE id = 'x'"),
  _Family(
      'field-level note',
      'note_table',
      "INSERT INTO note_table (id, created_date, title, content) VALUES ('x', 1, 'a', 'b')",
      "UPDATE note_table SET title = 'edited' WHERE id = 'x'"),
];

void main() {
  late SyncTestDevice a;
  late SyncTestDevice b;

  setUp(() async {
    a = await SyncTestDevice.open('a');
    b = await SyncTestDevice.open('b');
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<Object?> deletedDate(SyncTestDevice device, _Family family) async =>
      (await device.rows("SELECT deleted_date FROM ${family.table} WHERE id = 'x'"))
          .single['deleted_date'];

  for (final family in _families) {
    group(family.name, () {
      test('an edit of the deleted row on the deleting device stays deleted',
          () async {
        await a.sql(family.insert);
        await pullChanges(a, b);
        await a.sql("UPDATE ${family.table} SET deleted_date = 100 WHERE id = 'x'");
        await a.sql(family.edit);

        await syncAllDevices([a, b]);

        expect(await deletedDate(a, family), isNotNull);
        expect(await deletedDate(b, family), isNotNull);
      });

      test('an edit of the deleted row on a peer that saw the delete stays deleted',
          () async {
        await a.sql(family.insert);
        await a.sql("UPDATE ${family.table} SET deleted_date = 100 WHERE id = 'x'");
        await pullChanges(a, b);
        await b.forceHlcAhead();
        await b.sql(family.edit);

        await syncAllDevices([a, b]);

        expect(await deletedDate(a, family), isNotNull);
        expect(await deletedDate(b, family), isNotNull);
      });

      test('a real revive still revives on both devices', () async {
        await a.sql(family.insert);
        await a.sql("UPDATE ${family.table} SET deleted_date = 100 WHERE id = 'x'");
        await pullChanges(a, b);
        await b.forceHlcAhead();
        await b.sql("UPDATE ${family.table} SET deleted_date = NULL WHERE id = 'x'");

        await syncAllDevices([a, b]);

        expect(await deletedDate(a, family), isNull);
        expect(await deletedDate(b, family), isNull);
      });
    });
  }
}
