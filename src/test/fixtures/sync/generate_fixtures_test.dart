@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import 'fixture_builder.dart';

void main() {
  const seed = defaultFixtureSeed;
  late Directory root;
  late Directory runA;
  late Directory runB;
  final results = <String, FixtureResult>{};
  final hashesA = <String, String>{};
  final hashesB = <String, String>{};

  String sha(File file) => sha256.convert(file.readAsBytesSync()).toString();

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('whph_sync_fixtures_');
    runA = Directory(p.join(root.path, 'a'));
    runB = Directory(p.join(root.path, 'b'));
    for (final name in fixtureNames) {
      final a = await buildFixture(name, seed: seed, out: runA);
      final b = await buildFixture(name, seed: seed, out: runB);
      results[name] = a;
      hashesA[name] = sha(a.database);
      hashesB[name] = sha(b.database);
      // ignore: avoid_print
      print('fixture $name: ${a.totalRows} rows, generated in ${a.elapsed.inMilliseconds} ms '
          '(second run ${b.elapsed.inMilliseconds} ms), sha256 ${hashesA[name]}');
    }
  });

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Opens a copy of [fixture] so the generated file stays untouched.
  File copyOf(String name) {
    final copyDir = Directory(p.join(root.path, 'copies'))..createSync(recursive: true);
    return results[name]!
        .database
        .copySync(p.join(copyDir.path, '$name-${DateTime.now().microsecondsSinceEpoch}.sqlite'));
  }

  Future<List<Map<String, Object?>>> query(GeneratedDatabase db, String sql) async =>
      (await db.customSelect(sql).get()).map((r) => r.data).toList();

  Future<int> scalar(GeneratedDatabase db, String sql) async =>
      (await db.customSelect(sql).getSingle()).data.values.first as int;

  /// Header field `user_version` (big-endian int at offset 60).
  int headerUserVersion(File file) {
    final bytes = file.openSync()..setPositionSync(60);
    final b = bytes.readSync(4);
    bytes.closeSync();
    return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
  }

  group('determinism', () {
    for (final name in fixtureNames) {
      test('$name: same seed yields byte-identical files', () {
        expect(hashesA[name], hashesB[name]);
        final manifestA = results[name]!.manifest;
        if (manifestA != null) {
          expect(sha(manifestA), sha(File(fixtureManifestPath(runB, name))));
        }
      });
    }

    test('a different seed changes the content', () async {
      final other = Directory(p.join(root.path, 'other'));
      final result = await buildFixture(duplicatesFixture, seed: seed + 1, out: other);
      expect(sha(result.database), isNot(hashesA[duplicatesFixture]));
    });
  });

  group('schema and integrity', () {
    for (final name in fixtureNames) {
      test('$name: opens with AppDatabase at schema 37 and passes integrity_check', () async {
        expect(headerUserVersion(results[name]!.database), fixtureSchemaVersion);

        final db = AppDatabase.withExecutor(NativeDatabase(copyOf(name)));
        try {
          expect(db.schemaVersion, fixtureSchemaVersion);
          expect(await scalar(db, 'PRAGMA user_version'), fixtureSchemaVersion);
          expect(await query(db, 'PRAGMA integrity_check'), [
            {'integrity_check': 'ok'},
          ]);
          expect(await query(db, 'PRAGMA foreign_key_check'), isEmpty);

          // Every AppDatabase table exists in the fixture and is readable.
          for (final table in db.allTables) {
            await db.customSelect('SELECT COUNT(*) FROM "${table.actualTableName}"').getSingle();
          }
          expect(db.allTables.map((t) => t.actualTableName).toSet(), fixtureTables.toSet());
          expect(await db.select(db.taskTable).get(), hasLength(results[name]!.rowCounts['task_table']));
        } finally {
          await db.close();
        }
      });
    }
  });

  group('large_usage', () {
    test('has >= 150,000 usage records over >= 3 years and >= 200,000 items', () async {
      final db = AppDatabase.withExecutor(NativeDatabase(copyOf(largeUsageFixture)));
      try {
        final usage = await scalar(db, 'SELECT COUNT(*) FROM app_usage_time_record_table');
        final spanSeconds =
            await scalar(db, 'SELECT MAX(usage_date) - MIN(usage_date) FROM app_usage_time_record_table');
        var total = 0;
        final counts = <String, int>{};
        for (final table in fixtureTables) {
          counts[table] = await scalar(db, 'SELECT COUNT(*) FROM "$table"');
          total += counts[table]!;
        }
        // ignore: avoid_print
        print('large_usage: usage=$usage, span=${(spanSeconds / 86400).toStringAsFixed(1)} days, total=$total, '
            'counts=$counts');

        expect(usage, greaterThanOrEqualTo(150000));
        expect(spanSeconds, greaterThanOrEqualTo(3 * 365 * 86400));
        expect(total, greaterThanOrEqualTo(200000));
        for (final table in ['task_table', 'note_table', 'habit_table', 'habit_record_table', 'tag_table']) {
          expect(counts[table], greaterThan(0), reason: table);
        }
      } finally {
        await db.close();
      }
    });
  });

  group('large_realistic', () {
    test('has the rows and ids of large_usage and realistic text lengths', () async {
      expect(results[largeRealisticFixture]!.rowCounts, results[largeUsageFixture]!.rowCounts);
      expect(hashesA[largeRealisticFixture], isNot(hashesA[largeUsageFixture]));

      final db = AppDatabase.withExecutor(NativeDatabase(copyOf(largeRealisticFixture)));
      try {
        await db.customStatement("ATTACH DATABASE '${copyOf(largeUsageFixture).path.replaceAll("'", "''")}' AS u");
        for (final table in fixtureTables) {
          // Same ids, same timestamps: only free text differs.
          expect(
            await scalar(
                db,
                'SELECT COUNT(*) FROM "$table" a JOIN u."$table" b ON a.id = b.id '
                'AND a.created_date IS b.created_date AND a.modified_date IS b.modified_date '
                'AND a.deleted_date IS b.deleted_date'),
            results[largeUsageFixture]!.rowCounts[table],
            reason: table,
          );
        }
        final usageSame = await scalar(
            db,
            'SELECT COUNT(*) FROM app_usage_time_record_table a JOIN u.app_usage_time_record_table b USING (id) '
            'WHERE a.duration = b.duration AND a.usage_date = b.usage_date AND a.app_usage_id = b.app_usage_id');
        expect(usageSame, results[largeUsageFixture]!.rowCounts['app_usage_time_record_table']);

        Future<Map<String, Object?>> stats(String sql) async => (await query(db, sql)).single;
        final task = await stats('SELECT MIN(LENGTH(title)) AS min_t, MAX(LENGTH(title)) AS max_t, '
            'AVG(description IS NOT NULL) AS desc_share, MIN(LENGTH(description)) AS min_d, '
            'MAX(LENGTH(description)) AS max_d FROM task_table');
        // ignore: avoid_print
        print('large_realistic task text: $task');
        expect(task['min_t'] as int, greaterThanOrEqualTo(20));
        expect(task['max_t'] as int, lessThanOrEqualTo(80));
        expect(task['desc_share'] as double, inInclusiveRange(0.37, 0.43));
        expect(task['min_d'] as int, greaterThanOrEqualTo(50));
        expect(task['max_d'] as int, lessThanOrEqualTo(1500));

        final note = await stats('SELECT MIN(LENGTH(title)) AS min_t, MAX(LENGTH(title)) AS max_t, '
            'MIN(LENGTH(content)) AS min_c, MAX(LENGTH(content)) AS max_c, AVG(LENGTH(content)) AS avg_c, '
            'SUM(LENGTH(content) > 8000) AS tail FROM note_table');
        // ignore: avoid_print
        print('large_realistic note text: $note');
        expect(note['min_t'] as int, greaterThanOrEqualTo(10));
        expect(note['max_t'] as int, lessThanOrEqualTo(60));
        expect(note['min_c'] as int, greaterThanOrEqualTo(200));
        expect(note['max_c'] as int, lessThanOrEqualTo(32000));
        expect(note['tail'] as int, greaterThan(0));

        final other = await stats('SELECT '
            '(SELECT MIN(LENGTH(name)) FROM tag_table) AS tag_min, (SELECT MAX(LENGTH(name)) FROM tag_table) AS tag_max, '
            '(SELECT MIN(LENGTH(name)) FROM app_usage_table) AS app_min, '
            '(SELECT MAX(LENGTH(name)) FROM app_usage_table) AS app_max, '
            '(SELECT COUNT(*) FROM habit_table WHERE description IS NULL) AS habit_null');
        expect(other['tag_min'] as int, greaterThanOrEqualTo(3));
        expect(other['tag_max'] as int, lessThanOrEqualTo(20));
        expect(other['app_min'] as int, greaterThanOrEqualTo(5));
        expect(other['app_max'] as int, lessThanOrEqualTo(60));
        expect(other['habit_null'], 0);
      } finally {
        await db.close();
      }
    });
  });

  group('duplicates', () {
    late Map<String, dynamic> manifest;

    setUpAll(() {
      manifest = jsonDecode(results[duplicatesFixture]!.manifest!.readAsStringSync()) as Map<String, dynamic>;
    });

    /// Identity key of a row per FR-030 rule, computed from the database only.
    const identitySql = {
      'habit_record_day': "SELECT r.id, r.habit_id || '|' || date(r.occurred_at, 'unixepoch') AS k "
          'FROM habit_record_table r JOIN habit_table h ON h.id = r.habit_id WHERE COALESCE(h.daily_target, 1) = 1',
      'setting_key': 'SELECT id, key AS k FROM setting_table',
      'builtin_task_status':
          "SELECT id, CASE is_done_status WHEN 1 THEN 'done' ELSE 'todo' END AS k FROM task_status_table WHERE is_built_in = 1",
      'recurring_occurrence':
          "SELECT id, COALESCE(recurrence_parent_id, id) || '|' || date(planned_date, 'unixepoch') AS k FROM task_table "
              'WHERE planned_date IS NOT NULL AND (recurrence_parent_id IS NOT NULL OR recurrence_type <> 0)',
      'task_tag': "SELECT id, tag_id || '|' || task_id AS k FROM task_tag_table",
      'habit_tag': "SELECT id, tag_id || '|' || habit_id AS k FROM habit_tag_table",
      'note_tag': "SELECT id, tag_id || '|' || note_id AS k FROM note_tag_table",
      'app_usage_tag': "SELECT id, tag_id || '|' || app_usage_id AS k FROM app_usage_tag_table",
      'tag_tag': "SELECT id, primary_tag_id || '|' || secondary_tag_id AS k FROM tag_tag_table",
      'sync_device': "SELECT id, MIN(from_device_id, to_device_id) || '|' || MAX(from_device_id, to_device_id) AS k "
          'FROM sync_device_table',
    };

    test('manifest groups match the identities recomputed from the database', () async {
      final db = AppDatabase.withExecutor(NativeDatabase(copyOf(duplicatesFixture)));
      try {
        final groups = (manifest['duplicateGroups'] as List).cast<Map<String, dynamic>>();
        for (final rule in DuplicateRule.all) {
          // Independent grouping from SQL.
          final byKey = <String, List<String>>{};
          for (final row in await query(db, identitySql[rule]!)) {
            byKey.putIfAbsent(row['k'] as String, () => []).add(row['id'] as String);
          }
          final sqlGroups = {
            for (final e in byKey.entries.where((e) => e.value.length > 1)) e.key: (e.value..sort()),
          };
          final manifestGroups = {
            for (final g in groups.where((g) => g['rule'] == rule))
              g['key'] as String: (g['ids'] as List).cast<String>(),
          };
          expect(manifestGroups, sqlGroups, reason: rule);
          expect(
            groups.any((g) => g['rule'] == rule && (g['liveIds'] as List).length >= 2),
            isTrue,
            reason: '$rule must have a group with at least two live rows',
          );
        }

        // Soft-deleted members exist.
        expect(groups.any((g) => (g['ids'] as List).length > (g['liveIds'] as List).length), isTrue);

        // Target-3 completions on the same day are present and not listed as duplicates.
        final multi = (manifest['multiTargetGroups'] as List).cast<Map<String, dynamic>>();
        expect(multi, isNotEmpty);
        for (final g in multi) {
          final habitId = (g['key'] as String).split('|').first;
          expect(await scalar(db, "SELECT daily_target FROM habit_table WHERE id = '$habitId'"), 3);
          expect((g['liveIds'] as List).length, greaterThanOrEqualTo(2));
          expect(groups.where((d) => d['key'] == g['key']), isEmpty);
        }

        // Built-in status duplicates each have tasks pointing at them.
        for (final g in groups.where((g) => g['rule'] == 'builtin_task_status')) {
          final referenced = (g['dependents'] as List).map((d) => d['references']).toSet();
          expect(referenced, containsAll(g['ids'] as List), reason: g['key'] as String);
        }

        // Scenario 3.4: duplicate occurrences carry different tags, time records and subtasks.
        final scenario = groups.where((g) {
          if (g['rule'] != 'recurring_occurrence') return false;
          final deps = (g['dependents'] as List).cast<Map<String, dynamic>>();
          final tagsByTask = <Object?, Set<Object?>>{};
          for (final d in deps.where((d) => d['table'] == 'task_tag_table')) {
            tagsByTask.putIfAbsent(d['references'], () => {}).add(d['id']);
          }
          return tagsByTask.length >= 2 &&
              deps.any((d) => d['table'] == 'task_time_record_table') &&
              deps.any((d) => d['column'] == 'parent_task_id');
        });
        expect(scenario, isNotEmpty);

        // Manifest row counts match the database.
        final rowCounts = (manifest['rowCounts'] as Map).cast<String, int>();
        for (final table in fixtureTables) {
          expect(await scalar(db, 'SELECT COUNT(*) FROM "$table"'), rowCounts[table], reason: table);
        }
      } finally {
        await db.close();
      }
    });

    test('duplicates_shuffled has the same logical content in a different insertion order', () async {
      // Opened one at a time (drift warns about concurrent instances of one class).
      Future<(Map<String, String>, Map<String, String>)> dump(String name) async {
        final db = AppDatabase.withExecutor(NativeDatabase(copyOf(name)));
        try {
          final content = <String, String>{};
          final insertionOrder = <String, String>{};
          for (final table in fixtureTables) {
            content[table] = jsonEncode(await query(db, 'SELECT * FROM "$table" ORDER BY id'));
            insertionOrder[table] = jsonEncode(await query(db, 'SELECT id FROM "$table" ORDER BY rowid'));
          }
          return (content, insertionOrder);
        } finally {
          await db.close();
        }
      }

      final (contentA, orderA) = await dump(duplicatesFixture);
      final (contentB, orderB) = await dump(duplicatesShuffledFixture);
      for (final table in fixtureTables) {
        expect(contentB[table], contentA[table], reason: table);
      }
      final orderDiffers = fixtureTables.any((t) => orderA[t] != orderB[t]);
      expect(orderDiffers, isTrue);
      expect(hashesA[duplicatesShuffledFixture], isNot(hashesA[duplicatesFixture]));

      final shuffledManifest = jsonDecode(results[duplicatesShuffledFixture]!.manifest!.readAsStringSync()) as Map;
      final original = jsonDecode(results[duplicatesFixture]!.manifest!.readAsStringSync()) as Map;
      expect(shuffledManifest['fixture'], duplicatesShuffledFixture);
      expect({...shuffledManifest}..remove('fixture'), {...original}..remove('fixture'));
    });
  });

  test('empty has no rows', () async {
    final db = AppDatabase.withExecutor(NativeDatabase(copyOf(emptyFixture)));
    try {
      for (final table in fixtureTables) {
        expect(await scalar(db, 'SELECT COUNT(*) FROM "$table"'), 0, reason: table);
      }
    } finally {
      await db.close();
    }
  });
}
