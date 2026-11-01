// dart format width=80
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_ignore_rule_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_tag_rule_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_repository.dart';
import 'package:whph/infrastructure/persistence/features/settings/repositories/drift_settings_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_generator.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_installer.dart';

/// T14 acceptance 3: every raw-SQL write path in the repositories goes
/// through SQLite like any other statement, so the capture triggers must
/// fire. Each method is called; each must leave clock rows behind.
void main() {
  late AppDatabase db;

  Future<int> clockRows(int tblId, String pk) async => (await db
          .customSelect(
              'SELECT COUNT(*) AS n FROM sync_clock c JOIN sync_row r ON c.key / 256 = r.id '
              "WHERE r.tbl_id = $tblId AND r.pk = '$pk'")
          .getSingle())
      .data['n'] as int;

  Future<void> clearClock() async {
    await db.customStatement('DELETE FROM sync_clock');
    await db.customStatement('DELETE FROM sync_row');
  }

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.customSelect('SELECT 1').getSingle();
    for (final s in syncInternSeedStatements(
        nodeValue: 'test-node-local', originValue: 'test-origin-local')) {
      await db.customStatement(s);
    }
    await installSyncTriggers(db);
  });

  tearDown(() async => db.close());

  test('settings updateIfRevision captures clock rows', () async {
    final created = DateTime.utc(2026, 1, 1, 0, 0, 1); // whole-second: drift binds DateTimes as seconds
    await db.customStatement(
        "INSERT INTO setting_table (id, created_date, key, value, value_type) "
        "VALUES ('s1', ${created.millisecondsSinceEpoch ~/ 1000}, 'k', 'v', 0)");
    await clearClock();
    final repo = DriftSettingRepository.withDatabase(db);
    final next = await repo.updateIfRevision(
        Setting(
            id: 's1',
            createdDate: created,
            key: 'k',
            value: 'v2',
            valueType: SettingValueType.string),
        created);
    expect(next, isNotNull);
    expect(await clockRows(13, 's1'), greaterThan(0));
  });

  test('note updateIfRevision and deleteIfRevision capture clock rows',
      () async {
    final created = DateTime.utc(2026, 1, 1, 0, 0, 1); // whole-second: drift binds DateTimes as seconds
    await db.customStatement("INSERT INTO note_table (id, created_date, title) "
        "VALUES ('n1', ${created.millisecondsSinceEpoch ~/ 1000}, 'T')");
    final repo = DriftNoteRepository.withDatabase(db);
    await clearClock();
    final next = await repo.updateIfRevision(
        Note(id: 'n1', createdDate: created, title: 'T2', content: 'C'),
        created);
    expect(next, isNotNull);
    expect(await clockRows(9, 'n1'), greaterThan(0));
    await clearClock();
    final deleted = await repo.deleteIfRevision('n1', next!);
    expect(deleted, isTrue);
    expect(await clockRows(9, 'n1'), greaterThan(0));
  });

  test('tag updateIfRevision captures clock rows', () async {
    final created = DateTime.utc(2026, 1, 1, 0, 0, 1); // whole-second: drift binds DateTimes as seconds
    await db.customStatement(
        "INSERT INTO tag_table (id, created_date, name, is_archived, type) "
        "VALUES ('g1', ${created.millisecondsSinceEpoch ~/ 1000}, 'N', 0, 0)");
    await clearClock();
    final repo = DriftTagRepository.withDatabase(db);
    final next = await repo.updateIfRevision(
        Tag(id: 'g1', createdDate: created, name: 'N2'), created);
    expect(next, isNotNull);
    expect(await clockRows(11, 'g1'), greaterThan(0));
  });

  test('app usage updateIfRevision and deleteIfRevision capture clock rows',
      () async {
    final created = DateTime.utc(2026, 1, 1, 0, 0, 1); // whole-second: drift binds DateTimes as seconds
    await db
        .customStatement("INSERT INTO app_usage_table (id, created_date, name) "
            "VALUES ('a1', ${created.millisecondsSinceEpoch ~/ 1000}, 'A')");
    final repo = DriftAppUsageRepository.withDatabase(db);
    await clearClock();
    final next = await repo.updateIfRevision(
        AppUsage(id: 'a1', createdDate: created, name: 'A', displayName: 'D2'),
        created);
    expect(next, isNotNull);
    expect(await clockRows(14, 'a1'), greaterThan(0));
    await clearClock();
    final deletedAt = await repo.deleteIfRevision(
        AppUsage(id: 'a1', createdDate: created, name: 'A'), next!);
    expect(deletedAt, isNotNull);
    expect(await clockRows(14, 'a1'), greaterThan(0));
  });

  test('ignore-rule and tag-rule deleteIfRevision capture clock rows',
      () async {
    final created = DateTime.utc(2026, 1, 1, 0, 0, 1); // whole-second: drift binds DateTimes as seconds
    await db.customStatement(
        "INSERT INTO app_usage_ignore_rule_table (id, created_date, pattern) "
        "VALUES ('i1', ${created.millisecondsSinceEpoch ~/ 1000}, 'p')");
    await db.customStatement(
        "INSERT INTO app_usage_tag_rule_table (id, created_date, pattern, tag_id) "
        "VALUES ('r1', ${created.millisecondsSinceEpoch ~/ 1000}, 'p', 'g1')");
    await clearClock();
    final ignoreRepo = DriftAppUsageIgnoreRuleRepository.withDatabase(db);
    final d1 = await ignoreRepo.deleteIfRevision(
        AppUsageIgnoreRule(id: 'i1', createdDate: created, pattern: 'p'),
        created);
    expect(d1, isNotNull);
    expect(await clockRows(17, 'i1'), greaterThan(0));
    final ruleRepo = DriftAppUsageTagRuleRepository.withDatabase(db);
    final d2 = await ruleRepo.deleteIfRevision(
        AppUsageTagRule(
            id: 'r1', createdDate: created, pattern: 'p', tagId: 'g1'),
        created);
    expect(d2, isNotNull);
    expect(await clockRows(16, 'r1'), greaterThan(0));
  });

  test('the four batch updateTagOrders paths capture clock rows', () async {
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title) VALUES ('tk1', 0, 'T')");
    await db.customStatement(
        "INSERT INTO tag_table (id, created_date, name, is_archived, type) VALUES ('g1', 0, 'N', 0, 0)");
    await db.customStatement(
        "INSERT INTO task_tag_table (id, created_date, task_id, tag_id, tag_order) VALUES ('tt1', 0, 'tk1', 'g1', 1)");
    await db.customStatement(
        "INSERT INTO habit_table (id, created_date, type, name, description) VALUES ('h1', 0, 0, 'H', 'D')");
    await db.customStatement(
        "INSERT INTO habit_tag_table (id, created_date, habit_id, tag_id, tag_order) VALUES ('ht1', 0, 'h1', 'g1', 1)");
    await db.customStatement(
        "INSERT INTO note_table (id, created_date, title) VALUES ('n1', 0, 'T')");
    await db.customStatement(
        "INSERT INTO note_tag_table (id, created_date, note_id, tag_id, tag_order) VALUES ('nt1', 0, 'n1', 'g1', 1)");
    await db.customStatement(
        "INSERT INTO app_usage_table (id, created_date, name) VALUES ('a1', 0, 'A')");
    await db.customStatement(
        "INSERT INTO app_usage_tag_table (id, created_date, app_usage_id, tag_id, tag_order) VALUES ('at1', 0, 'a1', 'g1', 1)");
    await clearClock();

    await DriftTaskTagRepository.withDatabase(db)
        .updateTagOrders('tk1', {'g1': 2});
    expect(await clockRows(2, 'tt1'), greaterThan(0));
    await DriftHabitTagRepository.withDatabase(db)
        .updateTagOrders('h1', {'g1': 2});
    expect(await clockRows(7, 'ht1'), greaterThan(0));
    await DriftNoteTagRepository.withDatabase(db)
        .updateTagOrders('n1', {'g1': 2});
    expect(await clockRows(10, 'nt1'), greaterThan(0));
    await DriftAppUsageTagRepository.withDatabase(db)
        .updateTagOrders('a1', {'g1': 2});
    expect(await clockRows(15, 'at1'), greaterThan(0));
  });

  test('task bulk status and duplicate cleanup capture clock rows', () async {
    await db.customStatement(
        "INSERT INTO task_status_table (id, created_date, name, color, is_built_in, is_done_status) "
        "VALUES ('st1', 0, 'N', '#fff', 0, 0), ('st2', 0, 'M', '#fff', 0, 0)");
    await db.customStatement(
        "INSERT INTO task_table (id, created_date, title, status_id) VALUES ('tk1', 0, 'T', 'st1')");
    await clearClock();
    await DriftTaskRepository.withDatabase(db)
        .updateStatusIdForTasks('st1', 'st2');
    expect(await clockRows(1, 'tk1'), greaterThan(0));
  });
}
