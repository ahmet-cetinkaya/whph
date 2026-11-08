// S3 spike (plan T6): scale and performance of the per-cell sync design on the synthetic multi-year `large_usage`
// fixture. Test-only spike code; prints `[S3]`-prefixed metrics and stores them in `binding.reportData['s3']`.
//
// Measures:
//   (a) clock rows and DB growth after the D6 bootstrap (raw and after VACUUM, and with the D7 manifests stored)
//       for the selected physical clock shape; with S3_SURVEY also for every shape and policy variant of the PA-1
//       re-run on both survey fixtures (growth only),
//   (b) chunked D17 job time (dedupe + bootstrap) and max chunk,
//   (c) manifest-based hash/sign/encrypt and verify/decrypt throughput on fixture-derived values plus exact wire
//       sizes, and the S4 benchmark for reference,
//   (d) apply throughput for 1,000- and 500-change batches in a worker isolate (one transaction per batch, a
//       SAVEPOINT per item, `apply_mode = 1`),
//   (e) main-isolate frame times, event-loop lag and the latency of opening the task list and editing a task every
//       ~250 ms during the apply, for two designs: the apply on the SAME drift connection as the UI (queued behind
//       each batch transaction) and on a SEPARATE connection (WAL readers never block; writers wait for the lock).
//
// Run:
//   cd src && fvm flutter test integration_test/sync_scale_spike_test.dart -d linux
//   cd src && fvm flutter drive --profile --driver=<driver> --target=integration_test/sync_scale_spike_test.dart -d <id>
// Options (dart-define): S3_FIXTURE (large_usage | large_realistic), S3_SHAPE (v2_packed | v1_intern | baseline |
// d1_literal), S3_SURVEY (true), S3_SURVEY_FIXTURES (large_usage,large_realistic), S3_APPLY_N (200000),
// S3_APPLY_500_N (50000), S3_APPLY_SEPARATE_N (50000), S3_GROUPS_PER_CHUNK (250), S3_BENCH_N (5000).
// Every spike connection uses drift `cachePreparedStatements: true` (plan PA-3).
import 'dart:async';
import 'dart:developer' show Timeline;
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/task_query_builder.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sqlite_connection_setup.dart';
import 'package:whph_sync_core/spike.dart';

import '../test/drift/app_database/generated/schema_v37.dart';
import '../test/fixtures/sync/fixture_builder.dart' show buildFixture, defaultFixtureSeed, fixtureNames;
import '../test/infrastructure/persistence/sync/dedupe_spike.dart';
import '../test/infrastructure/persistence/sync/scale_spike_apply.dart';

const int _applyN = int.fromEnvironment('S3_APPLY_N', defaultValue: 200000);
const int _apply500N = int.fromEnvironment('S3_APPLY_500_N', defaultValue: 50000);
const int _applySeparateN = int.fromEnvironment('S3_APPLY_SEPARATE_N', defaultValue: 50000);
const int _groupsPerChunk = int.fromEnvironment('S3_GROUPS_PER_CHUNK', defaultValue: 250);
const int _benchN = int.fromEnvironment('S3_BENCH_N', defaultValue: 5000);
const String _fixture = String.fromEnvironment('S3_FIXTURE', defaultValue: 'large_usage');
const String _shapeLabel = String.fromEnvironment('S3_SHAPE', defaultValue: 'v2_packed');
const bool _survey = bool.fromEnvironment('S3_SURVEY', defaultValue: true);
const String _surveyFixtures =
    String.fromEnvironment('S3_SURVEY_FIXTURES', defaultValue: 'large_usage,large_realistic');

/// 20 Mbit/s in bytes per second.
const double _linkBytesPerSecond = 20e6 / 8;

final Map<String, Object?> _report = {};

void _log(String key, Object? value) {
  _report[key] = value is Map ? value.map((k, v) => MapEntry('$k', v)) : value;
  final text = value is double ? value.toStringAsFixed(3) : '$value';
  // ignore: avoid_print
  print('[S3] $key=$text');
}

String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(2);

// ---------------------------------------------------------------------------
// Main-isolate instrumentation
// ---------------------------------------------------------------------------

class _Frame {
  _Frame(this.vsyncUs, this.buildUs, this.rasterUs, this.totalUs);
  final int vsyncUs;
  final int buildUs;
  final int rasterUs;
  final int totalUs;
}

class _Instruments {
  final List<_Frame> frames = [];
  final List<(int, int)> lags = []; // (Timeline µs, lag µs)
  final Map<String, (int, int)> windows = {};
  Timer? _timer;
  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      frames.add(_Frame(t.timestampInMicroseconds(FramePhase.vsyncStart), t.buildDuration.inMicroseconds,
          t.rasterDuration.inMicroseconds, t.totalSpan.inMicroseconds));
    }
  }

  void start() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    final sw = Stopwatch()..start();
    var last = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = sw.elapsedMicroseconds;
      lags.add((Timeline.now, (now - last - 16000).clamp(0, 1 << 40)));
      last = now;
    });
  }

  void stop() {
    _timer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void open(String name) => windows[name] = (Timeline.now, 1 << 62);
  void close(String name) => windows[name] = (windows[name]!.$1, Timeline.now);

  void report(String name) {
    final (from, to) = windows[name]!;
    final inWindow = frames.where((f) => f.vsyncUs >= from && f.vsyncUs <= to).toList();
    final seconds = (to - from) / 1e6;
    _log('$name.window_s', seconds);
    _log('$name.frames', inWindow.length);
    _log('$name.fps', inWindow.length / seconds);
    _log('$name.frame_build_ms', formatSummary(summarize([for (final f in inWindow) f.buildUs / 1000])));
    _log('$name.frame_raster_ms', formatSummary(summarize([for (final f in inWindow) f.rasterUs / 1000])));
    _log('$name.frame_total_span_ms', formatSummary(summarize([for (final f in inWindow) f.totalUs / 1000])));
    _log('$name.frames_over_16ms', inWindow.where((f) => f.buildUs + f.rasterUs > 16667).length);
    _log('$name.frames_over_100ms', inWindow.where((f) => f.buildUs + f.rasterUs > 100000).length);
    final lag = [
      for (final (t, l) in lags)
        if (t >= from && t <= to) l / 1000
    ];
    _log('$name.event_loop_lag_ms', formatSummary(summarize(lag)));
  }
}

class _ScrollingProbe extends StatefulWidget {
  const _ScrollingProbe();

  @override
  State<_ScrollingProbe> createState() => _ScrollingProbeState();
}

class _ScrollingProbeState extends State<_ScrollingProbe> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..repeat(reverse: true);
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_scroll.hasClients) _scroll.jumpTo(_controller.value * _scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('S3 scale spike')),
          body: Column(children: [
            const LinearProgressIndicator(),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemCount: 3000,
                itemBuilder: (context, i) => ListTile(
                  leading: CircleAvatar(child: Text('${i % 100}')),
                  title: Text('Synthetic row $i'),
                  subtitle: const Text('Scrolling while the sync apply runs'),
                ),
              ),
            ),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------
// UI actions: open the task list, edit a task
// ---------------------------------------------------------------------------

class _ProbeResult {
  final List<double> listMs = [];
  final List<double> editMs = [];
  int listErrors = 0;
  int editFirstAttemptBusy = 0;
  int editBusyRetries = 0;
  int editErrors = 0;

  void report(String name) {
    _log('$name.open_list_ms', formatSummary(summarize(listMs)));
    _log('$name.edit_item_ms', formatSummary(summarize(editMs)));
    _log('$name.open_list_errors', listErrors);
    _log('$name.edit_first_attempt_busy', editFirstAttemptBusy);
    _log('$name.edit_busy_retries', editBusyRetries);
    _log('$name.edit_errors', editErrors);
  }
}

final String _taskListWhere = ' WHERE task_table.parent_task_id IS NULL AND task_table.deleted_date IS NULL '
    'AND ${TaskQueryBuilder().buildArchivedTagVisibilityCondition()}';

/// Page 0 of the task list as `DriftTaskRepository.getListWithOptions` issues it (select with total duration,
/// then the count), sorted by the custom order.
Future<void> _openTaskList(DatabaseAtV37 db) async {
  await db.customSelect(
    '${TaskQueryBuilder.selectClauseWithDuration}$_taskListWhere ORDER BY task_table."order" ASC LIMIT ? OFFSET ?',
    variables: [Variable<int>(20), Variable<int>(0)],
  ).get();
  await db.customSelect('SELECT COUNT(*) AS count FROM task_table$_taskListWhere').get();
}

/// Issues "open list" and "edit item" alternately every ~250 ms (sequentially, like a user) while [active].
/// With [retryBusy] an edit that fails with SQLITE_BUSY is retried every 5 ms (≤ 10 s) at the Dart level, standing
/// in for busy_timeout (which the profiler cuts to ~60 ms in debug/profile builds, see T3).
Future<_ProbeResult> _probe(DatabaseAtV37 db, List<String> taskIds, bool Function() active,
    {required bool retryBusy}) async {
  final result = _ProbeResult();
  var i = 0;
  while (active()) {
    final sw = Stopwatch()..start();
    if (i.isEven) {
      try {
        await _openTaskList(db);
        result.listMs.add(sw.elapsedMicroseconds / 1000);
      } catch (_) {
        result.listErrors++;
      }
    } else {
      final id = taskIds[(i ~/ 2) % taskIds.length];
      var attempt = 0;
      while (true) {
        try {
          await db.customStatement('UPDATE task_table SET title = ?, modified_date = ? WHERE id = ?',
              ['S3 edit $i', DateTime.now().millisecondsSinceEpoch ~/ 1000, id]);
          result.editMs.add(sw.elapsedMicroseconds / 1000);
          break;
        } catch (e) {
          final busy = isBusyError(e);
          if (busy && attempt == 0) result.editFirstAttemptBusy++;
          if (!busy || !retryBusy || sw.elapsed > const Duration(seconds: 10)) {
            result.editErrors++;
            break;
          }
          attempt++;
          result.editBusyRetries++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }
    }
    i++;
    final wait = 250 - sw.elapsedMilliseconds;
    if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
  }
  return result;
}

// ---------------------------------------------------------------------------
// Runs
// ---------------------------------------------------------------------------

Future<Map<String, Object?>> _applyRun(
  _Instruments instruments,
  DatabaseAtV37 db,
  String dbPath,
  List<String> taskIds,
  ScaleRunConfig cfg, {
  required bool separate,
}) async {
  final port = ReceivePort();
  final started = Completer<void>();
  final done = Completer<void>();
  port.listen((message) {
    final event = (message as Map)['event'];
    if (event == eventApplyStart && !started.isCompleted) started.complete();
    if (event == eventApplyDone && !done.isCompleted) done.complete();
  });
  final sw = Stopwatch()..start();
  final worker = separate
      ? spawnSeparateConnectionRun(dbPath, cfg, port.sendPort)
      : spawnSharedConnectionRun(db, cfg, port.sendPort);
  // A worker failure before applyStart must not hang the test.
  unawaited(worker.then((_) {}, onError: (Object _) {
    if (!started.isCompleted) started.complete();
    if (!done.isCompleted) done.complete();
  }));
  await started.future;
  _log('${cfg.label}.prepare_wall_ms', sw.elapsedMilliseconds);
  instruments.open(cfg.label);
  var active = true;
  final probe = _probe(db, taskIds, () => active, retryBusy: separate);
  await done.future;
  active = false;
  instruments.close(cfg.label);
  final probeResult = await probe;
  final metrics = await worker;
  port.close();
  for (final e in metrics.entries) {
    final v = e.value;
    _log('${cfg.label}.${e.key}', v is Map<String, num> ? formatSummary(v) : v);
  }
  probeResult.report(cfg.label);
  return metrics;
}

Future<void> _runSpike(_Instruments instruments) async {
  final base = await getTemporaryDirectory();
  final root = Directory('${base.path}/whph_s3_it');
  if (root.existsSync()) root.deleteSync(recursive: true);
  root.createSync(recursive: true);
  DatabaseAtV37? db;
  try {
    _log('platform', '${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    _log('build_mode', kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'));
    _log('cpus', Platform.numberOfProcessors);
    final shape = ScaleClockShape.byLabel(_shapeLabel);
    if (!fixtureNames.contains(_fixture)) throw ArgumentError.value(_fixture, 'S3_FIXTURE');
    _log(
        'config',
        'fixture=$_fixture shape=${shape.label} survey=$_survey survey_fixtures=$_surveyFixtures '
            'apply_n=$_applyN apply_500_n=$_apply500N apply_separate_n=$_applySeparateN '
            'groups_per_chunk=$_groupsPerChunk bench_n=$_benchN cache_prepared_statements=true');

    // ---- (a) PA-1 survey: growth of every shape and policy variant (deterministic; same on every platform) ------
    if (_survey) {
      final surveyDir = Directory('${root.path}/survey')..createSync();
      for (final name in _surveyFixtures.split(',').map((n) => n.trim()).where((n) => n.isNotEmpty)) {
        final fixture = await buildFixture(name, seed: defaultFixtureSeed, out: surveyDir);
        final variants = [
          for (final s in ScaleClockShape.values) (s, ScalePolicyVariant.d1),
          (shape, ScalePolicyVariant.settingRowLevel),
          (shape, ScalePolicyVariant.allRowLevel),
        ];
        for (final (s, policy) in variants) {
          final sw = Stopwatch()..start();
          final g = await measureShapeGrowth(
              fixture: fixture.database, shape: s, policy: policy, scratch: surveyDir, groupsPerChunk: _groupsPerChunk);
          final prefix = 'survey.$name.${s.label}.${policy.label}';
          for (final e in g.entries.where((e) => e.key != 'shape' && e.key != 'policy')) {
            _log('$prefix.${e.key}', e.value);
          }
          _log('$prefix.wall_ms', sw.elapsedMilliseconds);
        }
        fixture.database.deleteSync();
      }
    }

    final build = await buildFixture(_fixture, seed: defaultFixtureSeed, out: root);
    _log('fixture.rows', build.totalRows);
    _log('fixture.build_ms', build.elapsed.inMilliseconds);
    _log('fixture.file_bytes', build.database.lengthSync());
    _log('fixture.row_counts',
        build.rowCounts.entries.where((e) => e.value > 0).map((e) => '${e.key}:${e.value}').join(' '));

    // ---- (a)(b) selected shape: install, job, sizes -------------------------------------------------------------
    final primaryPath = '${root.path}/primary.sqlite';
    build.database.copySync(primaryPath);
    db = DatabaseAtV37(NativeDatabase.createInBackground(File(primaryPath),
        setup: configureSqliteConnection, cachePreparedStatements: true));
    final sqliteVersion = (await db.customSelect('SELECT sqlite_version() AS v').get()).single.data['v'];
    _log('sqlite_version', sqliteVersion);
    final pre = await measureDbSize(db, primaryPath, '${root.path}/vac.sqlite');
    _log('size.pre.raw_bytes', pre.rawBytes);
    _log('size.pre.vacuum_bytes', pre.vacuumBytes);

    await ScaleSpikeSchema.install(db, shape: shape, withTriggers: true);
    for (final sql in v38FkIndexStatements) {
      await db.customStatement(sql);
    }
    final timings = <ChunkTiming>[];
    final jobSw = Stopwatch()..start();
    final job = DedupeSpikeJob(db,
        nowMs: DateTime.now().millisecondsSinceEpoch,
        groupsPerChunk: _groupsPerChunk,
        onChunk: timings.add,
        bootstrapWriter: bootstrapWriterFor(shape));
    final jobResult = await job.run();
    jobSw.stop();
    final summary = ChunkTimingSummary(timings);
    _log('job.done', jobResult.done);
    _log('job.total_ms', jobSw.elapsedMilliseconds);
    for (final phase in [SpikeSyncSchema.phaseDedupe, SpikeSyncSchema.phaseBootstrap]) {
      final slow = summary.slowest(phase);
      _log('job.$phase.chunks', summary.count(phase));
      _log('job.$phase.units', summary.units(phase));
      _log('job.$phase.total_ms', summary.total(phase).inMilliseconds);
      _log('job.$phase.max_chunk_ms', slow == null ? 0 : slow.elapsed.inMicroseconds / 1000);
      _log(
          'job.$phase.chunk_ms',
          formatSummary(
              summarize([for (final t in timings.where((t) => t.phase == phase)) t.elapsed.inMicroseconds / 1000])));
    }
    final clockRows = (await db.customSelect('SELECT COUNT(*) AS n FROM sync_clock').get()).single.data['n'] as int;
    _log('clock.rows', clockRows);
    _log('clock.rows_per_table',
        (await clockRowsPerTable(db, shape)).entries.map((e) => '${e.key}:${e.value}').join(' '));
    if (shape.interned) {
      _log('clock.sync_row_rows',
          (await db.customSelect('SELECT COUNT(*) AS n FROM sync_row').get()).single.data['n'] as int);
    }
    for (final e in (await verifyShape(db, shape)).entries) {
      _log('verify.${e.key}', e.value);
    }
    _log('clock.rows_per_user_row', clockRows / build.totalRows);
    final post = await measureDbSize(db, primaryPath, '${root.path}/vac.sqlite');
    _log('size.post.main_bytes', post.mainBytes);
    _log('size.post.wal_bytes_after_checkpoint', post.walBytes);
    _log('size.post.vacuum_bytes', post.vacuumBytes);
    _log('growth.raw_ratio', post.rawBytes / pre.rawBytes);
    _log('growth.vacuum_ratio', post.vacuumBytes / pre.vacuumBytes);
    _log('growth.bytes_per_clock_row', (post.vacuumBytes - pre.vacuumBytes) / clockRows);
    final breakdown = await dbstatOfVacuumCopy(db, '${root.path}/vac.sqlite');
    _log(
        'size.post.dbstat_vacuum',
        breakdown == null
            ? 'unavailable'
            : syncObjectBytes(breakdown).entries.map((e) => '${e.key}:${_mb(e.value)}MiB').join(' '));
    // What-if for no-go fallback (i): every table row-level (`*` + `~` per row) instead of the D1 split.
    final allRowLevelCells = 2 * (build.totalRows - (build.rowCounts['sync_device_table'] ?? 0));
    _log('whatif.all_row_level.cells', allRowLevelCells);
    _log('whatif.all_row_level.est_vacuum_ratio',
        (pre.vacuumBytes + (post.vacuumBytes - pre.vacuumBytes) / clockRows * allRowLevelCells) / pre.vacuumBytes);

    final manifests = await addOwnManifestsForSize(db);
    final withManifests = await measureDbSize(db, primaryPath, '${root.path}/vac.sqlite');
    _log('size.with_manifests.manifests', manifests);
    _log('size.with_manifests.raw_bytes', withManifests.rawBytes);
    _log('size.with_manifests.vacuum_bytes', withManifests.vacuumBytes);
    _log('growth.with_manifests.raw_ratio', withManifests.rawBytes / pre.rawBytes);
    _log('growth.with_manifests.vacuum_ratio', withManifests.vacuumBytes / pre.vacuumBytes);

    // ---- (c) S4 benchmark for reference ---------------------------------------------------------------------
    if (_benchN > 0) {
      final bench = await Isolate.run(() => runCryptoBench(const CryptoBenchConfig(
          changes: _benchN, ed25519Ops: 50, hashOps: 5000, aeadSmallOps: 500, aeadLargeOps: 16)));
      for (final key in [
        'ed25519_sign_ops_per_s',
        'ed25519_verify_ops_per_s',
        'blake2b256_hashes_per_s',
        'xchacha20poly1305_encrypt_1kib_mb_per_s',
        'xchacha20poly1305_decrypt_1kib_mb_per_s',
        'e2e_per_change_us',
        'projected_seconds',
      ]) {
        _log('s4_bench.$key', bench.metrics[key]);
      }
    }

    // ---- (e) idle baseline ----------------------------------------------------------------------------------
    final taskIds = [
      for (final r
          in await db.customSelect('SELECT id FROM task_table WHERE deleted_date IS NULL ORDER BY id LIMIT 200').get())
        r.data['id'] as String
    ];
    instruments.open('idle');
    var idleActive = true;
    final idleProbe = _probe(db, taskIds, () => idleActive, retryBusy: false);
    await Future<void>.delayed(const Duration(seconds: 4));
    idleActive = false;
    instruments.close('idle');
    (await idleProbe).report('idle');

    // ---- (d)(e) apply runs -------------------------------------------------------------------------------------
    final a1 = await _applyRun(
        instruments,
        db,
        primaryPath,
        taskIds,
        ScaleRunConfig(
            label: 'shared_b1000',
            runIndex: 1,
            changes: _applyN,
            batchSize: 1000,
            shape: shape,
            measureFullState: true),
        separate: false);
    Map<String, Object?>? a2;
    if (_apply500N > 0) {
      a2 = await _applyRun(instruments, db, primaryPath, taskIds,
          ScaleRunConfig(label: 'shared_b500', runIndex: 2, changes: _apply500N, batchSize: 500, shape: shape),
          separate: false);
    }
    if (_applySeparateN > 0) {
      await _applyRun(instruments, db, primaryPath, taskIds,
          ScaleRunConfig(label: 'separate_b1000', runIndex: 3, changes: _applySeparateN, batchSize: 1000, shape: shape),
          separate: true);
    }
    final afterApply = await measureDbSize(db, primaryPath, '${root.path}/vac.sqlite');
    _log('size.after_apply.vacuum_bytes', afterApply.vacuumBytes);

    // Let the engine flush the last FrameTimings.
    await Future<void>.delayed(const Duration(seconds: 3));
    _log('frames.total_received', instruments.frames.length);
    for (final name in instruments.windows.keys) {
      instruments.report(name);
    }

    // ---- projections and go/no-go -------------------------------------------------------------------------
    num v(Map<String, Object?> m, String k) => m[k] as num;
    final n = v(a1, 'changes_prepared');
    final senderS = (v(a1, 'source_read_ms') + v(a1, 'sender_cpu_ms')) / 1000;
    final wireS = v(a1, 'wire_bytes_total') / _linkBytesPerSecond;
    final receiverS = v(a1, 'apply_total_ms') / 1000;
    _log('projection.200k.changes', n);
    _log('projection.200k.sender_s', senderS);
    _log('projection.200k.wire_s', wireS);
    _log('projection.200k.receiver_s', receiverS);
    _log('projection.200k.serial_s', senderS + wireS + receiverS);
    _log(
        'projection.200k.pipelined_s',
        [senderS, wireS, receiverS].reduce((a, b) => a > b ? a : b) +
            v(a1, 'wire_bytes_total') / n * 1000 / _linkBytesPerSecond);
    final cells = v(a1, 'full_state_cells');
    final perChangeSenderS = senderS / n;
    final perChangeReceiverS = receiverS / n;
    final fullWireS = v(a1, 'full_state_wire_bytes') / _linkBytesPerSecond;
    _log('projection.full_state.cells', cells);
    _log('projection.full_state.wire_mb', _mb(v(a1, 'full_state_wire_bytes').toInt()));
    _log('projection.full_state.one_way_serial_s', perChangeSenderS * cells + fullWireS + perChangeReceiverS * cells);
    _log('projection.full_state.two_way_serial_s',
        2 * (perChangeSenderS * cells + fullWireS + perChangeReceiverS * cells));
    if (a2 != null) {
      final batch500 = (a2['batch_total_ms'] as Map<String, num>);
      final avgWire = v(a2, 'wire_bytes_total') / v(a2, 'changes_prepared');
      final senderPer = (v(a2, 'source_read_ms') + v(a2, 'sender_cpu_ms')) / v(a2, 'changes_prepared') / 1000;
      _log('projection.500.apply_p95_s', batch500['p95']! / 1000);
      _log('projection.500.apply_max_s', batch500['max']! / 1000);
      _log('projection.500.end_to_end_s',
          500 * senderPer + 500 * avgWire / _linkBytesPerSecond + batch500['max']! / 1000);
    }
  } finally {
    await db?.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('S3 scale spike ($_fixture, $_shapeLabel)', (tester) async {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    await tester.pumpWidget(const _ScrollingProbe());
    final instruments = _Instruments()..start();
    try {
      await tester.runAsync(() => _runSpike(instruments));
    } finally {
      instruments.stop();
      binding.reportData = {'s3': _report};
    }
    await tester.pumpWidget(const SizedBox());
    expect(_report['shared_b1000.failed'], 0);
    expect(_report['shared_b1000.apply_mode_after'], 0);
  }, timeout: const Timeout(Duration(minutes: 60)));
}
