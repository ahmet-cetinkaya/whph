// dart format width=80
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/core/application/shared/utils/sync_identity.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_tag_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

/// T15 acceptance 2: untag → retag leaves one live link row with the
/// deterministic id and a `~` revival cell newer than the tombstone.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.customSelect('SELECT 1').getSingle();
  });

  tearDown(() async => db.close());

  Future<void> seedItem(String table, String cols, String values) =>
      db.customStatement('INSERT INTO $table ($cols) VALUES ($values)');

  test('untag then retag a task tag revives one row with the deterministic id',
      () async {
    await seedItem('task_table', 'id, created_date, title', "'t1', 0, 'T'");
    await seedItem('tag_table', 'id, created_date, name, is_archived, type',
        "'g1', 0, 'N', 0, 0");
    final repo = DriftTaskTagRepository.withDatabase(db);
    final add = AddTaskTagCommandHandler(taskTagRepository: repo);
    final id = syncIdentityId(identityKindTaskTag, ['t1', 'g1']);

    await add(AddTaskTagCommand(taskId: 't1', tagId: 'g1'));
    await db.customStatement(
        "UPDATE task_tag_table SET deleted_date = 500 WHERE id = '$id'");
    final tombHlc = await db
        .customSelect(
            'SELECT c.hlc AS hlc FROM sync_clock c JOIN sync_row r ON c.key / 256 = r.id '
            "WHERE r.tbl_id = 2 AND r.pk = '$id' AND c.key % 256 = 0")
        .getSingle();

    await add(AddTaskTagCommand(taskId: 't1', tagId: 'g1'));

    final rows = await db
        .customSelect(
            "SELECT id, deleted_date FROM task_tag_table WHERE task_id = 't1' AND tag_id = 'g1'")
        .get();
    expect(rows.length, 1);
    expect(rows.first.data['deleted_date'], isNull);
    final revival = await db
        .customSelect(
            'SELECT c.hlc AS hlc FROM sync_clock c JOIN sync_row r ON c.key / 256 = r.id '
            "WHERE r.tbl_id = 2 AND r.pk = '$id' AND c.key % 256 = 0")
        .getSingle();
    expect(revival.data['hlc'] as int, greaterThan(tombHlc.data['hlc'] as int));
  });

  test('two offline devices derive the same link id (collision)', () {
    final a = syncIdentityId(identityKindTaskTag, ['t1', 'g1']);
    final b = syncIdentityId(identityKindTaskTag, ['t1', 'g1']);
    expect(a, b);
  });
}
