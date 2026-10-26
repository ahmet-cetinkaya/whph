// T28, headless variant: the SC-012/U9/U10 measurements between two AppDatabase
// devices on this machine, over the real LanSyncServer/LanSyncClient on
// loopback. These are loopback DESKTOP numbers, not device numbers: the network
// is free, and the databases share one isolate with the sampler (so a blocked
// event loop shows up as latency). Android and Windows stay a human gap; the
// two-device run is integration_test/sync_performance_test.dart.
//
// Run: cd src && timeout 30m fvm flutter test --tags perf-sync --timeout=25m \
//        test/performance_sync/sync_performance_loopback_test.dart
// Writes: .agents/state/reliable-secure-lan-sync/reports/t28-perf-loopback.md
@Tags(['perf-sync'])
@Timeout(Duration(minutes: 30))
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';

import '../infrastructure/shared/features/sync/sync_security_test_support.dart';
import '../integration/sync_acceptance/support2/lab.dart';
import '../integration/sync_acceptance/support2/lan_support.dart';
import 'perf_harness.dart';

const Duration firstSyncLimit = Duration(minutes: 10);
const Duration changeSessionLimit = Duration(seconds: 15);
const Duration twoWayFirstSyncLimit = Duration(minutes: 6);
const Duration reauthorTotalLimit = Duration(seconds: 120);
const int taskEdits = 300;
const int noteInserts = 200;
const String _reportPath = '../.agents/state/reliable-secure-lan-sync/reports/t28-perf-loopback.md';

/// A real LAN server for [device] on a free loopback port.
class LanLink {
  final LabDevice device;
  final RecordingHost recorder;
  final int port;

  LanLink._(this.device, this.recorder, this.port);

  static Future<LanLink> open(LabDevice device) async {
    final recorder = RecordingHost(device);
    final server = await startLanServer(recorder);
    return LanLink._(device, recorder, server.port!);
  }

  /// One session of [from] towards the server; returns the time and both ends' bytes.
  Future<({Duration elapsed, int bytes, bool complete})> sync(LabDevice from) async {
    final stopwatch = Stopwatch()..start();
    final before = recorder.results.length;
    final initiator = await syncOverLan(from, device, port);
    final elapsed = stopwatch.elapsed;
    final responder = await recorder.resultAfter(before);
    return (
      elapsed: elapsed,
      bytes: initiator.stats.bytesSent + responder.stats.bytesSent,
      complete: initiator.isComplete && responder.isComplete,
    );
  }
}

Future<void> _makeChanges(LabDevice device) async {
  final db = device.appDatabase;
  await db.transaction(() async {
    await db.customStatement('UPDATE task_table SET title = title || ? WHERE id IN '
        '(SELECT id FROM task_table WHERE deleted_date IS NULL ORDER BY id LIMIT $taskEdits)', [' (edited)']);
    for (var index = 0; index < noteInserts; index++) {
      await db.customStatement(
          "INSERT INTO note_table (id, created_date, title, content) VALUES ('perf-note-$index', 1700000000, 'perf $index', 'body')");
    }
  });
}

Future<Duration> _runTimed(Future<void> Function() body) async {
  final stopwatch = Stopwatch()..start();
  await body();
  return stopwatch.elapsed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('T28 loopback: first sync, 500 changes, latency, re-author, two-way first sync', () async {
    final report = PerfReport('T28 sync performance - LOOPBACK DESKTOP numbers (not device numbers)');
    final root = Directory.systemTemp.createTempSync('whph_t28_perf_');
    addTearDown(() => root.deleteSync(recursive: true));
    final fixture = await buildLargeUsageFixture(Directory(p.join(root.path, 'fixtures')));

    final lab = await Lab.create();
    final openLabs = [lab];
    addTearDown(() async {
      for (final open in openLabs) {
        await open.close();
      }
    });
    final upgraded = await openFixtureDevice(lab, 'A', fixture);
    final a = upgraded.device;
    report.addTime('A: upgrade + bootstrap job (large_usage)', upgraded.upgradeTime);
    final b = await lab.add('B', pairWith: a);
    final linkToB = await LanLink.open(b);
    final tombstones = await TombstoneStats.read(a.appDatabase);

    final firstSyncLatency = ActionLatencySampler([a.appDatabase, b.appDatabase]);
    await firstSyncLatency.start();
    final first = await linkToB.sync(a);
    await firstSyncLatency.stop();
    report.add('first full sync (A full -> B empty): complete', '${first.complete}', met: first.complete);
    report.addTime('first full sync time', first.elapsed, limit: firstSyncLimit);
    report.add('first full sync bytes (both directions)', formatMegabytes(first.bytes));
    report.add('first full sync throughput', '${(first.bytes / 1024 / 1024 / first.elapsed.inSeconds.clamp(1, 1 << 30)).toStringAsFixed(2)} MiB/s');
    tombstones.addTo(report, firstSyncTime: first.elapsed, firstSyncBytes: first.bytes);
    firstSyncLatency.addTo(report, 'during first sync');

    await _makeChanges(a);
    final changeLatency = ActionLatencySampler([a.appDatabase, b.appDatabase]);
    await changeLatency.start();
    final changes = await linkToB.sync(a);
    await changeLatency.stop();
    report.add('${taskEdits + noteInserts} changes: complete', '${changes.complete}', met: changes.complete);
    report.addTime('${taskEdits + noteInserts} changes session time', changes.elapsed, limit: changeSessionLimit);
    report.add('${taskEdits + noteInserts} changes bytes', formatMegabytes(changes.bytes));
    changeLatency.addTo(report, 'during ${taskEdits + noteInserts}-change session');

    final x = await lab.add('X');
    final chunkTimes = <UpgradeChunkTiming>[];
    await pairDevices(x.security, a.security, confirmGroupSwitch: true);
    final reauthorTime = await _runTimed(() => SyncUpgradeJob(a.appDatabase, onChunk: chunkTimes.add).runChunks());
    final reauthorChunks = chunkTimes.where((chunk) => chunk.phase == SyncUpgradePhase.reauthor).toList();
    final slowestChunk = reauthorChunks.fold(Duration.zero, (worst, chunk) => chunk.elapsed > worst ? chunk.elapsed : worst);
    report.addTime('group-switch re-author job time (A, desktop)', reauthorTime, limit: reauthorTotalLimit);
    report.add('group-switch re-author chunks', '${reauthorChunks.length}: ${reauthorChunks.map((chunk) => formatSeconds(chunk.elapsed)).join(', ')}');
    report.addTime('group-switch slowest re-author chunk', slowestChunk, limit: sc012ReauthorChunkLimit);

    await lab.close();
    openLabs.clear();
    final twoWayLab = await Lab.create();
    openLabs.add(twoWayLab);
    final c = (await openFixtureDevice(twoWayLab, 'C', fixture)).device;
    final d = (await openFixtureDevice(twoWayLab, 'D', fixture)).device;
    await pairDevices(c.security, d.security);
    await SyncUpgradeJob(d.appDatabase).runChunks();
    final linkToD = await LanLink.open(d);
    final twoWay = await linkToD.sync(c);
    report.add('full-state two-way first sync (C <-> D, both large_usage): complete', '${twoWay.complete}', met: twoWay.complete);
    report.addTime('full-state two-way first sync time (U9/PA-2)', twoWay.elapsed, limit: twoWayFirstSyncLimit);
    report.add('full-state two-way first sync bytes', formatMegabytes(twoWay.bytes));

    final markdown = report.toMarkdown(
        'Platform: ${Platform.operatingSystem}, ${Platform.numberOfProcessors} cores. Loopback sockets, sampler and both databases in one isolate. NOT SC-012/SC-013 device evidence.');
    File(_reportPath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(markdown);
    // ignore: avoid_print
    print(markdown);
    expect(report.unmet.map((metric) => metric.name), isEmpty, reason: 'soft gates (see $_reportPath)');
  });
}
