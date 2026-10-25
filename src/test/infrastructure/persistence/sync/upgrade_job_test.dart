// T17 acceptance: the production SyncUpgradeJob (dedupe -> bootstrap -> done)
// on the synthetic v37 duplicates fixture, opened through the real v37 -> v38
// migration. Oracles are independent SQL, not derived from the job.
@Timeout(Duration(minutes: 10))
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/application/shared/services/mcp_restore_barrier.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart';

import '../../../fixtures/sync/fixture_builder.dart'
    show
        buildFixture,
        defaultFixtureSeed,
        duplicatesFixture,
        fixtureDatabasePath;

/// Natural keys that must be unique after dedupe (soft-deleted rows included).
const Map<String, String> _naturalKeys = {
  'setting_table': 'key',
  'tag_tag_table': 'primary_tag_id, secondary_tag_id',
  'task_tag_table': 'task_id, tag_id',
  'habit_tag_table': 'habit_id, tag_id',
  'note_tag_table': 'note_id, tag_id',
  'app_usage_tag_table': 'app_usage_id, tag_id',
};

const Duration _chunkBudget = Duration(seconds: 2);

class _TestAppDatabase extends AppDatabase {
  _TestAppDatabase(QueryExecutor executor)
      : super.withRestoreBarrier(executor, McpRestoreBarrier());

  @override
  int get schemaVersion => 38;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory root;
  late File pristine;
  var copyCounter = 0;
  final opened = <AppDatabase>[];

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('whph_t17_upgrade_');
    AppDatabase.testDirectory = root;
    AppDatabase.isTestMode = true;
    final fixtures = Directory(p.join(root.path, 'fixtures'));
    await buildFixture(duplicatesFixture,
        seed: defaultFixtureSeed, out: fixtures);
    pristine = File(fixtureDatabasePath(fixtures, duplicatesFixture));
  });

  tearDown(() async {
    for (final db in opened) {
      await db.close();
    }
    opened.clear();
  });

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Opens a fresh copy of the v37 fixture; the v38 migration runs on open.
  Future<AppDatabase> openUpgraded() async {
    final copy =
        pristine.copySync(p.join(root.path, 'copy-${copyCounter++}.sqlite'));
    final db = _TestAppDatabase(NativeDatabase(copy));
    opened.add(db);
    await db.customSelect('SELECT 1').get();
    return db;
  }

  Future<List<Map<String, Object?>>> rows(AppDatabase db, String sql) async =>
      (await db.customSelect(sql).get()).map((row) => row.data).toList();

  Future<int> count(AppDatabase db, String sql) async =>
      (await rows(db, sql)).single.values.first as int;

  /// Checksum of user data plus clock cells (recorded_at excluded: wall clock).
  Future<String> checksum(AppDatabase db) async {
    final buffer = StringBuffer();
    final tables = await rows(db,
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'sync_%' ORDER BY name");
    for (final table in tables) {
      final name = table['name'];
      buffer.writeln('#$name');
      for (final row in await rows(db, 'SELECT * FROM "$name" ORDER BY id')) {
        buffer.writeln(row.values.join('\u0001'));
      }
    }
    buffer.writeln('#sync_clock');
    for (final row in await rows(
        db,
        'SELECT r.tbl_id, r.pk, c.key % 256 AS col, c.hlc, c.node_id, c.origin_id, c.origin_seq, c.tomb_value '
        'FROM sync_clock c JOIN sync_row r ON r.id = c.key / 256 ORDER BY r.tbl_id, r.pk, col')) {
      buffer.writeln(row.values.join('\u0001'));
    }
    return sha256.convert(buffer.toString().codeUnits).toString();
  }

  Future<int> duplicateGroups(AppDatabase db, String table, String key) => count(
      db,
      'SELECT COUNT(*) FROM (SELECT 1 FROM $table GROUP BY $key HAVING COUNT(*) > 1)');

  Future<int> taskClockHlc(AppDatabase db, String taskId) => count(
      db,
      "SELECT MAX(c.hlc) FROM sync_clock c JOIN sync_row r ON r.id = c.key / 256 "
      "WHERE r.tbl_id = ${_tblId('task_table')} AND r.pk = '$taskId'");

  test('migration leaves the job scheduled at dedupe with no cursor', () async {
    final db = await openUpgraded();
    final progress = await SyncUpgradeJob(db).getProgress();
    expect(progress.phase, SyncUpgradePhase.dedupe);
    expect(progress.cursor, isNull);
  });

  test(
      'acceptance 1+2: no natural-key duplicates, no new orphans, apply_mode restored',
      () async {
    final db = await openUpgraded();
    for (final entry in _naturalKeys.entries) {
      expect(await duplicateGroups(db, entry.key, entry.value), greaterThan(0),
          reason: '${entry.key} fixture must contain duplicates');
    }
    final orphansBefore =
        await count(db, 'SELECT COUNT(*) FROM pragma_foreign_key_check');

    expect(await SyncUpgradeJob(db).runChunks(), isTrue);

    for (final entry in _naturalKeys.entries) {
      expect(await duplicateGroups(db, entry.key, entry.value), 0,
          reason: entry.key);
    }
    expect(await count(db, 'SELECT COUNT(*) FROM pragma_foreign_key_check'),
        lessThanOrEqualTo(orphansBefore));
    expect(await count(db, 'SELECT apply_mode FROM sync_state'), 0);
    expect(
        (await SyncUpgradeJob(db).getProgress()).phase, SyncUpgradePhase.done);
  });

  test(
      'acceptance 3: bootstrap gives every row its D6 cells with gapless ascending seqs',
      () async {
    final db = await openUpgraded();
    await SyncUpgradeJob(db).runChunks();

    for (final policy in syncTablePolicies) {
      final columnCount = 1 + (policy.rowLevel ? 1 : policy.columns.length);
      final rowCount =
          await count(db, 'SELECT COUNT(*) FROM "${policy.tableName}"');
      final cells = await count(
          db,
          'SELECT COUNT(*) FROM sync_clock c JOIN sync_row r ON r.id = c.key / 256 '
          'WHERE r.tbl_id = ${policy.tblId}');
      expect(cells, rowCount * columnCount, reason: policy.tableName);
    }
    final seqs =
        await rows(db, 'SELECT origin_seq FROM sync_clock ORDER BY origin_seq');
    for (var index = 1; index < seqs.length; index++) {
      expect(seqs[index]['origin_seq'],
          (seqs[index - 1]['origin_seq'] as int) + 1);
    }
    expect(await count(db, 'SELECT next_seq FROM sync_state'),
        seqs.isEmpty ? 1 : (seqs.last['origin_seq'] as int) + 1);
  });

  test(
      'acceptance 4+5: stopping after any chunk and resuming gives the uninterrupted result',
      () async {
    final reference = await openUpgraded();
    final chunkTimings = <UpgradeChunkTiming>[];
    await SyncUpgradeJob(reference, onChunk: chunkTimings.add).runChunks();
    final expected = await checksum(reference);
    final totalChunks = chunkTimings.length;
    expect(totalChunks, greaterThan(2));

    for (final stopAfter in {1, totalChunks ~/ 2, totalChunks - 1}) {
      final db = await openUpgraded();
      expect(await SyncUpgradeJob(db).runChunks(stopAfterChunks: stopAfter),
          isFalse);
      // A new job instance models a process restart: state lives in sync_state.
      expect(await SyncUpgradeJob(db).runChunks(), isTrue);
      expect(await checksum(db), expected, reason: 'stop after $stopAfter');
    }
  });

  test('acceptance 6: each chunk stays within the 2 s budget', () async {
    final db = await openUpgraded();
    final timings = <UpgradeChunkTiming>[];
    await SyncUpgradeJob(db, onChunk: timings.add).runChunks();
    expect(timings, isNotEmpty);
    for (final timing in timings) {
      expect(timing.elapsed, lessThan(_chunkBudget), reason: timing.label);
    }
  });

  test('acceptance 8: a user edit between chunks keeps its newer trigger clock',
      () async {
    final db = await openUpgraded();
    final job = SyncUpgradeJob(db);
    var stopAfter = 1;
    while ((await job.getProgress()).phase != SyncUpgradePhase.bootstrap) {
      await job.runChunks(stopAfterChunks: stopAfter++);
    }
    final target =
        (await rows(db, 'SELECT id FROM task_table ORDER BY id DESC LIMIT 1'))
            .single['id'] as String;
    await db.customStatement(
        "UPDATE task_table SET title = 'edited between chunks' WHERE id = '$target'");
    final editedHlc = await taskClockHlc(db, target);

    expect(await SyncUpgradeJob(db).runChunks(), isTrue);

    expect(await taskClockHlc(db, target), editedHlc);
  });

  test('acceptance 9: a database with no scheduled upgrade is already done',
      () async {
    final db = await openUpgraded();
    await db.customStatement('UPDATE sync_state SET upgrade_phase = NULL');
    expect(
        (await SyncUpgradeJob(db).getProgress()).phase, SyncUpgradePhase.done);
    expect(await SyncUpgradeJob(db).runChunks(), isTrue);
  });
}

int _tblId(String tableName) => syncTablePolicies
    .firstWhere((policy) => policy.tableName == tableName)
    .tblId;
