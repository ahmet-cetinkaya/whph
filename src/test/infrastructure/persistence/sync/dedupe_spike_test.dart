// S5 spike (plan T7): dedupe/re-key and clock bootstrap prototype on the
// synthetic v37 fixtures. Oracles (violations, expected counts, orphans) are
// independent SQL written here, not derived from `dedupe_spike.dart`.
@Timeout(Duration(minutes: 20))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../drift/app_database/generated/schema_v37.dart';
import '../../../fixtures/sync/fixture_builder.dart'
    show
        buildFixture,
        defaultFixtureSeed,
        duplicatesFixture,
        duplicatesShuffledFixture,
        fixtureDatabasePath,
        fixtureManifestPath,
        largeUsageFixture;
import 'dedupe_spike.dart';

const _memberId = 'spike-member-a';
const _originId = '0123456789abcdef0123456789abcdef';
const _nowMs = 1790000000000;

/// Every `*_id` column of the v37 schema, classified by the S5 scan.
/// Value: referenced table, or `external:` for ids that are not row ids.
const Map<String, String> _fkClassification = {
  'app_usage_tag_rule_table.tag_id': 'tag_table',
  'app_usage_tag_table.app_usage_id': 'app_usage_table',
  'app_usage_tag_table.tag_id': 'tag_table',
  'app_usage_time_record_table.app_usage_id': 'app_usage_table',
  'habit_record_table.habit_id': 'habit_table',
  'habit_tag_table.habit_id': 'habit_table',
  'habit_tag_table.tag_id': 'tag_table',
  'habit_time_record_table.habit_id': 'habit_table',
  'note_tag_table.note_id': 'note_table',
  'note_tag_table.tag_id': 'tag_table',
  'sync_device_table.from_device_id': 'external:legacy device id',
  'sync_device_table.to_device_id': 'external:legacy device id',
  'tag_tag_table.primary_tag_id': 'tag_table',
  'tag_tag_table.secondary_tag_id': 'tag_table',
  'task_table.parent_task_id': 'task_table',
  'task_table.recurrence_parent_id': 'task_table',
  'task_table.status_id': 'task_status_table',
  'task_tag_table.tag_id': 'tag_table',
  'task_tag_table.task_id': 'task_table',
  'task_time_record_table.task_id': 'task_table',
};

/// The D5 FK rewrite list as written in the plan (`tag_tag.*` expanded).
const List<String> _d5List = [
  'task_tag_table.task_id',
  'habit_tag_table.habit_id',
  'note_tag_table.note_id',
  'app_usage_tag_table.app_usage_id',
  'tag_tag_table.primary_tag_id',
  'tag_tag_table.secondary_tag_id',
  'task_time_record_table.task_id',
  'habit_time_record_table.habit_id',
  'habit_record_table.habit_id',
  'task_table.parent_task_id',
  'task_table.status_id',
  'task_table.recurrence_parent_id',
];

void _log(String message) {
  // ignore: avoid_print
  print('[S5] $message');
}

DatabaseAtV37 _open(File file) => DatabaseAtV37(NativeDatabase(file, setup: (raw) {
      raw.execute('PRAGMA journal_mode=WAL');
      raw.execute('PRAGMA busy_timeout=5000');
    }));

Future<List<Map<String, Object?>>> _rows(GeneratedDatabase db, String sql) async =>
    (await db.customSelect(sql).get()).map((r) => r.data).toList();

Future<int> _int(GeneratedDatabase db, String sql) async =>
    ((await db.customSelect(sql).getSingle()).data.values.first as int?) ?? 0;

// ---------------------------------------------------------------------------
// Independent oracles
// ---------------------------------------------------------------------------

/// D5c / FR-030 violation oracle: excess rows per identity key (all rows and
/// live rows), plus identity rows whose id is not the deterministic form.
Future<Map<String, int>> _violations(GeneratedDatabase db, int off) async {
  String excess(String from, String groupBy, {String where = '1'}) =>
      'SELECT IFNULL(SUM(c - 1), 0) FROM (SELECT COUNT(*) AS c FROM $from WHERE $where GROUP BY $groupBy HAVING c > 1)';
  final checks = <String, String>{
    'habit_record_day': excess('habit_record_table r JOIN habit_table h ON h.id = r.habit_id',
        "r.habit_id, date(r.occurred_at + $off, 'unixepoch')",
        where: '(h.daily_target IS NULL OR h.daily_target = 1)'),
    'setting_key': excess('setting_table', 'key'),
    'builtin_task_status': excess('task_status_table', 'is_done_status', where: 'is_built_in = 1'),
    'recurring_occurrence': excess(
        'task_table', "IFNULL(recurrence_parent_id, id), date(planned_date + $off, 'unixepoch')",
        where: 'planned_date IS NOT NULL AND (recurrence_parent_id IS NOT NULL OR recurrence_type != 0)'),
    'task_tag': excess('task_tag_table', 'tag_id, task_id'),
    'habit_tag': excess('habit_tag_table', 'tag_id, habit_id'),
    'note_tag': excess('note_tag_table', 'tag_id, note_id'),
    'app_usage_tag': excess('app_usage_tag_table', 'tag_id, app_usage_id'),
    'tag_tag': excess('tag_tag_table', 'primary_tag_id, secondary_tag_id'),
    'sync_device': excess('sync_device_table',
        "CASE WHEN from_device_id < to_device_id THEN from_device_id || '|' || to_device_id ELSE to_device_id || '|' || from_device_id END"),
  };
  final result = <String, int>{};
  for (final e in checks.entries) {
    result[e.key] = await _int(db, e.value);
    result['${e.key}(live)'] = await _int(db, e.value.replaceFirst(' GROUP BY', ' AND ${_liveOf(e.key)} GROUP BY'));
  }

  // Deterministic-form check (every identity row carries its UUIDv5 id).
  var wrongForm = 0;
  Future<void> form(String sql, String Function(Map<String, Object?>) expected) async {
    for (final row in await _rows(db, sql)) {
      if (row['id'] != expected(row)) wrongForm++;
    }
  }

  await form(
      "SELECT r.id, r.habit_id AS a, date(r.occurred_at + $off, 'unixepoch') AS b FROM habit_record_table r "
      'JOIN habit_table h ON h.id = r.habit_id WHERE h.daily_target IS NULL OR h.daily_target = 1',
      (r) => syncIdentityId('habit_record', [r['a'] as String, r['b'] as String]));
  await form('SELECT id, key AS a FROM setting_table', (r) => syncIdentityId('setting', [r['a'] as String]));
  await form('SELECT id, is_done_status AS a FROM task_status_table WHERE is_built_in = 1',
      (r) => r['a'] == 1 ? 'task-status-builtin-done' : 'task-status-builtin-todo');
  await form(
      "SELECT id, recurrence_parent_id AS a, date(planned_date + $off, 'unixepoch') AS b FROM task_table "
      'WHERE planned_date IS NOT NULL AND recurrence_parent_id IS NOT NULL',
      (r) => syncIdentityId('task_occurrence', [r['a'] as String, r['b'] as String]));
  for (final (table, kind, item) in [
    ('task_tag_table', 'task_tag', 'task_id'),
    ('habit_tag_table', 'habit_tag', 'habit_id'),
    ('note_tag_table', 'note_tag', 'note_id'),
    ('app_usage_tag_table', 'app_usage_tag', 'app_usage_id'),
  ]) {
    await form('SELECT id, tag_id AS a, $item AS b FROM $table',
        (r) => syncIdentityId(kind, [r['a'] as String, r['b'] as String]));
  }
  await form('SELECT id, primary_tag_id AS a, secondary_tag_id AS b FROM tag_tag_table',
      (r) => syncIdentityId('tag_tag', [r['a'] as String, r['b'] as String]));
  result['deterministic_id_form'] = wrongForm;
  return result;
}

String _liveOf(String check) => switch (check) {
      'habit_record_day' => 'r.deleted_date IS NULL',
      _ => 'deleted_date IS NULL',
    };

/// Expected post-merge counts computed from the pre-merge DB: every identity
/// collapses to one row (live if any member is live); every other row stays.
Map<String, String> _expectedCountSql(int off) {
  final tk = 'WITH tk AS (SELECT id, CASE WHEN planned_date IS NOT NULL AND '
      '(recurrence_parent_id IS NOT NULL OR recurrence_type != 0) '
      "THEN 'R|' || IFNULL(recurrence_parent_id, id) || '|' || date(planned_date + $off, 'unixepoch') "
      "ELSE 'T|' || id END AS k FROM task_table) ";
  const t1 = '(h.daily_target IS NULL OR h.daily_target = 1)';
  final hday = "r.habit_id || '|' || date(r.occurred_at + $off, 'unixepoch')";
  String link(String table, String item) => 'SELECT COUNT(DISTINCT tag_id || \'|\' || $item) FROM $table';
  return {
    'task.rows': '${tk}SELECT COUNT(DISTINCT k) FROM tk',
    'task.live':
        '${tk}SELECT COUNT(DISTINCT tk.k) FROM tk JOIN task_table t ON t.id = tk.id WHERE t.deleted_date IS NULL',
    'subtask.rows':
        '${tk}SELECT COUNT(DISTINCT tk.k) FROM tk JOIN task_table t ON t.id = tk.id WHERE t.parent_task_id IS NOT NULL',
    'subtask.live': '${tk}SELECT COUNT(DISTINCT tk.k) FROM tk JOIN task_table t ON t.id = tk.id '
        'WHERE t.parent_task_id IS NOT NULL AND t.deleted_date IS NULL',
    'subtask.parents': '${tk}SELECT COUNT(DISTINCT IFNULL(pk.k, t.parent_task_id)) FROM task_table t '
        'LEFT JOIN tk pk ON pk.id = t.parent_task_id WHERE t.parent_task_id IS NOT NULL',
    'occurrence.series': '${tk}SELECT COUNT(DISTINCT recurrence_parent_id) FROM task_table',
    'task_tag.rows': "${tk}SELECT COUNT(DISTINCT x.tag_id || '|' || IFNULL(tk.k, x.task_id)) FROM task_tag_table x "
        'LEFT JOIN tk ON tk.id = x.task_id',
    'task_tag.live': "${tk}SELECT COUNT(DISTINCT x.tag_id || '|' || IFNULL(tk.k, x.task_id)) FROM task_tag_table x "
        'LEFT JOIN tk ON tk.id = x.task_id WHERE x.deleted_date IS NULL',
    'task_time_record.rows': 'SELECT COUNT(*) FROM task_time_record_table',
    'task_time_record.live': 'SELECT COUNT(*) FROM task_time_record_table WHERE deleted_date IS NULL',
    'task_time_record.duration': 'SELECT IFNULL(SUM(duration), 0) FROM task_time_record_table',
    'task_time_record.owners': '${tk}SELECT COUNT(DISTINCT IFNULL(tk.k, x.task_id)) FROM task_time_record_table x '
        'LEFT JOIN tk ON tk.id = x.task_id',
    'task.status_refs':
        '${tk}SELECT COUNT(DISTINCT tk.k) FROM tk JOIN task_table t ON t.id = tk.id WHERE t.status_id IS NOT NULL',
    'task_status.rows': 'SELECT (SELECT COUNT(DISTINCT is_done_status) FROM task_status_table WHERE is_built_in = 1) + '
        '(SELECT COUNT(*) FROM task_status_table WHERE is_built_in = 0)',
    'setting.rows': 'SELECT COUNT(DISTINCT key) FROM setting_table',
    'setting.live': 'SELECT COUNT(DISTINCT key) FROM setting_table WHERE deleted_date IS NULL',
    'sync_device.rows':
        "SELECT COUNT(DISTINCT MIN(from_device_id, to_device_id) || '|' || MAX(from_device_id, to_device_id)) "
            'FROM sync_device_table',
    'habit_record.rows': 'SELECT '
        '(SELECT COUNT(DISTINCT $hday) FROM habit_record_table r JOIN habit_table h ON h.id = r.habit_id WHERE $t1) + '
        '(SELECT COUNT(*) FROM habit_record_table r LEFT JOIN habit_table h ON h.id = r.habit_id '
        'WHERE h.id IS NULL OR NOT $t1)',
    'habit_record.live': 'SELECT '
        '(SELECT COUNT(DISTINCT $hday) FROM habit_record_table r JOIN habit_table h ON h.id = r.habit_id '
        'WHERE $t1 AND r.deleted_date IS NULL) + '
        '(SELECT COUNT(*) FROM habit_record_table r LEFT JOIN habit_table h ON h.id = r.habit_id '
        'WHERE (h.id IS NULL OR NOT $t1) AND r.deleted_date IS NULL)',
    'habit_tag.rows': link('habit_tag_table', 'habit_id'),
    'habit_tag.live': '${link('habit_tag_table', 'habit_id')} WHERE deleted_date IS NULL',
    'note_tag.rows': link('note_tag_table', 'note_id'),
    'note_tag.live': '${link('note_tag_table', 'note_id')} WHERE deleted_date IS NULL',
    'app_usage_tag.rows': link('app_usage_tag_table', 'app_usage_id'),
    'app_usage_tag.live': '${link('app_usage_tag_table', 'app_usage_id')} WHERE deleted_date IS NULL',
    'tag_tag.rows': "SELECT COUNT(DISTINCT primary_tag_id || '|' || secondary_tag_id) FROM tag_tag_table",
    'tag_tag.live':
        "SELECT COUNT(DISTINCT primary_tag_id || '|' || secondary_tag_id) FROM tag_tag_table WHERE deleted_date IS NULL",
    for (final t in [
      'habit_time_record_table',
      'app_usage_time_record_table',
      'habit_table',
      'note_table',
      'tag_table',
      'app_usage_table',
      'app_usage_tag_rule_table',
      'app_usage_ignore_rule_table',
    ]) ...{
      '$t.rows': 'SELECT COUNT(*) FROM $t',
      '$t.live': 'SELECT COUNT(*) FROM $t WHERE deleted_date IS NULL',
    },
    'habit_time_record.duration': 'SELECT IFNULL(SUM(duration), 0) FROM habit_time_record_table',
    'app_usage_time_record.duration': 'SELECT IFNULL(SUM(duration), 0) FROM app_usage_time_record_table',
  };
}

/// The same metrics measured directly on the merged DB.
Map<String, String> _actualCountSql() {
  String count(String table, {bool live = false, String extra = ''}) =>
      'SELECT COUNT(*) FROM $table WHERE 1 ${live ? 'AND deleted_date IS NULL' : ''} $extra';
  final sql = <String, String>{
    'task.rows': count('task_table'),
    'task.live': count('task_table', live: true),
    'subtask.rows': count('task_table', extra: 'AND parent_task_id IS NOT NULL'),
    'subtask.live': count('task_table', live: true, extra: 'AND parent_task_id IS NOT NULL'),
    'subtask.parents': 'SELECT COUNT(DISTINCT parent_task_id) FROM task_table',
    'occurrence.series': 'SELECT COUNT(DISTINCT recurrence_parent_id) FROM task_table',
    'task_tag.rows': count('task_tag_table'),
    'task_tag.live': count('task_tag_table', live: true),
    'task_time_record.rows': count('task_time_record_table'),
    'task_time_record.live': count('task_time_record_table', live: true),
    'task_time_record.duration': 'SELECT IFNULL(SUM(duration), 0) FROM task_time_record_table',
    'task_time_record.owners': 'SELECT COUNT(DISTINCT task_id) FROM task_time_record_table',
    'task.status_refs': 'SELECT COUNT(*) FROM task_table WHERE status_id IS NOT NULL',
    'task_status.rows': count('task_status_table'),
    'setting.rows': count('setting_table'),
    'setting.live': count('setting_table', live: true),
    'sync_device.rows': count('sync_device_table'),
    'habit_record.rows': count('habit_record_table'),
    'habit_record.live': count('habit_record_table', live: true),
    'habit_time_record.duration': 'SELECT IFNULL(SUM(duration), 0) FROM habit_time_record_table',
    'app_usage_time_record.duration': 'SELECT IFNULL(SUM(duration), 0) FROM app_usage_time_record_table',
  };
  for (final t in ['habit_tag', 'note_tag', 'app_usage_tag', 'tag_tag']) {
    sql['$t.rows'] = count('${t}_table');
    sql['$t.live'] = count('${t}_table', live: true);
  }
  for (final t in [
    'habit_time_record_table',
    'app_usage_time_record_table',
    'habit_table',
    'note_table',
    'tag_table',
    'app_usage_table',
    'app_usage_tag_rule_table',
    'app_usage_ignore_rule_table',
  ]) {
    sql['$t.rows'] = count(t);
    sql['$t.live'] = count(t, live: true);
  }
  return sql;
}

Future<Map<String, int>> _evaluate(GeneratedDatabase db, Map<String, String> sql) async =>
    {for (final e in sql.entries) e.key: await _int(db, e.value)};

/// Dangling references per classified FK column (target row missing).
Future<Map<String, int>> _orphans(GeneratedDatabase db) async {
  final result = <String, int>{};
  for (final e in _fkClassification.entries) {
    if (e.value.startsWith('external:')) continue;
    final [table, column] = e.key.split('.');
    result[e.key] = await _int(
        db,
        'SELECT COUNT(*) FROM $table x WHERE x.$column IS NOT NULL '
        'AND NOT EXISTS (SELECT 1 FROM ${e.value} y WHERE y.id = x.$column)');
  }
  return result;
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

class _Run {
  _Run(this.db, this.file);
  final DatabaseAtV37 db;
  final File file;
  final List<ChunkTiming> timings = [];
  int chunks = 0;
}

void main() {
  late Directory root;
  late Directory fixtures;
  var copyCounter = 0;
  final opened = <DatabaseAtV37>[];

  setUpAll(() async {
    // Each test opens its own copy (distinct files and executors).
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    root = Directory.systemTemp.createTempSync('whph_s5_dedupe_');
    fixtures = Directory(p.join(root.path, 'fixtures'));
    for (final name in [duplicatesFixture, duplicatesShuffledFixture]) {
      await buildFixture(name, seed: defaultFixtureSeed, out: fixtures);
    }
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

  Future<_Run> openCopy(String name) async {
    final work = Directory(p.join(root.path, 'work'))..createSync(recursive: true);
    final copy = File(fixtureDatabasePath(fixtures, name)).copySync(p.join(work.path, '$name-${copyCounter++}.sqlite'));
    final db = _open(copy);
    opened.add(db);
    await db.customSelect('SELECT 1').get();
    return _Run(db, copy);
  }

  Future<JobRunResult> runJob(
    _Run run, {
    int nowMs = _nowMs,
    int dayOffset = 0,
    int groupsPerChunk = 1,
    int maxCells = 5000,
    int? stopAfterChunks,
    int? failInsideChunk,
  }) async {
    await SpikeSyncSchema.install(run.db, memberId: _memberId, originId: _originId);
    final job = DedupeSpikeJob(run.db,
        nowMs: nowMs,
        dayOffsetSeconds: dayOffset,
        groupsPerChunk: groupsPerChunk,
        maxCellsPerChunk: maxCells,
        failInsideChunk: failInsideChunk,
        onChunk: run.timings.add);
    final result = await job.run(stopAfterChunks: stopAfterChunks);
    run.chunks += result.chunks;
    return result;
  }

  // -------------------------------------------------------------------------

  group('identity ids', () {
    test('UUIDv5 matches the RFC 4122 vector and the WHPH namespace derivation', () {
      expect(uuidV5('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'python.org'), '886313e1-3b8a-5372-9b90-0c9aee199e5d');
      expect(uuidV5(rfc4122UrlNamespace, whphSyncNamespaceName), whphSyncNamespace);
      // Golden values (cross-checked with Python's uuid.uuid5).
      expect(syncIdentityId('setting', ['WORK_TIME']), '1c261436-b0ef-5b9e-8ca5-be85a3b333fb');
      expect(syncIdentityId('task_tag', ['tagA', 'taskB']), '375d6d45-b112-547e-9ebe-86829d66f377');
    });
  });

  group('FK scan (acceptance 7)', () {
    test('every *_id column of v37 is classified; the rewrite list equals FKs into re-keyed tables', () async {
      final run = await openCopy(duplicatesFixture);
      final scanned = (await _rows(
              run.db,
              "SELECT m.name AS t, c.name AS c FROM sqlite_master m JOIN pragma_table_info(m.name) c "
              "WHERE m.type = 'table' AND m.name NOT LIKE 'sqlite_%' AND c.name LIKE '%\\_id' ESCAPE '\\' "
              'ORDER BY 1, 2'))
          .map((r) => '${r['t']}.${r['c']}')
          .toList();
      _log('scanned *_id columns (${scanned.length}): ${scanned.join(', ')}');
      expect(scanned.toSet(), _fkClassification.keys.toSet(), reason: 'unclassified or missing *_id column');

      // Classification is consistent with the data: no dangling reference.
      final orphans = await _orphans(run.db);
      expect(orphans.values.every((v) => v == 0), isTrue, reason: '$orphans');

      final derived = {
        for (final e in _fkClassification.entries)
          if (reKeyedTables.contains(e.value)) e.key,
      };
      final implemented = {
        for (final entries in fkRewriteList.values)
          for (final (t, c) in entries) '$t.$c',
      };
      expect(implemented, derived);
      for (final entry in fkRewriteList.keys) {
        expect(reKeyedTables, contains(entry));
      }

      final d5 = _d5List.toSet();
      final notInD5 = scanned.where((c) => !d5.contains(c)).toList();
      final d5NoOp = _d5List.where((c) => !derived.contains(c)).toList();
      _log('re-keyed tables: ${reKeyedTables.toList()..sort()}');
      _log('final rewrite list: ${implemented.toList()..sort()}');
      _log('D5 entries whose target is never re-keyed (no-op): $d5NoOp');
      _log('*_id columns not in D5 list: ${notInD5.map((c) => '$c->${_fkClassification[c]}').join(', ')}');
      expect(derived.difference(d5), isEmpty, reason: 'rewrite list needs a column D5 does not name');
    });
  });

  group('duplicates fixture', () {
    test('acceptance 1+2: zero violations and counts equal the independent oracle', () async {
      for (final name in [duplicatesFixture, duplicatesShuffledFixture]) {
        final run = await openCopy(name);
        final before = await _violations(run.db, 0);
        final expected = await _evaluate(run.db, _expectedCountSql(0));
        final orphansBefore = await _orphans(run.db);
        _log('$name violations before: $before');

        final result = await runJob(run);
        expect(result.done, isTrue);

        final after = await _violations(run.db, 0);
        final actual = await _evaluate(run.db, _actualCountSql());
        _log('$name violations after: $after');
        _log('$name counts expected==actual: ${jsonEncode(actual)}');
        expect(after.values.every((v) => v == 0), isTrue, reason: '$after');
        expect(actual, expected);
        expect(await _orphans(run.db), orphansBefore);
        expect(before.values.fold(0, (a, b) => a + b), greaterThan(0), reason: 'fixture must contain duplicates');
      }
    });

    test('manifest cross-check: groups merged, multi-target completions kept, dependents follow', () async {
      final run = await openCopy(duplicatesFixture);
      final manifest =
          jsonDecode(File(fixtureManifestPath(fixtures, duplicatesFixture)).readAsStringSync()) as Map<String, Object?>;
      // Occurrences are identity rows themselves (re-keyed): not looked up by old id.
      final recurring = (await _rows(
              run.db, 'SELECT id FROM task_table WHERE recurrence_parent_id IS NOT NULL OR recurrence_type != 0'))
          .map((r) => r['id'])
          .toSet();
      await runJob(run);
      final taskIds = (await _rows(run.db, 'SELECT id FROM task_table')).map((r) => r['id']).toSet();

      for (final g in (manifest['duplicateGroups'] as List).cast<Map<String, Object?>>()) {
        final table = g['table'] as String;
        final ids = (g['ids'] as List).cast<String>();
        final remaining = await _int(run.db, "SELECT COUNT(*) FROM $table WHERE id IN ('${ids.join("','")}')");
        // At most one original id survives (built-in constant or series root).
        expect(remaining, lessThanOrEqualTo(1), reason: '${g['rule']} ${g['key']}');
        for (final dep in (g['dependents'] as List? ?? const []).cast<Map<String, Object?>>()) {
          final depTable = dep['table'] as String;
          final column = dep['column'] as String;
          final rows = await _rows(run.db, "SELECT $column AS ref FROM $depTable WHERE id = '${dep['id']}'");
          // Links and occurrences are re-keyed themselves (covered by the count oracle).
          if (depTable == 'task_tag_table' || recurring.contains(dep['id'])) continue;
          expect(rows, hasLength(1), reason: 'dependent ${dep['id']} lost');
          final ref = rows.single['ref'] as String;
          expect(await _int(run.db, "SELECT COUNT(*) FROM $table WHERE id = '$ref'"), 1,
              reason: 'dependent ${dep['id']} points at a missing survivor');
          if (table == 'task_table') expect(taskIds, contains(ref));
        }
        _log('group ${g['rule']} ${g['key']}: ${ids.length} rows (${(g['liveIds'] as List).length} live) merged');
      }

      // Survivor-rule decisions.
      Future<Map<String, Object?>> setting(String key) async =>
          (await _rows(run.db, "SELECT * FROM setting_table WHERE key = '$key'")).single;
      expect((await setting('WORK_TIME'))['value'], '50', reason: 'latest edit wins');
      expect((await setting('WORK_TIME'))['id'], syncIdentityId('setting', ['WORK_TIME']));
      final page = await setting('DEFAULT_PAGE');
      expect([page['value'], page['deleted_date']], ['tasks', null], reason: 'a live row beats a soft-deleted one');
      final daily = (await _rows(run.db, "SELECT * FROM task_table WHERE title = 'Daily recurring series'"));
      final root = daily.singleWhere((r) => r['recurrence_parent_id'] == null);
      expect(root['recurrence_type'], 1, reason: 'series root keeps its id and series definition');
      expect(daily.where((r) => r['recurrence_parent_id'] == root['id']), hasLength(3), reason: 'days 2, 3, 4');
      // Scenario 3.4: the day-2 survivor carries the union of tags, time records and subtasks.
      final day2 = syncIdentityId('task_occurrence', [root['id'] as String, '2025-03-03']);
      expect(await _int(run.db, "SELECT COUNT(*) FROM task_tag_table WHERE task_id = '$day2'"), 3);
      expect(await _int(run.db, "SELECT COUNT(*) FROM task_time_record_table WHERE task_id = '$day2'"), 3);
      expect(await _int(run.db, "SELECT COUNT(*) FROM task_table WHERE parent_task_id = '$day2'"), 2);

      for (final g in (manifest['multiTargetGroups'] as List).cast<Map<String, Object?>>()) {
        final ids = (g['ids'] as List).cast<String>();
        expect(await _int(run.db, "SELECT COUNT(*) FROM habit_record_table WHERE id IN ('${ids.join("','")}')"),
            ids.length,
            reason: 'target-3 completions must not merge');
      }
    });

    test('acceptance 3: re-running is a no-op (checksum equal)', () async {
      final run = await openCopy(duplicatesFixture);
      await runJob(run, maxCells: 40);
      final first = await databaseChecksum(run.db);

      // Job already done: nothing to do.
      final again = await runJob(run, nowMs: _nowMs + 999);
      expect(again.chunks, 0);
      expect(await databaseChecksum(run.db), first);

      // Full re-run from phase dedupe (e.g. a stray reset): still a no-op.
      await run.db.customStatement("UPDATE sync_state SET upgrade_phase = 'dedupe', upgrade_cursor = NULL");
      final rerun = await runJob(run, nowMs: _nowMs + 999, maxCells: 40);
      final second = await databaseChecksum(run.db);
      _log('rerun: ${rerun.chunks} chunks (bootstrap chunks insert 0 cells), checksum $first -> $second');
      expect(run.timings.where((t) => t.phase == 'dedupe').length, greaterThan(0));
      expect(second, first);
    });

    test('acceptance 4: duplicates and duplicates_shuffled give identical survivors and values', () async {
      final a = await openCopy(duplicatesFixture);
      final b = await openCopy(duplicatesShuffledFixture);
      // Same logical rows, different physical (rowid) order.
      const physical = "SELECT group_concat(id, ',') FROM (SELECT id FROM task_table ORDER BY rowid)";
      expect(
          (await _rows(a.db, physical)).single.values.first, isNot((await _rows(b.db, physical)).single.values.first));
      await runJob(a);
      await runJob(b);
      final user = [await databaseChecksum(a.db, includeSync: false), await databaseChecksum(b.db, includeSync: false)];
      final full = [await databaseChecksum(a.db), await databaseChecksum(b.db)];
      _log('duplicates vs shuffled user-table checksum: ${user[0]} / ${user[1]}');
      _log('duplicates vs shuffled full checksum (incl. sync_clock): ${full[0]} / ${full[1]}');
      expect(user[1], user[0]);
      expect(full[1], full[0]);
    });

    test('time-zone offset within the fixture guarantee gives the same result', () async {
      final a = await openCopy(duplicatesFixture);
      final b = await openCopy(duplicatesFixture);
      await runJob(a);
      await runJob(b, dayOffset: 3 * 3600);
      expect(await databaseChecksum(b.db), await databaseChecksum(a.db));
      final c = await openCopy(duplicatesFixture);
      await runJob(c, dayOffset: 12 * 3600);
      final differs = await databaseChecksum(c.db) != await databaseChecksum(a.db);
      _log('offset +12h (outside the fixture guarantee) changes ids: $differs');
    });

    test('acceptance 5: abort between chunks / crash inside a chunk, then resume == uninterrupted', () async {
      const maxCells = 40; // many bootstrap chunks on the small fixture
      final reference = await openCopy(duplicatesFixture);
      await runJob(reference, maxCells: maxCells);
      final expected = await databaseChecksum(reference.db);
      final total = reference.chunks;
      final dedupeChunks = reference.timings.where((t) => t.phase == 'dedupe').length;
      _log('uninterrupted: $total chunks ($dedupeChunks dedupe, ${total - dedupeChunks} bootstrap)');

      final rnd = Random(20260927);
      final points = <int>{};
      while (points.length < 20) {
        points.add(1 + rnd.nextInt(total - 1));
      }
      for (final point in points.toList()..sort()) {
        final run = await openCopy(duplicatesFixture);
        final partial = await runJob(run, maxCells: maxCells, stopAfterChunks: point);
        expect(partial.done, isFalse);
        final state = (await _rows(run.db, 'SELECT upgrade_phase, upgrade_cursor FROM sync_state')).single;
        // Resume with a different wall clock: stored upgrade_started_at is reused.
        final rest = await runJob(run, nowMs: _nowMs + 123456, maxCells: maxCells);
        expect(rest.done, isTrue);
        expect(await databaseChecksum(run.db), expected, reason: 'abort after chunk $point ($state)');
        await run.db.close();
        opened.remove(run.db);
      }
      _log('abort points ${(points.toList()..sort())}: all resumed to $expected');

      final crashes = <int>{};
      while (crashes.length < 6) {
        crashes.add(1 + rnd.nextInt(total));
      }
      for (final point in crashes.toList()..sort()) {
        final run = await openCopy(duplicatesFixture);
        await expectLater(runJob(run, maxCells: maxCells, failInsideChunk: point), throwsA(isA<SimulatedCrash>()));
        expect(await _int(run.db, 'SELECT apply_mode FROM sync_state'), 0, reason: 'rolled back');
        await runJob(run, nowMs: _nowMs + 1, maxCells: maxCells);
        expect(await databaseChecksum(run.db), expected, reason: 'crash inside chunk $point');
        await run.db.close();
        opened.remove(run.db);
      }
      _log('crash-inside-chunk points ${(crashes.toList()..sort())}: all resumed to $expected');
    });

    test('bootstrap: D6 cells for every live and soft-deleted row, gapless ascending seqs', () async {
      final run = await openCopy(duplicatesFixture);
      await runJob(run, maxCells: 40);
      await _checkBootstrap(run.db);
    });

    test('bootstrap INSERT OR IGNORE keeps a clock captured between chunks', () async {
      final run = await openCopy(duplicatesFixture);
      // Run until the bootstrap has started, then simulate a trigger capture of
      // a later table's cell (tag_tag tombstone cell of its largest pk).
      await SpikeSyncSchema.install(run.db, memberId: _memberId, originId: _originId);
      while ((await _rows(run.db, 'SELECT upgrade_phase FROM sync_state')).single['upgrade_phase'] != 'bootstrap' ||
          (await _int(run.db, 'SELECT COUNT(*) FROM sync_clock')) == 0) {
        await runJob(run, maxCells: 40, stopAfterChunks: 1);
      }
      final pk = (await _rows(run.db, 'SELECT MAX(id) AS id FROM tag_tag_table')).single['id'] as String;
      const capturedHlc = 0x7fff << 40;
      await run.db.customStatement('''
INSERT INTO sync_clock (tbl_id, pk, col_id, hlc, node_id, origin_id, origin_seq, recorded_at)
SELECT 18, ?, 0, ?, member_node_id, local_origin_id, next_seq, 1 FROM sync_state''', [pk, capturedHlc]);
      await run.db.customStatement('UPDATE sync_state SET next_seq = next_seq + 1');
      await runJob(run, maxCells: 40);
      final cell = (await _rows(run.db, "SELECT hlc FROM sync_clock WHERE tbl_id = 18 AND pk = '$pk' AND col_id = 0"));
      expect(cell.single['hlc'], capturedHlc);
      expect(await _int(run.db, 'SELECT COUNT(*) - COUNT(DISTINCT origin_seq) FROM sync_clock'), 0);
      expect(await _int(run.db, 'SELECT MAX(origin_seq) - COUNT(*) FROM sync_clock'), 0, reason: 'gapless');
    });
  });

  group('large_usage fixture', () {
    test('acceptance 1/2/3/5/6 on ~200k rows with chunk timings', () async {
      final build = await buildFixture(largeUsageFixture, seed: defaultFixtureSeed, out: fixtures);
      _log('large_usage built: ${build.totalRows} rows');
      final run = await openCopy(largeUsageFixture);
      final expected = await _evaluate(run.db, _expectedCountSql(0));
      final before = await _violations(run.db, 0);
      _log('large_usage violations before: $before');

      final sw = Stopwatch()..start();
      await runJob(run);
      sw.stop();
      final summary = ChunkTimingSummary(run.timings);
      _log('large_usage Linux run ${sw.elapsedMilliseconds} ms total (groupsPerChunk 1, maxCells 5000)\n'
          '${summary.describe()}');
      final after = await _violations(run.db, 0);
      _log('large_usage violations after: $after');
      expect(after.values.every((v) => v == 0), isTrue);
      expect(await _evaluate(run.db, _actualCountSql()), expected);
      expect((await _orphans(run.db)).values, everyElement(0));
      await _checkBootstrap(run.db);
      expect(summary.slowestOverall!.elapsed, lessThan(const Duration(seconds: 2)));

      final firstRunChunks = run.chunks;
      final checksum = await databaseChecksum(run.db);
      await run.db.customStatement("UPDATE sync_state SET upgrade_phase = 'dedupe', upgrade_cursor = NULL");
      final rerunSw = Stopwatch()..start();
      await runJob(run, nowMs: _nowMs + 5);
      rerunSw.stop();
      expect(await databaseChecksum(run.db), checksum);
      _log('large_usage re-run no-op in ${rerunSw.elapsedMilliseconds} ms, checksum $checksum');

      // One random abort point, resumed.
      final point = 1 + Random(37).nextInt(firstRunChunks - 1);
      final resumed = await openCopy(largeUsageFixture);
      await runJob(resumed, stopAfterChunks: point);
      await runJob(resumed, nowMs: _nowMs + 77);
      expect(await databaseChecksum(resumed.db), checksum, reason: 'abort after chunk $point');
      _log('large_usage abort after chunk $point resumed to the same checksum (first run $firstRunChunks chunks)');

      // Timing comparison: batching groups per chunk (not D17's one group per chunk).
      final batched = await openCopy(largeUsageFixture);
      final batchedSw = Stopwatch()..start();
      await runJob(batched, groupsPerChunk: 250);
      batchedSw.stop();
      final batchedSummary = ChunkTimingSummary(batched.timings);
      _log('large_usage Linux run with groupsPerChunk 250: ${batchedSw.elapsedMilliseconds} ms total\n'
          '${batchedSummary.describe()}');
      expect(await databaseChecksum(batched.db), checksum, reason: 'batching must not change the result');
      expect(batchedSummary.slowestOverall!.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });
}

/// D6 coverage oracle (independent SQL over sync_clock and the base rows).
Future<void> _checkBootstrap(GeneratedDatabase db) async {
  for (final policy in spikeSyncedTables) {
    final synced = (await _rows(db, 'PRAGMA table_info("${policy.table}")'))
        .map((r) => r['name'] as String)
        .where((c) => !auditColumns.contains(c))
        .length;
    final perRow = policy.fieldLevel ? synced + 1 : 2;
    final rows = await _int(db, 'SELECT COUNT(*) FROM ${policy.table}');
    final cells = await _int(db, 'SELECT COUNT(*) FROM sync_clock WHERE tbl_id = ${policy.tblId}');
    expect(cells, rows * perRow, reason: policy.table);
    final badTomb = await _int(
        db,
        'SELECT COUNT(*) FROM ${policy.table} t LEFT JOIN sync_clock s '
        'ON s.tbl_id = ${policy.tblId} AND s.pk = t.id AND s.col_id = 0 '
        'WHERE s.pk IS NULL OR s.tomb_value IS NOT t.deleted_date');
    expect(badTomb, 0, reason: '${policy.table} tombstone cells');
    final badHlc = await _int(
        db,
        'SELECT COUNT(*) FROM sync_clock s JOIN ${policy.table} t ON t.id = s.pk '
        'WHERE s.tbl_id = ${policy.tblId} AND s.hlc != '
        '(MAX(t.created_date, IFNULL(t.modified_date, 0), IFNULL(t.deleted_date, 0)) * 1000 * 65536)');
    expect(badHlc, 0, reason: '${policy.table} hlc');
  }
  expect(await _int(db, "SELECT COUNT(*) FROM sync_clock WHERE pk IN (SELECT id FROM sync_device_table)"), 0);
  final ordered = await _int(
      db,
      'SELECT COUNT(*) FROM (SELECT origin_seq, LAG(origin_seq) OVER (ORDER BY tbl_id, pk, col_id) AS prev '
      'FROM sync_clock) WHERE prev IS NOT NULL AND origin_seq != prev + 1');
  expect(ordered, 0, reason: 'origin_seq ascending and gapless in (tbl_id, pk, col_id) order');
  expect(await _int(db, 'SELECT next_seq - 1 - (SELECT COUNT(*) FROM sync_clock) FROM sync_state'), 0);
  expect(await _int(db, 'SELECT hlc - (SELECT MAX(hlc) FROM sync_clock) FROM sync_state'), 0);
  expect(await _int(db, "SELECT COUNT(*) FROM sync_state WHERE upgrade_phase = 'done' AND apply_mode = 0"), 1);
}
