// Shared measurement code of the T28 performance runs: the headless loopback
// test (test/performance_sync) and the two-device run (integration_test). It
// opens a `large_usage` fixture as a real sync device, samples database actions
// while a session runs, and prints a metrics table.
import 'dart:async';
import 'dart:io';

import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import '../fixtures/sync/fixture_builder.dart';
import '../infrastructure/persistence/sync/restore_test_support.dart';
import '../integration/sync_acceptance/support2/lab.dart';

const Duration sampleInterval = Duration(milliseconds: 100);
const Duration sc013ActionLimit = Duration(seconds: 1);
const Duration sc012ReauthorChunkLimit = Duration(seconds: 2);
const int _percentile95 = 95;
const String _probeNoteId = 'perf-probe-note';
const String _listOpenSql = 'SELECT id, title, created_date FROM task_table '
    'WHERE deleted_date IS NULL ORDER BY created_date DESC LIMIT 50';

/// One line of the metrics table. [limit] is the soft gate, when there is one.
class PerfMetric {
  final String name;
  final String value;
  final String? limit;
  final bool? met;

  const PerfMetric(this.name, this.value, {this.limit, this.met});
}

/// The metrics of one run, printed and written as a markdown table.
class PerfReport {
  final String title;
  final List<PerfMetric> metrics = [];

  PerfReport(this.title);

  void add(String name, String value, {String? limit, bool? met}) =>
      metrics.add(PerfMetric(name, value, limit: limit, met: met));

  /// Adds a time metric gated by [limit].
  void addTime(String name, Duration elapsed, {Duration? limit}) => add(
        name,
        formatSeconds(elapsed),
        limit: limit == null ? null : '<= ${formatSeconds(limit)}',
        met: limit == null ? null : elapsed <= limit,
      );

  List<PerfMetric> get unmet => metrics.where((metric) => metric.met == false).toList();

  String toMarkdown(String header) {
    final buffer = StringBuffer('# $title\n\n$header\n\n| Metric | Value | Gate | Met |\n|---|---|---|---|\n');
    for (final metric in metrics) {
      final met = metric.met == null ? '' : (metric.met! ? 'yes' : 'NO');
      buffer.writeln('| ${metric.name} | ${metric.value} | ${metric.limit ?? ''} | $met |');
    }
    return buffer.toString();
  }
}

String formatSeconds(Duration elapsed) => '${(elapsed.inMilliseconds / 1000).toStringAsFixed(2)} s';

String formatMegabytes(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB';

/// Times `list open` (the 50 newest open tasks) and `edit` (one note title)
/// on [databases] while a sync runs.
class ActionLatencySampler {
  final List<AppDatabase> databases;
  final List<Duration> listOpen = [];
  final List<Duration> edit = [];
  Timer? _timer;
  bool _sampling = false;
  int _editCount = 0;

  ActionLatencySampler(this.databases);

  Future<void> start() async {
    for (final database in databases) {
      await database.customStatement(
        "INSERT OR IGNORE INTO note_table (id, created_date, title, content) VALUES ('$_probeNoteId', 1, 'probe', 'body')",
      );
    }
    _timer = Timer.periodic(sampleInterval, (_) => _sampleOnce());
  }

  Future<void> stop() async {
    _timer?.cancel();
    while (_sampling) {
      await Future<void>.delayed(sampleInterval);
    }
  }

  Duration get worst => [...listOpen, ...edit].fold(Duration.zero, (a, b) => a > b ? a : b);

  int get sampleCount => listOpen.length + edit.length;

  Duration percentile95(List<Duration> samples) {
    if (samples.isEmpty) return Duration.zero;
    final sorted = [...samples]..sort();
    return sorted[((sorted.length - 1) * _percentile95 / 100).floor()];
  }

  Future<void> _sampleOnce() async {
    if (_sampling) return;
    _sampling = true;
    try {
      for (final database in databases) {
        listOpen.add(await _timed(() => database.customSelect(_listOpenSql).get()));
        edit.add(await _timed(() => database.customStatement(
              'UPDATE note_table SET title = ? WHERE id = ?',
              ['probe ${_editCount++}', _probeNoteId],
            )));
      }
    } finally {
      _sampling = false;
    }
  }

  Future<Duration> _timed(Future<void> Function() action) async {
    final stopwatch = Stopwatch()..start();
    await action();
    return stopwatch.elapsed;
  }

  void addTo(PerfReport report, String phase) {
    report.add('$phase: samples', '$sampleCount (every ${sampleInterval.inMilliseconds} ms)');
    report.add('$phase: list-open p95', formatSeconds(percentile95(listOpen)));
    report.add('$phase: edit p95', formatSeconds(percentile95(edit)));
    report.add('$phase: worst action', formatSeconds(worst),
        limit: '< ${formatSeconds(sc013ActionLimit)}', met: worst < sc013ActionLimit);
  }
}

/// What the deleted rows add to a first sync (plan U10), counted on [database].
class TombstoneStats {
  final int clockCells;
  final int tombstoneCells;
  final int cellsOfDeletedRows;
  final int softDeletedRows;

  const TombstoneStats(this.clockCells, this.tombstoneCells, this.cellsOfDeletedRows, this.softDeletedRows);

  double get cellShare => clockCells == 0 ? 0 : cellsOfDeletedRows / clockCells;

  static Future<TombstoneStats> read(AppDatabase database) async {
    Future<int> count(String sql) async => (await database.customSelect(sql).getSingle()).data.values.first! as int;
    var softDeleted = 0;
    for (final table in fixtureTables) {
      final hasColumn = await count("SELECT COUNT(*) FROM pragma_table_info('$table') WHERE name = 'deleted_date'");
      if (hasColumn > 0) softDeleted += await count('SELECT COUNT(*) FROM "$table" WHERE deleted_date IS NOT NULL');
    }
    return TombstoneStats(
      await count('SELECT COUNT(*) FROM sync_clock'),
      await count('SELECT COUNT(*) FROM sync_clock WHERE tomb_value IS NOT NULL'),
      await count('SELECT COUNT(*) FROM sync_clock WHERE key / 256 IN '
          '(SELECT key / 256 FROM sync_clock WHERE tomb_value IS NOT NULL)'),
      softDeleted,
    );
  }

  /// The share is a proportional estimate: cells of deleted rows over all cells,
  /// applied to the measured time and bytes of the first sync.
  void addTo(PerfReport report, {required Duration firstSyncTime, required int firstSyncBytes}) {
    report.add('tombstones: soft-deleted rows', '$softDeletedRows');
    report.add('tombstones: tombstone cells', '$tombstoneCells of $clockCells clock cells');
    report.add('tombstones: cells of deleted rows', '$cellsOfDeletedRows (${(cellShare * 100).toStringAsFixed(2)} %)');
    report.add('tombstones: est. share of first-sync time', formatSeconds(firstSyncTime * cellShare));
    report.add('tombstones: est. share of first-sync bytes', formatMegabytes((firstSyncBytes * cellShare).round()));
  }
}

/// Builds `large_usage` once and returns its v37 database file.
Future<File> buildLargeUsageFixture(Directory out) async {
  await buildFixture(largeUsageFixture, seed: defaultFixtureSeed, out: out);
  return File(fixtureDatabasePath(out, largeUsageFixture));
}

/// Opens [fixture] (a copy) as the database of a new lab device, the way the
/// app starts: v37 -> v38 migration, startup identity check, then the
/// dedupe/bootstrap job. Returns the device and the job time.
Future<({LabDevice device, Duration upgradeTime})> openFixtureDevice(
  Lab lab,
  String name,
  File fixture,
) async {
  final device = await lab.add(name);
  await device.security.keyStore.deleteAll();
  final copy = fixture.copySync('${lab.scratch.path}/$name-fixture.sqlite');
  await device.security.openDatabaseFile(copy.path);
  device.rebuild();
  final action = await device.security.startup.run(deviceName: name, databaseCreatedThisLaunch: true);
  if (action != SyncStartupAction.freshIdentity) {
    throw StateError('Fixture device $name did not get a fresh identity: $action');
  }
  final stopwatch = Stopwatch()..start();
  if (!await SyncUpgradeJob(device.appDatabase).runChunks()) {
    throw StateError('The upgrade job of $name did not finish');
  }
  return (device: device, upgradeTime: stopwatch.elapsed);
}
