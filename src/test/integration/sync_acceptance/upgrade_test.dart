// T27 part 2, SC-010 (FR-060, FR-061): the synthetic schema-v37 fixtures are
// upgraded through the real v37 -> v38 migration and the real upgrade job
// (dedupe, then bootstrap). No item and no field is lost, except the rows the
// documented dedupe merges; `large_usage` (3+ years of app usage) keeps all of
// its rows; every legacy pairing is marked and listed as needing re-pairing.
@Tags(['t27-slow'])
@Timeout(Duration(minutes: 40))
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/queries/get_list_sync_members_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/application/shared/services/mcp_restore_barrier.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_device_repository.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_status_store.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import '../../drift/app_database/generated/schema_v37.dart';
import '../../fixtures/sync/fixture_builder.dart';
import 'support2/lab.dart';

const int _migratedSchemaVersion = 38;
const int _legacyPairings = 3;
const int _minimumUsageRecords = 150000;
const int _minimumYears = 3;
const int _secondsPerYear = 365 * 24 * 60 * 60;
const String _usageTable = 'app_usage_time_record_table';
const String _deviceTable = 'sync_device_table';
const String _fieldSeparator = '\u0001';

class _MigratingAppDatabase extends AppDatabase {
  _MigratingAppDatabase(QueryExecutor executor) : super.withRestoreBarrier(executor, McpRestoreBarrier());

  @override
  int get schemaVersion => _migratedSchemaVersion;
}

/// Tables whose rows the dedupe re-keys to the deterministic id of their
/// identity (D5, FR-033), so their ids are not stable across the upgrade.
const Set<String> _rekeyedTables = {
  'setting_table',
  'task_status_table',
  _deviceTable,
  'task_table',
  'habit_record_table',
  'task_tag_table',
  'habit_tag_table',
  'note_tag_table',
  'app_usage_tag_table',
  'tag_tag_table',
};

/// Re-keyed tables compared field by field without the id (no column of them
/// refers to a re-keyed id); `task_table` and `task_tag_table` are compared by
/// count because recurring occurrences and their links move to new ids.
const Set<String> _contentComparedTables = {
  'setting_table',
  'task_status_table',
  _deviceTable,
  'habit_record_table',
  'habit_tag_table',
  'note_tag_table',
  'app_usage_tag_table',
  'tag_tag_table',
};

/// Columns the dedupe rewrites when it re-keys the row they refer to (`fkRewriteList`).
const Map<String, Set<String>> _rewrittenColumns = {
  'task_time_record_table': {'task_id'},
};

/// One table: the joined field values by id.
class _Table {
  final Map<String, String> rows = {};
  List<String> columns = const [];

  /// The field values without the id, sorted: a multiset of the row contents.
  List<String> get contents {
    final idPosition = columns.indexOf('id');
    final all = [
      for (final row in rows.values) (row.split(_fieldSeparator)..removeAt(idPosition)).join(_fieldSeparator),
    ];
    return all..sort();
  }
}

typedef _Snapshot = Map<String, _Table>;

Future<_Snapshot> _readSnapshot(GeneratedDatabase db, {_Snapshot? columnsOf}) async {
  final snapshot = <String, _Table>{};
  for (final name in fixtureTables) {
    final table = _Table();
    table.columns = columnsOf?[name]!.columns ??
        [
          for (final row in await db.customSelect("SELECT name FROM pragma_table_info('$name') ORDER BY cid").get())
            if (!(_rewrittenColumns[name]?.contains(row.data['name']) ?? false)) row.data['name']! as String
        ];
    final select = table.columns.map((column) => '"$column"').join(', ');
    for (final row in await db.customSelect('SELECT $select FROM "$name"').get()) {
      table.rows['${row.data['id']}'] = table.columns.map((column) => '${row.data[column]}').join(_fieldSeparator);
    }
    snapshot[name] = table;
  }
  return snapshot;
}

String _digest(Map<String, String> rows) {
  final ids = rows.keys.toList()..sort();
  final hash = sha256.convert(utf8.encode(ids.map((id) => '$id|${rows[id]}').join('\n')));
  return hash.toString();
}

/// How many rows the dedupe removes per table: one survivor stays per duplicate group.
Map<String, int> _mergedRowsPerTable(File manifest) {
  final removed = <String, int>{};
  final json = jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
  for (final group in (json['duplicateGroups']! as List).cast<Map>()) {
    final table = group['table']! as String;
    removed[table] = (removed[table] ?? 0) + (group['ids']! as List).length - 1;
  }
  return removed;
}

/// Inserts [_legacyPairings] old-protocol pairings into the v37 file, so FR-061 has something to mark.
Future<void> _addLegacyPairings(File v37File) async {
  final db = DatabaseAtV37(NativeDatabase(v37File));
  try {
    for (var index = 0; index < _legacyPairings; index++) {
      await db.customStatement(
        'INSERT INTO $_deviceTable (id, created_date, from_ip, to_ip, from_device_id, to_device_id, name, last_sync_date) '
        "VALUES ('legacy-$index', 1700000000, '10.0.0.1', '10.0.0.${index + 2}', 'local-device', 'old-peer-$index', 'Old peer $index', 1700000500)",
      );
    }
  } finally {
    await db.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory root;
  late Directory fixtures;
  final opened = <AppDatabase>[];

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('whph_t27b_upgrade_');
    AppDatabase.testDirectory = root;
    AppDatabase.isTestMode = true;
    fixtures = Directory(p.join(root.path, 'fixtures'));
  });

  tearDownAll(() async {
    for (final db in opened) {
      await db.close();
    }
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Builds [name], adds the legacy pairings, records the v37 state, upgrades a
  /// copy and returns everything the checks need.
  Future<({_Snapshot before, _Snapshot after, AppDatabase db, Map<String, int> merged})> upgrade(String name) async {
    await buildFixture(name, seed: defaultFixtureSeed, out: fixtures);
    final pristine = File(fixtureDatabasePath(fixtures, name));
    await _addLegacyPairings(pristine);
    final manifest = File(fixtureManifestPath(fixtures, name));
    final merged = manifest.existsSync() ? _mergedRowsPerTable(manifest) : <String, int>{};

    final v37 = DatabaseAtV37(NativeDatabase(pristine));
    final before = await _readSnapshot(v37);
    await v37.close();

    final copy = pristine.copySync(p.join(root.path, 'upgrade-$name.sqlite'));
    final db = _MigratingAppDatabase(NativeDatabase(copy));
    opened.add(db);
    await db.customSelect('SELECT 1').get();
    expect(await SyncUpgradeJob(db).runChunks(), isTrue);
    expect((await SyncUpgradeJob(db).getProgress()).phase, SyncUpgradePhase.done);
    final after = await _readSnapshot(db, columnsOf: before);
    return (before: before, after: after, db: db, merged: merged);
  }

  /// FR-060: every row and field is kept, except the rows the dedupe merges into
  /// one survivor per identity (the documented FR-032 merge).
  void expectNothingLost(_Snapshot before, _Snapshot after, Map<String, int> merged) {
    for (final name in fixtureTables) {
      final was = before[name]!;
      final now = after[name]!;
      if (!_rekeyedTables.contains(name)) {
        expect(now.rows.keys.toSet(), was.rows.keys.toSet(), reason: '$name: same rows');
        final changed = was.rows.keys.where((id) => now.rows[id] != was.rows[id]);
        expect(changed, isEmpty, reason: '$name: fields changed');
        continue;
      }
      final expected = was.rows.length - (merged[name] ?? 0);
      if (merged.containsKey(name)) {
        // Moving the links of merged items onto their survivor can make further links exact duplicates (FR-031).
        expect(now.rows.length, lessThanOrEqualTo(expected), reason: '$name: only merged duplicates disappear');
        expect(now.rows.length, greaterThan(0), reason: '$name: the survivors stay');
        continue;
      }
      expect(now.rows.length, expected, reason: '$name: every row is kept');
      if (_contentComparedTables.contains(name)) {
        expect(now.contents, was.contents, reason: '$name: every field of every row is kept');
      }
    }
  }

  for (final name in [largeUsageFixture, emptyFixture, duplicatesFixture]) {
    group('SC-010 fixture $name', () {
      late ({_Snapshot before, _Snapshot after, AppDatabase db, Map<String, int> merged}) result;

      setUpAll(() async => result = await upgrade(name));

      test('SC-010 $name: 100% of items and fields are kept (FR-060)', () {
        expectNothingLost(result.before, result.after, result.merged);
        for (final table in fixtureTables) {
          if (_rekeyedTables.contains(table)) continue;
          expect(_digest(result.after[table]!.rows), _digest(result.before[table]!.rows), reason: '$table checksum');
        }
      });

      if (name == largeUsageFixture) {
        test('SC-010 $name: the fixture holds 3+ years of app usage and all of it survives', () async {
          final upgraded = await result.db
              .customSelect('SELECT COUNT(*) AS n, MIN(usage_date) AS first, MAX(usage_date) AS last FROM $_usageTable')
              .getSingle();
          expect(upgraded.data['n'], greaterThanOrEqualTo(_minimumUsageRecords));
          expect(upgraded.data['n'], result.before[_usageTable]!.rows.length);
          final span = (upgraded.data['last'] as int) - (upgraded.data['first'] as int);
          expect(span, greaterThanOrEqualTo(_minimumYears * _secondsPerYear));
        });
      }

      test('SC-010 $name: every legacy pairing needs re-pairing and none is synced (FR-061)', () async {
        final marked =
            await result.db.customSelect('SELECT COUNT(*) AS n FROM $_deviceTable WHERE needs_repair = 1').getSingle();
        final all = await result.db.customSelect('SELECT COUNT(*) AS n FROM $_deviceTable').getSingle();
        expect(all.data['n'], greaterThanOrEqualTo(_legacyPairings));
        expect(marked.data['n'], all.data['n'], reason: 'every existing pairing is marked');

        final lab = await Lab.create();
        addTearDown(lab.close);
        final device = await lab.add('Upgraded');
        final reader = SyncMemberSummaryReader(
          membershipService: device.security.service,
          statusStore: DriftSyncPeerStatusStore(result.db),
          legacyDeviceRepository: DriftSyncDeviceRepository.withDatabase(result.db),
          itemsCannotBeApplied: (_) => false,
        );
        final summaries = await reader.readAll();
        expect(summaries, hasLength(all.data['n'] as int));
        for (final summary in summaries) {
          expect(summary.isLegacy, isTrue);
          expect(summary.lastResult, SyncResultCategory.needsRepairing);
        }
        final run = await lab.engineSyncAll(device);
        expect(run.peers, isEmpty, reason: 'no legacy pairing is a sync peer until it is paired again');
      });
    });
  }
}
