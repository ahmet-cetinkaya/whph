/// Deterministic builder for the synthetic schema-v37 sync fixtures (plan T2).
///
/// Every fixture is generated from a seed. Nothing here reads, copies or
/// derives from a real user database: all names, texts and ids are synthetic.
///
/// The schema is pinned to the generated `schema_v37.dart` snapshot (not to the
/// live `AppDatabase`), so the fixtures stay at v37 after later schema bumps.
/// This file must not import Flutter so it can run under `fvm dart run`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../../drift/app_database/generated/schema_v37.dart';

const int fixtureSchemaVersion = 37;
const int defaultFixtureSeed = 37020927;

const String largeUsageFixture = 'large_usage';
const String duplicatesFixture = 'duplicates';
const String duplicatesShuffledFixture = 'duplicates_shuffled';
const String emptyFixture = 'empty';

/// `large_usage` with realistic text lengths (S3 re-run, plan PA-1). Same seed, same rows, ids, dates and
/// numbers as [largeUsageFixture]; only the free-text columns differ. See [_RealisticText] for the distribution.
const String largeRealisticFixture = 'large_realistic';

const List<String> fixtureNames = [
  largeUsageFixture,
  duplicatesFixture,
  duplicatesShuffledFixture,
  emptyFixture,
  largeRealisticFixture,
];

/// Mirrors `TaskStatusConstants.todoId` / `doneId` (not imported: that file
/// pulls in Flutter through `acore`).
const String builtInTodoStatusId = 'task-status-builtin-todo';
const String builtInDoneStatusId = 'task-status-builtin-done';

/// All v37 user tables, in a fixed order.
const List<String> fixtureTables = [
  'app_usage_ignore_rule_table',
  'app_usage_table',
  'app_usage_tag_rule_table',
  'app_usage_tag_table',
  'app_usage_time_record_table',
  'habit_record_table',
  'habit_table',
  'habit_tag_table',
  'habit_time_record_table',
  'note_table',
  'note_tag_table',
  'setting_table',
  'sync_device_table',
  'tag_table',
  'tag_tag_table',
  'task_table',
  'task_status_table',
  'task_tag_table',
  'task_time_record_table',
];

String fixtureDatabasePath(Directory out, String name) => p.join(out.path, '$name.sqlite');
String fixtureManifestPath(Directory out, String name) => p.join(out.path, '$name.manifest.json');

class FixtureResult {
  FixtureResult({
    required this.name,
    required this.seed,
    required this.database,
    required this.manifest,
    required this.rowCounts,
    required this.elapsed,
  });

  final String name;
  final int seed;
  final File database;

  /// JSON sidecar with the duplicate-identity oracle; only for the
  /// `duplicates` and `duplicates_shuffled` fixtures.
  final File? manifest;
  final Map<String, int> rowCounts;
  final Duration elapsed;

  int get totalRows => rowCounts.values.fold(0, (a, b) => a + b);
}

/// Builds fixture [name] into [out] (`<name>.sqlite`, plus
/// `<name>.manifest.json` for the duplicates fixtures). Existing files with the
/// same name are replaced. Same [seed] => byte-identical output.
Future<FixtureResult> buildFixture(String name, {required int seed, required Directory out}) async {
  if (!fixtureNames.contains(name)) {
    throw ArgumentError.value(name, 'name', 'Unknown fixture. Expected one of $fixtureNames');
  }
  final stopwatch = Stopwatch()..start();
  out.createSync(recursive: true);

  List<_Row> rows;
  Map<String, Object?>? manifest;
  switch (name) {
    case largeUsageFixture:
      rows = _LargeUsageBuilder(seed).build();
    case largeRealisticFixture:
      rows = _LargeUsageBuilder(seed, realistic: true).build();
    case duplicatesFixture:
    case duplicatesShuffledFixture:
      final builder = _DuplicatesBuilder(seed)..build();
      rows = builder.rows;
      manifest = builder.manifest(name);
      if (name == duplicatesShuffledFixture) {
        rows = _shuffledDistinct(rows, seed);
      }
    default:
      rows = const [];
  }

  final dbFile = File(fixtureDatabasePath(out, name));
  await _writeDatabase(dbFile, rows);

  File? manifestFile;
  if (manifest != null) {
    manifestFile = File(fixtureManifestPath(out, name));
    manifestFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
  }

  final counts = <String, int>{for (final t in fixtureTables) t: 0};
  for (final row in rows) {
    counts[row.table] = counts[row.table]! + 1;
  }
  stopwatch.stop();
  return FixtureResult(
    name: name,
    seed: seed,
    database: dbFile,
    manifest: manifestFile,
    rowCounts: counts,
    elapsed: stopwatch.elapsed,
  );
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

class _Row {
  _Row(this.table, Map<String, Object?> data)
      : columns = data.keys.toList(growable: false),
        values = data.values.toList(growable: false);

  final String table;
  final List<String> columns;
  final List<Object?> values;

  String get id => values[columns.indexOf('id')] as String;
  Object? operator [](String column) {
    final index = columns.indexOf(column);
    return index < 0 ? null : values[index];
  }
}

Future<void> _writeDatabase(File file, List<_Row> rows) async {
  for (final path in [file.path, '${file.path}-journal', '${file.path}-wal', '${file.path}-shm']) {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  }

  // Foreign keys stay OFF (SQLite default, drift does not enable them), so the
  // shuffled fixture can insert children before parents. Integrity is checked
  // by the test with PRAGMA foreign_key_check.
  final db = DatabaseAtV37(NativeDatabase(file));
  try {
    // First statement opens the connection; drift's default strategy runs
    // createAll() and sets user_version = 37.
    await db.customSelect('SELECT 1').get();
    await db.customStatement('PRAGMA user_version = $fixtureSchemaVersion');

    if (rows.isNotEmpty) {
      final sqlCache = <String, String>{};
      await db.batch((batch) {
        for (final row in rows) {
          final key = '${row.table}(${row.columns.join(',')})';
          final sql = sqlCache.putIfAbsent(
            key,
            () => 'INSERT INTO "${row.table}" (${row.columns.map((c) => '"$c"').join(', ')}) '
                'VALUES (${List.filled(row.columns.length, '?').join(', ')})',
          );
          batch.customStatement(sql, row.values);
        }
      });
    }

    // Canonical page layout for byte-identical output.
    await db.customStatement('VACUUM');
  } finally {
    await db.close();
  }
}

/// Deterministic Fisher-Yates shuffle that is guaranteed to change the order.
List<_Row> _shuffledDistinct(List<_Row> rows, int seed) {
  final shuffled = List<_Row>.of(rows);
  shuffled.shuffle(Random(seed ^ 0x5A17F1E));
  var same = true;
  for (var i = 0; i < rows.length && same; i++) {
    same = identical(rows[i], shuffled[i]);
  }
  if (same && shuffled.length > 1) return rows.reversed.toList();
  return shuffled;
}

// ---------------------------------------------------------------------------
// Shared generation helpers
// ---------------------------------------------------------------------------

const _words = [
  'alpha', 'bravo', 'cedar', 'delta', 'ember', 'fjord', 'grove', 'harbor', 'island', 'jade', 'kettle', //
  'lantern', 'meadow', 'nectar', 'orbit', 'pebble', 'quartz', 'river', 'summit', 'timber', 'umber', //
  'valley', 'willow', 'xenon', 'yonder', 'zephyr', 'review', 'plan', 'draft', 'call', 'read', 'fix', //
  'write', 'clean', 'buy', 'check', 'update', 'prepare', 'organize', 'practice',
];

class _Gen {
  _Gen(int seed) : rnd = Random(seed);

  final Random rnd;
  final Set<String> _issued = {};

  // Same length and alphabet as nanoid() used by KeyHelper.generateStringId().
  static const _idAlphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_-';
  static const _rankAlphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

  String id() {
    while (true) {
      final buffer = StringBuffer();
      for (var i = 0; i < 21; i++) {
        buffer.write(_idAlphabet[rnd.nextInt(_idAlphabet.length)]);
      }
      final value = buffer.toString();
      if (_issued.add(value)) return value;
    }
  }

  int intIn(int min, int maxInclusive) => min + rnd.nextInt(maxInclusive - min + 1);
  bool chance(double probability) => rnd.nextDouble() < probability;
  T pick<T>(List<T> list) => list[rnd.nextInt(list.length)];

  String words(int count) {
    final buffer = StringBuffer();
    for (var i = 0; i < count; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(pick(_words));
    }
    return buffer.toString();
  }

  String color() => rnd.nextInt(0x1000000).toRadixString(16).toUpperCase().padLeft(6, '0');

  /// Strictly increasing canonical OrderRank strings: '1' + 3 base-62 digits.
  static String rank(int index) {
    final digits = StringBuffer();
    var value = index;
    for (var i = 0; i < 3; i++) {
      digits.write(_rankAlphabet[value % 62]);
      value ~/= 62;
    }
    return '1${digits.toString().split('').reversed.join()}';
  }
}

/// Drift stores DateTime as unix seconds (no `store_date_time_values_as_text`).
int _sec(DateTime utc) => utc.millisecondsSinceEpoch ~/ 1000;

String _utcDay(int seconds) {
  final d = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Map<String, Object?> _audit(int created, {int? modified, int? deleted}) => {
      'created_date': created,
      'modified_date': modified,
      'deleted_date': deleted,
    };

// ---------------------------------------------------------------------------
// large_usage
// ---------------------------------------------------------------------------

class _LargeUsageBuilder {
  _LargeUsageBuilder(int seed, {bool realistic = false})
      : g = _Gen(seed),
        t = realistic ? _RealisticText(seed) : null;

  final _Gen g;

  /// Separate random stream for [largeRealisticFixture] texts; null for [largeUsageFixture].
  final _RealisticText? t;
  final List<_Row> rows = [];

  /// [base] is the large_usage value and is always evaluated first, so the structural random stream (ids, dates,
  /// numbers, choices) is identical in both fixtures and large_usage stays byte-identical. The realistic text comes
  /// from its own stream.
  T _text<T>(T base, T Function(_RealisticText t) realistic) {
    final text = t;
    return text == null ? base : realistic(text);
  }

  static final DateTime start = DateTime.utc(2022, 7, 1);
  static final DateTime end = DateTime.utc(2025, 12, 31);
  static const int usageRecords = 160000;

  int get _days => end.difference(start).inDays + 1;
  int _dayStart(int dayIndex) => _sec(start) + dayIndex * 86400;
  int _randomMoment() => _sec(start) + g.rnd.nextInt(_days * 86400);

  void _add(String table, Map<String, Object?> data) => rows.add(_Row(table, data));

  List<_Row> build() {
    // Tags
    final tagIds = <String>[];
    for (var i = 0; i < 40; i++) {
      final id = g.id();
      tagIds.add(id);
      _add('tag_table', {
        'id': id,
        ..._audit(_sec(start) + i * 3600, modified: g.chance(0.3) ? _randomMoment() : null),
        'name': _text('Tag ${i.toString().padLeft(2, '0')} ${g.words(1)}', (t) => t.phrase(3, 20)),
        'color': g.color(),
        'is_archived': g.chance(0.1) ? 1 : 0,
        'type': g.intIn(0, 2),
      });
    }
    final tagPairs = <String>{};
    while (tagPairs.length < 20) {
      final a = g.pick(tagIds);
      final b = g.pick(tagIds);
      if (a == b || !tagPairs.add('$a|$b')) continue;
      _add('tag_tag_table', {
        'id': g.id(),
        ..._audit(_randomMoment()),
        'primary_tag_id': a,
        'secondary_tag_id': b,
      });
    }

    // App usages
    final appIds = <String>[];
    for (var i = 0; i < 60; i++) {
      final id = g.id();
      appIds.add(id);
      _add('app_usage_table', {
        'id': id,
        ..._audit(_sec(start) + i * 60),
        'name': _text('com.example.app${i.toString().padLeft(2, '0')}', (t) => t.packageName(5, 60)),
        'display_name': _text('App ${i.toString().padLeft(2, '0')} ${g.words(1)}', (t) => t.phrase(5, 60)),
        'color': g.color(),
        'device_name': i.isEven ? 'fixture-desktop' : 'fixture-phone',
      });
    }
    final appTagPairs = <String>{};
    while (appTagPairs.length < 80) {
      final app = g.pick(appIds);
      final tag = g.pick(tagIds);
      if (!appTagPairs.add('$app|$tag')) continue;
      _add('app_usage_tag_table', {
        'id': g.id(),
        ..._audit(_randomMoment()),
        'app_usage_id': app,
        'tag_id': tag,
        'tag_order': appTagPairs.length,
      });
    }
    for (var i = 0; i < 5; i++) {
      _add('app_usage_ignore_rule_table', {
        'id': g.id(),
        'pattern': '^com\\.example\\.ignored$i',
        'description': _text(g.words(3), (t) => t.phrase(10, 120)),
        ..._audit(_randomMoment()),
      });
    }
    for (var i = 0; i < 10; i++) {
      _add('app_usage_tag_rule_table', {
        'id': g.id(),
        'pattern': '^com\\.example\\.app$i.*',
        'tag_id': g.pick(tagIds),
        'description': _text(g.words(2), (t) => t.phrase(10, 120)),
        ..._audit(_randomMoment()),
      });
    }
    // >= 150,000 usage records, first and last day always covered.
    for (var i = 0; i < usageRecords; i++) {
      final dayIndex = (i * (_days - 1)) ~/ (usageRecords - 1);
      final usageDate = _dayStart(dayIndex) + g.intIn(0, 23) * 3600;
      final duration = g.intIn(30, 3600);
      _add('app_usage_time_record_table', {
        'id': g.id(),
        'app_usage_id': g.pick(appIds),
        'duration': duration,
        'usage_date': usageDate,
        ..._audit(usageDate + duration, deleted: g.chance(0.005) ? usageDate + duration + 60 : null),
      });
    }

    // Task statuses
    final statusIds = [builtInTodoStatusId, builtInDoneStatusId];
    _add('task_status_table', {
      'id': builtInTodoStatusId,
      ..._audit(_sec(start)),
      'name': '',
      'color': '9E9E9E',
      'order': 'U',
      'is_built_in': 1,
      'is_done_status': 0,
    });
    _add('task_status_table', {
      'id': builtInDoneStatusId,
      ..._audit(_sec(start)),
      'name': '',
      'color': '4CAF50',
      'order': 'V',
      'is_built_in': 1,
      'is_done_status': 1,
    });
    for (var i = 0; i < 3; i++) {
      final id = g.id();
      statusIds.add(id);
      _add('task_status_table', {
        'id': id,
        ..._audit(_randomMoment()),
        'name': _text('Status ${g.words(1)}', (t) => t.phrase(4, 24)),
        'color': g.color(),
        'order': 'W$i',
        'is_built_in': 0,
        'is_done_status': 0,
      });
    }

    // Tasks: 9,000 top level, 2,000 subtasks, 100 recurring roots x 10 tasks.
    final taskIds = <String>[];
    final topLevel = <String>[];
    var order = 0;
    Map<String, Object?> task({String? parent, int? planned, String? recurrenceParent, int recurrenceType = 0}) {
      final id = g.id();
      final created = planned != null ? planned - g.intIn(0, 7 * 86400) : _randomMoment();
      final done = g.chance(0.55);
      final deleted = g.chance(0.02) ? created + g.intIn(3600, 90 * 86400) : null;
      taskIds.add(id);
      return {
        'id': id,
        'parent_task_id': parent,
        'title': _text('Task ${taskIds.length.toString().padLeft(5, '0')} ${g.words(3)}', (t) => t.phrase(20, 80)),
        'description': _text(g.chance(0.3) ? g.words(12) : null, (t) => t.taskDescription()),
        'priority': g.chance(0.6) ? g.intIn(0, 3) : null,
        'planned_date': planned ?? (g.chance(0.5) ? created + g.intIn(0, 30) * 86400 : null),
        'deadline_date': g.chance(0.2) ? created + g.intIn(1, 60) * 86400 : null,
        'estimated_time': g.chance(0.4) ? g.intIn(1, 16) * 15 : null,
        'completed_at': done ? created + g.intIn(600, 20 * 86400) : null,
        'status_id': done ? builtInDoneStatusId : (g.chance(0.1) ? g.pick(statusIds) : builtInTodoStatusId),
        ..._audit(created, modified: g.chance(0.5) ? created + g.intIn(60, 86400) : null, deleted: deleted),
        'order': _Gen.rank(order++),
        'planned_date_reminder_time': 0,
        'deadline_date_reminder_time': 0,
        'recurrence_type': recurrenceType,
        'recurrence_interval': recurrenceType == 0 ? null : 1,
        'recurrence_start_date': recurrenceType == 0 ? null : planned,
        'recurrence_parent_id': recurrenceParent,
      };
    }

    for (var i = 0; i < 9000; i++) {
      final data = task();
      topLevel.add(data['id'] as String);
      _add('task_table', data);
    }
    for (var i = 0; i < 2000; i++) {
      _add('task_table', task(parent: g.pick(topLevel)));
    }
    for (var i = 0; i < 100; i++) {
      final firstDay = g.intIn(0, _days - 200);
      final rootPlanned = _dayStart(firstDay) + 9 * 3600;
      final root = task(planned: rootPlanned, recurrenceType: 1);
      _add('task_table', root);
      for (var k = 1; k <= 9; k++) {
        _add('task_table', task(planned: rootPlanned + k * 86400, recurrenceParent: root['id'] as String));
      }
    }
    final taskTagPairs = <String>{};
    while (taskTagPairs.length < 8000) {
      final t = g.pick(taskIds);
      final tag = g.pick(tagIds);
      if (!taskTagPairs.add('$t|$tag')) continue;
      _add('task_tag_table', {
        'id': g.id(),
        ..._audit(_randomMoment()),
        'task_id': t,
        'tag_id': tag,
        'tag_order': 0,
      });
    }
    for (var i = 0; i < 6000; i++) {
      final created = _randomMoment();
      _add('task_time_record_table', {
        'id': g.id(),
        'task_id': g.pick(taskIds),
        'duration': g.intIn(60, 7200),
        ..._audit(created),
      });
    }

    // Notes
    final noteIds = <String>[];
    for (var i = 0; i < 1500; i++) {
      final id = g.id();
      noteIds.add(id);
      final created = _randomMoment();
      _add('note_table', {
        'id': id,
        'title': _text('Note ${i.toString().padLeft(4, '0')} ${g.words(2)}', (t) => t.phrase(10, 60)),
        'content': _text(g.words(g.intIn(10, 60)), (t) => t.noteBody()),
        'order': _Gen.rank(i),
        ..._audit(created,
            modified: g.chance(0.4) ? created + g.intIn(60, 86400 * 30) : null,
            deleted: g.chance(0.02) ? created + 86400 : null),
      });
    }
    final noteTagPairs = <String>{};
    while (noteTagPairs.length < 1200) {
      final n = g.pick(noteIds);
      final tag = g.pick(tagIds);
      if (!noteTagPairs.add('$n|$tag')) continue;
      _add('note_tag_table', {
        'id': g.id(),
        'note_id': n,
        'tag_id': tag,
        'tag_order': 0,
        ..._audit(_randomMoment()),
      });
    }

    // Habits: 30 habits, 10,000 records (at most one per habit per day).
    final habitIds = <String>[];
    for (var i = 0; i < 30; i++) {
      final id = g.id();
      habitIds.add(id);
      final target = i % 5 == 0 ? 3 : (i % 3 == 0 ? 1 : null);
      _add('habit_table', {
        'id': id,
        ..._audit(_sec(start) + i * 600),
        'type': i % 7 == 0 ? 1 : 0,
        'name': _text('Habit ${i.toString().padLeft(2, '0')} ${g.words(2)}', (t) => t.phrase(10, 40)),
        'description': _text(g.words(6), (t) => t.habitDescription()),
        'estimated_time': g.chance(0.5) ? g.intIn(1, 8) * 5 : null,
        'archived_date': null,
        'has_reminder': 0,
        'reminder_days': '',
        'has_goal': target == null ? 0 : 1,
        'target_frequency': target == null ? 1 : g.intIn(1, 7),
        'period_days': 7,
        'daily_target': target,
        'order': _Gen.rank(i),
      });
    }
    for (var i = 0; i < 10000; i++) {
      final habit = i % habitIds.length;
      final dayIndex = (i ~/ habitIds.length) * 3 + habit % 3;
      final occurred = _dayStart(dayIndex) + 12 * 3600 + g.intIn(-1800, 1800);
      _add('habit_record_table', {
        'id': g.id(),
        ..._audit(occurred),
        'habit_id': habitIds[habit],
        'occurred_at': occurred,
        'status': g.chance(0.9) ? 0 : g.intIn(1, 2),
      });
    }
    final habitTagPairs = <String>{};
    while (habitTagPairs.length < 40) {
      final h = g.pick(habitIds);
      final tag = g.pick(tagIds);
      if (!habitTagPairs.add('$h|$tag')) continue;
      _add('habit_tag_table', {
        'id': g.id(),
        ..._audit(_randomMoment()),
        'habit_id': h,
        'tag_id': tag,
        'tag_order': 0,
      });
    }
    for (var i = 0; i < 2000; i++) {
      final occurred = _randomMoment();
      _add('habit_time_record_table', {
        'id': g.id(),
        ..._audit(occurred),
        'habit_id': g.pick(habitIds),
        'duration': g.intIn(60, 3600),
        'occurred_at': occurred,
        'is_estimated': g.chance(0.2) ? 1 : 0,
      });
    }

    // Settings and paired devices
    for (var i = 0; i < 20; i++) {
      _add('setting_table', {
        'id': g.id(),
        ..._audit(_sec(start) + i),
        'key': 'FIXTURE_SETTING_${i.toString().padLeft(2, '0')}',
        'value': '${g.intIn(0, 100)}',
        'value_type': 1,
      });
    }
    final localDevice = g.id();
    for (var i = 0; i < 2; i++) {
      _add('sync_device_table', {
        'id': g.id(),
        ..._audit(_sec(start) + i * 86400, modified: _sec(end)),
        'from_ip': '192.168.1.10',
        'to_ip': '192.168.1.${20 + i}',
        'from_device_id': localDevice,
        'to_device_id': g.id(),
        'name': 'Fixture device $i',
        'last_sync_date': _sec(end),
      });
    }
    return rows;
  }
}

/// Text lengths for [largeRealisticFixture] (characters, not bytes; ~8 % of the vocabulary is non-ASCII, so UTF-8
/// bytes are slightly higher). Rationale: `large_usage` uses 2-12 word placeholders (task titles ~30 chars,
/// descriptions ~70 chars in 30 % of tasks, note bodies ~250 chars), which is small next to what a multi-year
/// user writes; the row count and structure stay the same so only the text weight changes.
/// - task title: uniform 20-80; description in 40 % of tasks, log-uniform 50-1,500 (median ~270);
/// - note title: uniform 10-60; note body: log-uniform 200-8,000 (median ~1,260), plus a 3 % tail log-uniform
///   8,000-32,000 (long notes spill into overflow pages);
/// - habit name: uniform 10-40; habit description in 70 % of habits, log-uniform 20-400 (else '');
/// - tag name: uniform 3-20; task status name: uniform 4-24;
/// - app usage: name (package/process) uniform 5-60, display name uniform 5-60;
/// - app-usage rule descriptions: uniform 10-120.
/// Settings, time records, habit records and links have no free text and are unchanged.
class _RealisticText {
  _RealisticText(int seed) : rnd = Random(seed ^ 0x7E47C0DE);

  final Random rnd;

  static const _vocabulary = [
    'the', 'and', 'for', 'with', 'from', 'about', 'after', 'before', 'meeting', 'project', 'review', 'draft', //
    'follow', 'up', 'client', 'budget', 'report', 'weekly', 'monthly', 'quarterly', 'invoice', 'deadline', //
    'groceries', 'dentist', 'appointment', 'workout', 'running', 'reading', 'chapter', 'book', 'notes', 'idea', //
    'research', 'compare', 'options', 'decide', 'schedule', 'call', 'email', 'reply', 'prepare', 'presentation', //
    'slides', 'refactor', 'database', 'migration', 'backup', 'release', 'version', 'feature', 'bug', 'fix', //
    'test', 'deploy', 'server', 'kitchen', 'garden', 'repair', 'renew', 'insurance', 'passport', 'travel', //
    'flight', 'hotel', 'booking', 'birthday', 'gift', 'family', 'weekend', 'morning', 'evening', 'tomorrow', //
    'important', 'maybe', 'later', 'remember', 'check', 'update', 'organize', 'clean', 'write', 'plan', 'learn', //
    'practice', 'language', 'lesson', 'course', 'exam', 'homework', 'summary', 'outline', 'question', 'answer', //
    'because', 'should', 'could', 'would', 'probably', 'already', 'still', 'again', 'first', 'second', 'third', //
    'toplantı', 'görüşme', 'çalışma', 'ödev', 'alışveriş', 'über', 'café', 'naïve', 'résumé', 'señal', //
  ];
  static final List<String> _asciiVocabulary = [
    for (final w in _vocabulary)
      if (w.codeUnits.every((c) => c < 128)) w
  ];

  bool chance(double probability) => rnd.nextDouble() < probability;
  int uniform(int min, int maxInclusive) => min + rnd.nextInt(maxInclusive - min + 1);
  int logUniform(int min, int max) => (min * pow(max / min, rnd.nextDouble())).round().clamp(min, max);

  String phrase(int minLength, int maxLength) => _fill(uniform(minLength, maxLength), sentences: false);
  String? taskDescription() => chance(0.4) ? _fill(logUniform(50, 1500), sentences: true) : null;
  String noteBody() => _fill(chance(0.03) ? logUniform(8000, 32000) : logUniform(200, 8000), sentences: true);
  String habitDescription() => chance(0.7) ? _fill(logUniform(20, 400), sentences: true) : '';

  String packageName(int minLength, int maxLength) {
    final length = uniform(minLength, maxLength);
    final b = StringBuffer();
    while (b.length < length) {
      if (b.isNotEmpty) b.write('.');
      b.write(_asciiVocabulary[rnd.nextInt(_asciiVocabulary.length)]);
    }
    var s = b.toString().substring(0, length);
    if (s.endsWith('.')) s = '${s.substring(0, length - 1)}x';
    return s;
  }

  /// Words up to exactly [length] characters. With [sentences]: capitalized sentences of 6-18 words and paragraph
  /// breaks every 3-6 sentences, some paragraphs as `- ` bullet lists (markdown-like note bodies).
  String _fill(int length, {required bool sentences}) {
    final b = StringBuffer();
    var wordsLeft = uniform(6, 18);
    var sentencesLeft = uniform(3, 6);
    var startOfSentence = true;
    var bullets = sentences && chance(0.15);
    while (b.length < length) {
      var word = _vocabulary[rnd.nextInt(_vocabulary.length)];
      if (startOfSentence) {
        if (bullets) b.write('- ');
        word = '${word[0].toUpperCase()}${word.substring(1)}';
        startOfSentence = false;
      }
      b.write(word);
      if (!sentences) {
        b.write(' ');
        continue;
      }
      if (--wordsLeft > 0) {
        b.write(' ');
        continue;
      }
      wordsLeft = uniform(6, 18);
      startOfSentence = true;
      if (--sentencesLeft > 0) {
        b.write(bullets ? '\n' : '. ');
        continue;
      }
      sentencesLeft = uniform(3, 6);
      b.write(bullets ? '\n\n' : '.\n\n');
      bullets = chance(0.15);
    }
    var s = b.toString().substring(0, length);
    if (s.endsWith(' ') || s.endsWith('\n')) s = '${s.substring(0, length - 1)}.';
    return s;
  }
}

// ---------------------------------------------------------------------------
// duplicates / duplicates_shuffled
// ---------------------------------------------------------------------------

/// FR-030 rule names used in the manifest.
abstract final class DuplicateRule {
  static const habitRecordDay = 'habit_record_day';
  static const settingKey = 'setting_key';
  static const builtInTaskStatus = 'builtin_task_status';
  static const recurringOccurrence = 'recurring_occurrence';
  static const taskTag = 'task_tag';
  static const habitTag = 'habit_tag';
  static const noteTag = 'note_tag';
  static const appUsageTag = 'app_usage_tag';
  static const tagTag = 'tag_tag';
  static const syncDevice = 'sync_device';

  static const all = [
    habitRecordDay,
    settingKey,
    builtInTaskStatus,
    recurringOccurrence,
    taskTag,
    habitTag,
    noteTag,
    appUsageTag,
    tagTag,
    syncDevice,
  ];
}

/// Columns that reference an id of the given table (dependents of a group).
const Map<String, List<(String, String)>> _referencingColumns = {
  'task_table': [
    ('task_table', 'parent_task_id'),
    ('task_table', 'recurrence_parent_id'),
    ('task_tag_table', 'task_id'),
    ('task_time_record_table', 'task_id'),
  ],
  'task_status_table': [('task_table', 'status_id')],
};

class _DuplicatesBuilder {
  _DuplicatesBuilder(this.seed) : g = _Gen(seed);

  final int seed;
  final _Gen g;
  final List<_Row> rows = [];
  final Map<String, _Group> _groups = {};
  final Map<String, _Group> _mustNotMerge = {};
  final List<Map<String, Object?>> _habits = [];

  static final DateTime base = DateTime.utc(2025, 3, 1);
  int _day(int index, {int hour = 12, int minute = 0}) => _sec(base) + index * 86400 + hour * 3600 + minute * 60;

  _Row _add(String table, Map<String, Object?> data) {
    final row = _Row(table, data);
    rows.add(row);
    return row;
  }

  void _group(String rule, String table, String key, _Row row) {
    final group = _groups.putIfAbsent('$rule|$key', () => _Group(rule, table, key));
    group.rows.add(row);
  }

  // Tag links ---------------------------------------------------------------

  _Row _link(String table, String rule, String itemColumn, String itemId, String tagId, {int? deleted, int? day}) {
    final created = _day(day ?? 0, hour: 8, minute: g.intIn(0, 59));
    final row = _add(table, {
      'id': g.id(),
      ..._audit(created, deleted: deleted),
      itemColumn: itemId,
      'tag_id': tagId,
      if (table != 'tag_tag_table') 'tag_order': 0,
    });
    _group(rule, table, '$tagId|$itemId', row);
    return row;
  }

  _Row _taskTag(String taskId, String tagId, {int? deleted}) =>
      _link('task_tag_table', DuplicateRule.taskTag, 'task_id', taskId, tagId, deleted: deleted);

  _Row _timeRecord(String taskId, int day, {int? deleted}) {
    final created = _day(day, hour: 15, minute: g.intIn(0, 59));
    return _add('task_time_record_table', {
      'id': g.id(),
      'task_id': taskId,
      'duration': g.intIn(5, 90) * 60,
      ..._audit(created, deleted: deleted),
    });
  }

  // Tasks -------------------------------------------------------------------

  var _taskOrder = 0;
  _Row _task(
    String title, {
    String statusId = builtInTodoStatusId,
    String? parent,
    int? planned,
    String? recurrenceParent,
    int recurrenceType = 0,
    int? deleted,
    int? modified,
  }) {
    final created = (planned ?? _day(0, hour: 7)) - 86400 + g.intIn(0, 3600);
    return _add('task_table', {
      'id': g.id(),
      'parent_task_id': parent,
      'title': title,
      'description': g.words(5),
      'priority': g.intIn(0, 3),
      'planned_date': planned,
      'deadline_date': null,
      'estimated_time': 30,
      'completed_at': statusId == builtInDoneStatusId ? created + 7200 : null,
      'status_id': statusId,
      ..._audit(created, modified: modified, deleted: deleted),
      'order': _Gen.rank(_taskOrder++),
      'planned_date_reminder_time': 0,
      'deadline_date_reminder_time': 0,
      'recurrence_type': recurrenceType,
      'recurrence_interval': recurrenceType == 0 ? null : 1,
      'recurrence_days_string': null,
      'recurrence_start_date': recurrenceType == 0 ? null : planned,
      'recurrence_end_date': null,
      'recurrence_count': null,
      'recurrence_parent_id': recurrenceParent,
      'recurrence_configuration': null,
    });
  }

  _Row _occurrence(_Row root, int day, {int hour = 10, int? deleted, int? modified}) {
    final row = _task(root['title'] as String,
        planned: _day(day, hour: hour),
        recurrenceParent: root.id,
        deleted: deleted,
        modified: modified ?? _day(day, hour: 10, minute: g.intIn(0, 59)));
    _group(DuplicateRule.recurringOccurrence, 'task_table', '${root.id}|${_dayOf(row)}', row);
    return row;
  }

  String _dayOf(_Row task) => _utcDay(task['planned_date'] as int);

  // Build -------------------------------------------------------------------

  void build() {
    // Tags (t[0..7] live, one soft-deleted).
    final tags = <String>[];
    for (var i = 0; i < 8; i++) {
      final row = _add('tag_table', {
        'id': g.id(),
        ..._audit(_day(-30, hour: i)),
        'name': 'Fixture tag $i ${g.words(1)}',
        'color': g.color(),
        'is_archived': 0,
        'type': i % 3,
      });
      tags.add(row.id);
    }
    final deletedTag = _add('tag_table', {
      'id': g.id(),
      ..._audit(_day(-30, hour: 9), deleted: _day(-5)),
      'name': 'Fixture tag deleted',
      'color': g.color(),
      'is_archived': 0,
      'type': 0,
    }).id;

    // tag_tag: duplicate (t0 -> t1) x3 (one soft-deleted), single t2 -> t3.
    for (final deleted in [null, null, _day(2)]) {
      final row = _add('tag_tag_table', {
        'id': g.id(),
        ..._audit(_day(0, hour: 8, minute: g.intIn(0, 59)), deleted: deleted),
        'primary_tag_id': tags[0],
        'secondary_tag_id': tags[1],
      });
      _group(DuplicateRule.tagTag, 'tag_tag_table', '${tags[0]}|${tags[1]}', row);
    }
    final single = _add('tag_tag_table', {
      'id': g.id(),
      ..._audit(_day(0, hour: 8)),
      'primary_tag_id': tags[2],
      'secondary_tag_id': tags[3],
    });
    _group(DuplicateRule.tagTag, 'tag_tag_table', '${tags[2]}|${tags[3]}', single);

    _buildHabits(tags);
    _buildSettings();
    final statuses = _buildStatuses();
    _buildRecurring(tags);

    // Plain tasks: duplicate tag links, subtasks, soft-deleted task.
    final plain = _task('Plain task with duplicate tag links', planned: _day(1, hour: 11));
    _taskTag(plain.id, tags[0]);
    _taskTag(plain.id, tags[0]);
    _taskTag(plain.id, tags[0], deleted: _day(3));
    _taskTag(plain.id, tags[1]);
    _task('Subtask of plain task', parent: plain.id);
    final deletedTask = _task('Soft-deleted task', deleted: _day(4));
    _task('Subtask of soft-deleted task', parent: deletedTask.id, deleted: _day(4));
    _taskTag(deletedTask.id, deletedTag, deleted: _day(4));

    // Tasks pointing at each status row via status_id.
    for (final status in statuses) {
      for (var i = 0; i < 2; i++) {
        _task('Task in status ${status.$2} #$i', statusId: status.$1, planned: _day(i));
      }
    }

    _buildNotes(tags);
    _buildAppUsages(tags);
    _buildSyncDevices();
  }

  void _buildHabits(List<String> tags) {
    _Row habit(String name, {required int hasGoal, required int? dailyTarget}) {
      final row = _add('habit_table', {
        'id': g.id(),
        ..._audit(_day(-20, hour: _habits.length)),
        'type': 0,
        'name': name,
        'description': g.words(4),
        'estimated_time': 10,
        'archived_date': null,
        'has_reminder': 0,
        'reminder_days': '',
        'has_goal': hasGoal,
        'target_frequency': hasGoal == 1 ? 5 : 1,
        'period_days': 7,
        'daily_target': dailyTarget,
        'order': _Gen.rank(_habits.length),
      });
      _habits.add({
        'id': row.id,
        'name': name,
        'hasGoal': hasGoal == 1,
        'dailyTarget': dailyTarget,
        'effectiveDailyTarget': dailyTarget ?? 1,
      });
      return row;
    }

    final hA = habit('Target-1 habit (no goal, null target)', hasGoal: 0, dailyTarget: null);
    final hB = habit('Target-1 habit (goal, target 1)', hasGoal: 1, dailyTarget: 1);
    final hC = habit('Target-3 habit', hasGoal: 1, dailyTarget: 3);

    _Row record(_Row h, int day, {int status = 0, int? deleted, int minute = 0}) {
      final occurred = _day(day, minute: minute);
      final row = _add('habit_record_table', {
        'id': g.id(),
        ..._audit(occurred, deleted: deleted),
        'habit_id': h.id,
        'occurred_at': occurred,
        'status': status,
      });
      final key = '${h.id}|${_utcDay(occurred)}';
      if (h == hC) {
        _mustNotMerge
            .putIfAbsent(key, () => _Group('habit_record_multi_target', 'habit_record_table', key))
            .rows
            .add(row);
      } else {
        _group(DuplicateRule.habitRecordDay, 'habit_record_table', key, row);
      }
      return row;
    }

    // Occurrence times stay within 11:30-12:30 UTC, so the calendar day is the
    // same for any device offset between UTC-11 and UTC+11.
    record(hA, 1, minute: -20);
    record(hA, 1, minute: 25);
    record(hA, 2, minute: -10);
    record(hA, 2, minute: 5);
    record(hA, 2, minute: 15, deleted: _day(2, hour: 13));
    record(hA, 3, status: 0);
    record(hA, 3, status: 2, minute: 10);
    record(hA, 4);
    record(hB, 1, minute: -5);
    record(hB, 1, minute: 5);
    record(hB, 5);
    record(hB, 5, minute: 1, deleted: _day(5, hour: 14));
    record(hC, 1, minute: -15);
    record(hC, 1);
    record(hC, 1, minute: 15);
    record(hC, 2, minute: -5);
    record(hC, 2, minute: 5);
    record(hC, 3);

    _link('habit_tag_table', DuplicateRule.habitTag, 'habit_id', hA.id, tags[0]);
    _link('habit_tag_table', DuplicateRule.habitTag, 'habit_id', hA.id, tags[0]);
    _link('habit_tag_table', DuplicateRule.habitTag, 'habit_id', hB.id, tags[1]);
    _link('habit_tag_table', DuplicateRule.habitTag, 'habit_id', hC.id, tags[2]);
    _link('habit_tag_table', DuplicateRule.habitTag, 'habit_id', hC.id, tags[2], deleted: _day(3));

    for (final (h, day) in [(hA, 1), (hA, 2), (hC, 1), (hC, 2)]) {
      final occurred = _day(day, hour: 18);
      _add('habit_time_record_table', {
        'id': g.id(),
        ..._audit(occurred),
        'habit_id': h.id,
        'duration': 600,
        'occurred_at': occurred,
        'is_estimated': day == 2 ? 1 : 0,
      });
    }
  }

  void _buildSettings() {
    void setting(String key, String value, int valueType, {int? modified, int? deleted}) {
      final row = _add('setting_table', {
        'id': g.id(),
        ..._audit(_day(0, hour: 6, minute: g.intIn(0, 59)), modified: modified, deleted: deleted),
        'key': key,
        'value': value,
        'value_type': valueType,
      });
      _group(DuplicateRule.settingKey, 'setting_table', key, row);
    }

    // SettingValueType: string=0, int=1, double=2, bool=3, json=4.
    setting('WORK_TIME', '25', 1, modified: _day(1));
    setting('WORK_TIME', '50', 1, modified: _day(3));
    setting('WORK_TIME', '30', 1, modified: _day(2));
    setting('DEFAULT_PAGE', 'tasks', 0);
    setting('DEFAULT_PAGE', 'habits', 0, deleted: _day(1));
    setting('NOTIFICATIONS_ENABLED', 'true', 3);
    setting('NOTIFICATIONS_ENABLED', 'true', 3);
    setting('ONBOARDING_COMPLETED', 'true', 3);
  }

  /// Returns (id, label) of every status row.
  List<(String, String)> _buildStatuses() {
    final result = <(String, String)>[];
    void status(String id, String kind, {int? deleted, int? modified, bool builtIn = true, String name = ''}) {
      final done = kind == 'done';
      final row = _add('task_status_table', {
        'id': id,
        ..._audit(_day(-40, hour: result.length), modified: modified, deleted: deleted),
        'name': name,
        'color': done ? '4CAF50' : '9E9E9E',
        'order': done ? 'V' : 'U',
        'is_built_in': builtIn ? 1 : 0,
        'is_done_status': done ? 1 : 0,
      });
      if (builtIn) _group(DuplicateRule.builtInTaskStatus, 'task_status_table', kind, row);
      result.add((id, builtIn ? '$kind ${result.length}' : name));
    }

    status(builtInTodoStatusId, 'todo');
    status(builtInDoneStatusId, 'done');
    status(g.id(), 'todo', modified: _day(1));
    status(g.id(), 'done');
    status(g.id(), 'todo', deleted: _day(2));
    status(g.id(), 'todo', builtIn: false, name: 'In review');
    return result;
  }

  void _buildRecurring(List<String> tags) {
    // Series 1 (daily). Root planned on day 1; an occurrence also on day 1
    // duplicates the root itself (key = root id + day).
    final root = _task('Daily recurring series', planned: _day(1, hour: 10), recurrenceType: 1);
    _group(DuplicateRule.recurringOccurrence, 'task_table', '${root.id}|${_dayOf(root)}', root);
    _occurrence(root, 1, hour: 12);

    // Day 2: Scenario 3.4. Two duplicates with different tags, a shared tag
    // (collapses after merge), time records, and subtasks (with a sub-subtask).
    final a = _occurrence(root, 2, hour: 10);
    final b = _occurrence(root, 2, hour: 13);
    _taskTag(a.id, tags[3]);
    _taskTag(b.id, tags[4]);
    _taskTag(a.id, tags[5]);
    _taskTag(b.id, tags[5]);
    _timeRecord(a.id, 2);
    _timeRecord(a.id, 2);
    _timeRecord(b.id, 2);
    final subA = _task('Subtask of occurrence A', parent: a.id);
    _task('Sub-subtask of occurrence A', parent: subA.id);
    _taskTag(subA.id, tags[6]);
    _task('Subtask of occurrence B', parent: b.id, statusId: builtInDoneStatusId);

    // Day 3: three duplicates, one soft-deleted with its links deleted too.
    final c1 = _occurrence(root, 3);
    final c2 = _occurrence(root, 3, hour: 11);
    final c3 = _occurrence(root, 3, hour: 12, deleted: _day(3, hour: 14));
    _taskTag(c1.id, tags[3]);
    _taskTag(c2.id, tags[6]);
    _taskTag(c3.id, tags[7], deleted: _day(3, hour: 14));
    _timeRecord(c2.id, 3);
    _timeRecord(c3.id, 3, deleted: _day(3, hour: 14));
    _task('Subtask of occurrence C2', parent: c2.id);

    // Day 4: single occurrence (not a duplicate).
    _occurrence(root, 4);

    // Series 2 (weekly), duplicate on day 7.
    final root2 = _task('Weekly recurring series', planned: _day(0, hour: 11), recurrenceType: 3);
    _group(DuplicateRule.recurringOccurrence, 'task_table', '${root2.id}|${_dayOf(root2)}', root2);
    final w1 = _occurrence(root2, 7, hour: 11);
    final w2 = _occurrence(root2, 7, hour: 11);
    _taskTag(w1.id, tags[0]);
    _timeRecord(w2.id, 7);
  }

  void _buildNotes(List<String> tags) {
    _Row note(String title, {int? deleted}) => _add('note_table', {
          'id': g.id(),
          'title': title,
          'content': g.words(20),
          'order': _Gen.rank(rows.where((r) => r.table == 'note_table').length),
          ..._audit(_day(0, hour: 5), modified: _day(1, hour: 5), deleted: deleted),
        });

    final n1 = note('Note with duplicate tag links');
    final n2 = note('Note with one tag');
    final n3 = note('Soft-deleted note', deleted: _day(2));
    _link('note_tag_table', DuplicateRule.noteTag, 'note_id', n1.id, tags[1]);
    _link('note_tag_table', DuplicateRule.noteTag, 'note_id', n1.id, tags[1]);
    _link('note_tag_table', DuplicateRule.noteTag, 'note_id', n2.id, tags[2]);
    _link('note_tag_table', DuplicateRule.noteTag, 'note_id', n3.id, tags[2], deleted: _day(2));
  }

  void _buildAppUsages(List<String> tags) {
    _Row app(String name) => _add('app_usage_table', {
          'id': g.id(),
          ..._audit(_day(-10)),
          'name': name,
          'display_name': name.split('.').last,
          'color': g.color(),
          'device_name': 'fixture-desktop',
        });

    final a1 = app('org.example.browser');
    final a2 = app('org.example.editor');
    _link('app_usage_tag_table', DuplicateRule.appUsageTag, 'app_usage_id', a1.id, tags[2]);
    _link('app_usage_tag_table', DuplicateRule.appUsageTag, 'app_usage_id', a1.id, tags[2]);
    _link('app_usage_tag_table', DuplicateRule.appUsageTag, 'app_usage_id', a2.id, tags[3]);
    for (var i = 0; i < 4; i++) {
      final usage = _day(i, hour: 10 + i);
      _add('app_usage_time_record_table', {
        'id': g.id(),
        'app_usage_id': i.isEven ? a1.id : a2.id,
        'duration': 900,
        'usage_date': usage,
        ..._audit(usage + 900, deleted: i == 3 ? usage + 1000 : null),
      });
    }
  }

  void _buildSyncDevices() {
    final local = g.id();
    final remote1 = g.id();
    final remote2 = g.id();
    final remote3 = g.id();
    void device(String from, String to, String fromIp, String toIp, {int? deleted}) {
      final row = _add('sync_device_table', {
        'id': g.id(),
        ..._audit(_day(0, hour: 4, minute: g.intIn(0, 59)), modified: _day(6), deleted: deleted),
        'from_ip': fromIp,
        'to_ip': toIp,
        'from_device_id': from,
        'to_device_id': to,
        'name': 'Fixture device',
        'last_sync_date': _day(6),
      });
      final pair = [from, to]..sort();
      _group(DuplicateRule.syncDevice, 'sync_device_table', pair.join('|'), row);
    }

    // Same pair three times (IP changed, and once recorded from the other side).
    device(local, remote1, '192.168.1.10', '192.168.1.20');
    device(local, remote1, '192.168.1.11', '192.168.1.21');
    device(remote1, local, '192.168.1.21', '192.168.1.11');
    device(local, remote2, '192.168.1.10', '192.168.1.30');
    device(local, remote2, '192.168.1.10', '192.168.1.31', deleted: _day(5));
    device(local, remote3, '192.168.1.10', '192.168.1.40');
  }

  // Manifest ----------------------------------------------------------------

  Map<String, Object?> manifest(String fixtureName) {
    final byTableColumn = <String, List<_Row>>{};
    for (final row in rows) {
      byTableColumn.putIfAbsent(row.table, () => []).add(row);
    }

    Map<String, Object?> groupJson(_Group group, {required bool withDependents}) {
      final ids = group.rows.map((r) => r.id).toList()..sort();
      final liveIds = group.rows.where((r) => r['deleted_date'] == null).map((r) => r.id).toList()..sort();
      final json = <String, Object?>{
        'rule': group.rule,
        'table': group.table,
        'key': group.key,
        'ids': ids,
        'liveIds': liveIds,
      };
      if (withDependents) {
        final idSet = ids.toSet();
        final dependents = <Map<String, Object?>>[];
        for (final (table, column) in _referencingColumns[group.table] ?? const <(String, String)>[]) {
          for (final row in byTableColumn[table] ?? const <_Row>[]) {
            final ref = row[column];
            if (ref is String && idSet.contains(ref)) {
              dependents.add({
                'table': table,
                'id': row.id,
                'column': column,
                'references': ref,
                'live': row['deleted_date'] == null,
              });
            }
          }
        }
        dependents.sort((x, y) {
          final c = '${x['table']}|${x['column']}|${x['id']}'.compareTo('${y['table']}|${y['column']}|${y['id']}');
          return c;
        });
        json['dependents'] = dependents;
      }
      return json;
    }

    int compareGroups(_Group x, _Group y) {
      final c = x.rule.compareTo(y.rule);
      return c != 0 ? c : x.key.compareTo(y.key);
    }

    final duplicateGroups = _groups.values.where((grp) => grp.rows.length > 1).toList()..sort(compareGroups);
    final multiTarget = _mustNotMerge.values.where((grp) => grp.rows.length > 1).toList()..sort(compareGroups);

    final rowCounts = <String, int>{for (final t in fixtureTables) t: 0};
    final liveRowCounts = <String, int>{for (final t in fixtureTables) t: 0};
    for (final row in rows) {
      rowCounts[row.table] = rowCounts[row.table]! + 1;
      if (row['deleted_date'] == null) liveRowCounts[row.table] = liveRowCounts[row.table]! + 1;
    }

    return {
      'fixture': fixtureName,
      'logicalContent': duplicatesFixture,
      'seed': seed,
      'schemaVersion': fixtureSchemaVersion,
      'format': 1,
      'notes': [
        'Dates are unix seconds (UTC). Calendar days in keys are UTC days; habit record occurred_at and '
            'occurrence planned_date times (10:00-13:00 UTC) keep the day stable for offsets between UTC-10 and UTC+10.',
        'duplicateGroups lists every identity with more than one row, including soft-deleted rows (ids) '
            'and the live subset (liveIds).',
        'Keys: habit_record_day = habitId|yyyy-MM-dd(occurred_at); setting_key = key; '
            'builtin_task_status = todo|done (is_done_status); recurring_occurrence = '
            '(recurrence_parent_id ?? id)|yyyy-MM-dd(planned_date); tag links = tagId|itemId '
            '(tag_tag: primary_tag_id|secondary_tag_id); sync_device = sorted(from_device_id, to_device_id).',
        'multiTargetGroups are completions of habits with effective daily target > 1 on the same day; '
            'they must NOT be merged.',
        'dependents lists rows whose FK column points at a member of the group.',
      ],
      'rules': DuplicateRule.all,
      'habits': _habits,
      'duplicateGroups': [for (final grp in duplicateGroups) groupJson(grp, withDependents: true)],
      'multiTargetGroups': [for (final grp in multiTarget) groupJson(grp, withDependents: false)],
      'rowCounts': rowCounts,
      'liveRowCounts': liveRowCounts,
    };
  }
}

class _Group {
  _Group(this.rule, this.table, this.key);

  final String rule;
  final String table;
  final String key;
  final List<_Row> rows = [];
}
