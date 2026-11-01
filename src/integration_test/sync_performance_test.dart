// T28: two-device sync performance (SC-012, SC-013, plan U9/U10/PA-2/PA-6).
// Real services over a real LAN: pairing, SyncEngineService and
// DriftSyncSessionHost over a WebSocket between two physical devices. Nothing in
// this file has been run on hardware yet; the headless loopback variant
// (test/performance_sync/sync_performance_loopback_test.dart) produced the
// desktop numbers in .agents/state/reliable-secure-lan-sync/reports/.
//
// PROCEDURE (a human runs it; one Linux desktop and one Android phone)
//
//  1. Put both on the same Wi-Fi. If iperf3 exists, measure the link
//     (`iperf3 -s` on one, `iperf3 -c <ip>` on the other); it must be at
//     least 20 Mbit/s. Write the figure into the report.
//  2. SERVER device (holds the full large_usage data, listens, shows the
//     invitation). Start it first, for example on Linux:
//       cd src && fvm flutter test integration_test/sync_performance_test.dart \
//         -d linux --dart-define=PERF_ROLE=server --dart-define=PERF_MODE=first
//     It builds large_usage, runs the migration and the bootstrap job (the
//     time is printed), starts the LAN server and prints a line
//       PERF_INVITATION=whph-pair:...
//     It stays up for PERF_SERVER_MINUTES (default 45) and prints its own
//     action latencies at the end.
//  3. CLIENT device (empty, joins, measures). Copy the invitation text:
//       cd src && fvm flutter test integration_test/sync_performance_test.dart \
//         -d <android-id> --dart-define=PERF_ROLE=client \
//         --dart-define=PERF_MODE=first --dart-define=PERF_INVITATION=<text>
//     It pairs (the code comparison is confirmed by the test itself; it is a
//     performance run, not a security check), then measures: first full sync,
//     a 500-change session, list-open and edit latency during both, the
//     group-switch re-author job (chunk times), the tombstone share (U10).
//  4. Repeat both roles with PERF_MODE=twoway: the client also loads
//     large_usage and bootstraps it before pairing; the first sync is then the
//     full-state two-way exchange measured against the 6-minute T6 gate
//     (U9/PA-2). Run the server once per client run.
//  5. Swap the devices (Android as server, Linux as client) and repeat 2-4 to
//     get latency on each side. SC-013 on Windows needs a Windows machine: if
//     none is available, record it as a gap; it is not a pass.
//  6. The client prints the metrics table (markdown) between
//     PERF_REPORT_BEGIN and PERF_REPORT_END; paste it into
//     .agents/state/reliable-secure-lan-sync/reports/t28-perf-devices.md.
//
// Thresholds (soft gates, printed as "Met"): first full sync <= 10 min;
// 500 changes <= 15 s; every sampled action < 1 s; re-author <= 120 s with each
// chunk <= 2 s; two-way first sync <= 6 min.
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/application/features/sync/services/network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/sync_engine_service.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_status_store.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph/infrastructure/shared/features/sync/drift_sync_session_host.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_client.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_peer_connector.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';

import '../test/infrastructure/shared/features/sync/sync_security_test_support.dart';
import '../test/integration/sync_acceptance/support2/lab.dart';
import '../test/performance_sync/perf_harness.dart';

const String _role = String.fromEnvironment('PERF_ROLE');
const String _mode = String.fromEnvironment('PERF_MODE', defaultValue: 'first');
const String _invitationText = String.fromEnvironment('PERF_INVITATION');
const int _serverMinutes = int.fromEnvironment('PERF_SERVER_MINUTES', defaultValue: 45);
const bool _isTwoWay = _mode == 'twoway';

const Duration _firstSyncLimit = Duration(minutes: 10);
const Duration _twoWayFirstSyncLimit = Duration(minutes: 6);
const Duration _changeSessionLimit = Duration(seconds: 15);
const Duration _reauthorTotalLimit = Duration(seconds: 120);
const Duration _pairingTimeout = Duration(minutes: 2);
const int _taskEdits = 300;
const int _noteInserts = 200;
const String _platformName = String.fromEnvironment('PERF_PLATFORM', defaultValue: '');

/// The pairing, engine and host services of one lab device, wired as the app
/// wires them (no loopback shortcut between devices).
class _NetworkDevice {
  final LabDevice lab;
  final SyncPairingService pairing;
  final DriftSyncSessionHost host;

  _NetworkDevice._(this.lab, this.pairing, this.host);

  static _NetworkDevice wire(LabDevice lab) {
    final pairing = SyncPairingService(
      membershipService: lab.security.service,
      connector: const LanSyncPeerConnector(LanSyncClient()),
      statusStore: DriftSyncPeerStatusStore(lab.appDatabase),
      networkInterfaces: NetworkInterfaceService(),
      upgradeService: SyncUpgradeJob(lab.appDatabase),
      platform: Platform.operatingSystem,
    );
    final host = DriftSyncSessionHost(
      device: lab.device,
      platform: Platform.operatingSystem,
      appVersion: labAppVersion,
      onPair: pairing.respond,
    );
    return _NetworkDevice._(lab, pairing, host);
  }

  SyncEngineService engine() => SyncEngineService(
        membershipService: lab.security.service,
        statusStore: DriftSyncPeerStatusStore(lab.appDatabase),
        peerStateStore: lab.security.peerStates,
        connector: const LanSyncPeerConnector(LanSyncClient()),
        host: host,
        upgradeService: SyncUpgradeJob(lab.appDatabase),
        device: lab.device,
        port: lanSyncPort,
      );
}

Future<LabDevice> _openDevice(Lab lab, String name, {required bool withFixture, required Directory root}) async {
  if (!withFixture) return lab.add(name);
  final fixture = await buildLargeUsageFixture(Directory('${root.path}/fixtures'));
  final opened = await openFixtureDevice(lab, name, fixture);
  // ignore: avoid_print
  print('PERF upgrade + bootstrap of large_usage on $name: ${formatSeconds(opened.upgradeTime)}');
  return opened.device;
}

Future<void> _runServer(Lab lab, Directory root) async {
  final device = await _openDevice(lab, 'server', withFixture: true, root: root);
  final network = _NetworkDevice.wire(device);
  final server = LanSyncServer(host: network.host);
  expect(await server.start(), isTrue, reason: 'the LAN server must start');
  addTearDown(server.stop);
  final invitation = await network.pairing.createInvitation();
  // ignore: avoid_print
  print('PERF_INVITATION=${invitation.encode()}');
  final latency = ActionLatencySampler([device.appDatabase]);
  await latency.start();
  await Future<void>.delayed(Duration(minutes: _serverMinutes));
  await latency.stop();
  final report = PerfReport('T28 server side ($_platformName ${Platform.operatingSystem})');
  latency.addTo(report, 'server, whole run');
  // ignore: avoid_print
  print('PERF_REPORT_BEGIN\n${report.toMarkdown('')}PERF_REPORT_END');
}

Future<void> _pair(_NetworkDevice client) async {
  final done = Completer<SyncPairingStatus>();
  final subscription = client.pairing.statusStream.listen((status) {
    if (status.phase == SyncPairingPhase.comparingCodes) client.pairing.confirmCode();
    if (status.isTerminal && !done.isCompleted) done.complete(status);
  });
  addTearDown(subscription.cancel);
  await client.pairing.pairFromInvitation(PairingInvitation.decode(_invitationText));
  final status = await done.future.timeout(_pairingTimeout);
  expect(status.phase, SyncPairingPhase.completed, reason: 'pairing failed: $status');
}

Future<({Duration elapsed, int bytes, bool complete})> _syncWithServer(_NetworkDevice client) async {
  final peerId = client.lab.security.membership.activeMembers
      .firstWhere((member) => member.memberId != client.lab.memberId)
      .memberId;
  final stopwatch = Stopwatch()..start();
  final report = await client.engine().syncPeer(peerId);
  final peer = report.peers.single;
  return (elapsed: stopwatch.elapsed, bytes: peer.result?.stats.bytesSent ?? 0, complete: peer.result?.isComplete ?? false);
}

Future<void> _runClient(Lab lab, Directory root) async {
  expect(_invitationText, isNotEmpty, reason: 'pass --dart-define=PERF_INVITATION=<text from the server>');
  final report = PerfReport('T28 two-device sync performance ($_platformName ${Platform.operatingSystem}, mode $_mode)');
  final device = await _openDevice(lab, 'client', withFixture: _isTwoWay, root: root);
  final network = _NetworkDevice.wire(device);
  await _pair(network);

  final firstLatency = ActionLatencySampler([device.appDatabase]);
  await firstLatency.start();
  final first = await _syncWithServer(network);
  await firstLatency.stop();
  final firstLimit = _isTwoWay ? _twoWayFirstSyncLimit : _firstSyncLimit;
  report.add('first sync complete', '${first.complete}', met: first.complete);
  report.addTime(_isTwoWay ? 'full-state two-way first sync (U9/PA-2)' : 'first full sync', first.elapsed,
      limit: firstLimit);
  report.add('first sync bytes sent by this device', formatMegabytes(first.bytes));
  (await TombstoneStats.read(device.appDatabase)).addTo(report, firstSyncTime: first.elapsed, firstSyncBytes: first.bytes);
  firstLatency.addTo(report, 'during first sync');

  await _makeChanges(device);
  final changeLatency = ActionLatencySampler([device.appDatabase]);
  await changeLatency.start();
  final changes = await _syncWithServer(network);
  await changeLatency.stop();
  report.addTime('${_taskEdits + _noteInserts} changes session', changes.elapsed, limit: _changeSessionLimit);
  changeLatency.addTo(report, 'during change session');

  if (!_isTwoWay) await _measureReauthor(lab, device, report);
  // ignore: avoid_print
  print('PERF_REPORT_BEGIN\n${report.toMarkdown('Link: record the iperf3 result here.')}PERF_REPORT_END');
  expect(report.unmet.map((metric) => metric.name), isEmpty, reason: 'soft gates');
}

Future<void> _makeChanges(LabDevice device) async {
  final database = device.appDatabase;
  await database.transaction(() async {
    await database.customStatement('UPDATE task_table SET title = title || ? WHERE id IN '
        '(SELECT id FROM task_table WHERE deleted_date IS NULL ORDER BY id LIMIT $_taskEdits)', [' (edited)']);
    for (var index = 0; index < _noteInserts; index++) {
      await database.customStatement(
          "INSERT INTO note_table (id, created_date, title, content) VALUES ('perf-note-$index', 1700000000, 'perf $index', 'body')");
    }
  });
}

/// The group switch is local work; the other group is an in-process helper
/// device, joined through the real handover.
Future<void> _measureReauthor(Lab lab, LabDevice device, PerfReport report) async {
  final other = await lab.add('other-group');
  final timings = <UpgradeChunkTiming>[];
  await pairDevices(other.security, device.security, confirmGroupSwitch: true);
  final stopwatch = Stopwatch()..start();
  await SyncUpgradeJob(device.appDatabase, onChunk: timings.add).runChunks();
  final chunks = timings.where((chunk) => chunk.phase == SyncUpgradePhase.reauthor).toList();
  final slowest = chunks.fold(Duration.zero, (worst, chunk) => chunk.elapsed > worst ? chunk.elapsed : worst);
  report.addTime('group-switch re-author job', stopwatch.elapsed, limit: _reauthorTotalLimit);
  report.add('group-switch re-author chunks', '${chunks.length}: ${chunks.map((chunk) => formatSeconds(chunk.elapsed)).join(', ')}');
  report.addTime('slowest re-author chunk', slowest, limit: sc012ReauthorChunkLimit);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('T28 two-device sync performance', () async {
    expect(_role, anyOf('server', 'client'), reason: 'pass --dart-define=PERF_ROLE=server|client');
    final root = Directory.systemTemp.createTempSync('whph_t28_device_');
    addTearDown(() => root.deleteSync(recursive: true));
    final lab = await Lab.create();
    addTearDown(lab.close);
    await (_role == 'server' ? _runServer(lab, root) : _runClient(lab, root));
  }, timeout: const Timeout(Duration(minutes: 60)));
}
