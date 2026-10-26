// Part 2 of the T27 acceptance suites: real Drift devices (key files, membership,
// capture triggers, the async session engine) with a configurable protocol, a
// controllable clock, and sessions run through the real SyncEngineService over
// an in-memory loopback or through a real LAN server.
import 'dart:io';

import 'package:whph/core/application/features/sync/models/sync_run_report.dart';
import 'package:whph/core/application/features/sync/services/sync_engine_service.dart';
import 'package:whph/core/application/features/sync/services/sync_ledger_mark_service.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_status_store.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_change_store.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/shared/features/sync/drift_async_session_device.dart';
import 'package:whph/infrastructure/shared/features/sync/drift_sync_session_host.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../../infrastructure/persistence/sync/drift_sync_test_support.dart';
import '../../../infrastructure/shared/features/sync/sync_app_test_support.dart';
import '../../../infrastructure/shared/features/sync/sync_security_test_support.dart';

const String labPlatform = 'linux';
const String labAppVersion = '9.9.9';
const int _loopbackPort = 1;
const int _startWallMs = 1767225600000;
const int _convergenceRounds = 3;

/// A wall clock the test moves by hand.
class LabClock {
  int nowMs = _startWallMs;

  void advance(Duration by) => nowMs += by.inMilliseconds;
}

/// One device of the lab: the Drift database with its key files and the
/// session engine over it. [rebuild] re-creates the engine after the files or
/// the database were replaced (a restore).
class LabDevice {
  final SecurityDevice security;
  final LabClock clock;
  final SyncEngineConfig config;
  late DriftAsyncSessionDevice device;
  late DriftSyncSessionHost host;
  SessionHooks hooks;

  LabDevice._(this.security, this.clock, this.config, this.hooks) {
    rebuild();
  }

  static Future<LabDevice> open(
    String name,
    Directory scratch, {
    SyncEngineConfig? config,
    SessionHooks hooks = const SessionHooks(),
    LabClock? clock,
  }) async {
    final security = await SecurityDevice.open(name, scratch);
    return LabDevice._(
      security,
      clock ?? LabClock(),
      config ?? SyncEngineConfig(delay: (_) async {}),
      hooks,
    );
  }

  /// Creates the engine objects over the current stores of [security].
  void rebuild() {
    final marks = SyncLedgerMarkService(
      keyStore: security.keyStore,
      changeStore: security.database.store,
      delay: (_) async {},
    );
    final startupCheck = SyncStartupCheckService(
      membershipService: security.service,
      keyStore: security.keyStore,
      changeStore: security.database.store,
      marks: marks,
    );
    device = DriftAsyncSessionDevice(
      membershipService: security.service,
      keyStore: security.keyStore,
      changeStore: security.database.store,
      store: DriftAsyncSyncStore(security.database.store),
      marks: marks,
      startupCheck: startupCheck,
      config: config,
      nowMs: () => clock.nowMs,
    );
    host = _hostWith(hooks);
  }

  DriftSyncSessionHost _hostWith(SessionHooks hooks) => DriftSyncSessionHost(
        device: device,
        platform: labPlatform,
        appVersion: labAppVersion,
        hooks: hooks,
      );

  /// Replaces the test hooks that act on this device's sessions.
  void setHooks(SessionHooks next) {
    hooks = next;
    host = _hostWith(next);
  }

  String get name => security.name;
  String get memberId => security.memberId;
  SyncTestDevice get db => security.database;
  AppDatabase get appDatabase => security.database.db;

  Future<String> origin() => security.database.store.localOrigin();

  Future<SessionResult> initiate(ISyncTransport transport, String peerMemberId) =>
      host.initiate(transport, peerMemberId);

  Future<SessionResult> respond(ISyncTransport transport) => host.respond(transport, 'lab');

  Future<void> close() => security.close();
}

/// Both ends of one in-memory session.
class SessionPair {
  final SessionResult initiator;
  final SessionResult responder;

  const SessionPair(this.initiator, this.responder);

  bool get bothComplete => initiator is SessionComplete && responder is SessionComplete;

  bool get exchangedNothing => !initiator.exchanged && !responder.exchanged;

  @override
  String toString() => 'initiator=$initiator responder=$responder';
}

/// A set of devices that sync with each other.
class Lab {
  final Directory scratch;
  final List<LabDevice> devices = [];

  Lab._(this.scratch);

  static Future<Lab> create() async => Lab._(await Directory.systemTemp.createTemp('t27b-lab-'));

  /// Opens a device. When [pairWith] is given it joins that device's group.
  Future<LabDevice> add(
    String name, {
    LabDevice? pairWith,
    SyncEngineConfig? config,
    SessionHooks hooks = const SessionHooks(),
    bool confirmGroupSwitch = false,
  }) async {
    final device = await LabDevice.open(name, scratch, config: config, hooks: hooks);
    devices.add(device);
    if (pairWith != null) {
      await pairDevices(pairWith.security, device.security, confirmGroupSwitch: confirmGroupSwitch);
    }
    return device;
  }

  /// One session of [from] (initiator) with [into] over an in-memory link.
  Future<SessionPair> session(LabDevice from, LabDevice into, {TransportFaults faults = TransportFaults.none}) async {
    final (initiatorEnd, responderEnd) = InMemoryTransport.pair(faults: faults);
    final results = await Future.wait([
      from.initiate(initiatorEnd, into.memberId),
      into.respond(responderEnd),
    ]);
    return SessionPair(results[0], results[1]);
  }

  SyncEngineService _engineOf(LabDevice from, LoopbackConnector connector) => SyncEngineService(
        membershipService: from.security.service,
        statusStore: DriftSyncPeerStatusStore(from.db.db),
        peerStateStore: from.security.peerStates,
        connector: connector,
        host: from.host,
        upgradeService: DoneUpgradeService(),
        device: from.device,
        port: _loopbackPort,
        now: () => DateTime.fromMillisecondsSinceEpoch(from.clock.nowMs, isUtc: true),
      );

  /// One session through the real [SyncEngineService] of [from] towards [into]
  /// (statuses, categories and the upgrade gate included).
  Future<SyncPeerReport> engineSync(LabDevice from, LabDevice into) async {
    final connector = LoopbackConnector()..responder = into.respond;
    await from.security.peerStates.saveAddresses(into.memberId, [loopbackAddress]);
    final report = await _engineOf(from, connector).syncPeer(into.memberId);
    await connector.settle();
    return report.peers.single;
  }

  /// The periodic run of [from]: one session with every peer of its group. The
  /// connector never reaches anyone, so the report shows which peers were tried.
  Future<SyncRunReport> engineSyncAll(LabDevice from) async {
    final connector = LoopbackConnector();
    final report = await _engineOf(from, connector).syncAll();
    await connector.settle();
    return report;
  }

  /// Every ordered pair syncs, [rounds] times: all devices reach the same state.
  Future<void> converge({List<LabDevice>? among, int rounds = _convergenceRounds}) async {
    final group = among ?? devices;
    for (var round = 0; round < rounds; round++) {
      for (final from in group) {
        for (final into in group) {
          if (from != into) await session(from, into);
        }
      }
    }
  }

  Future<void> close() async {
    for (final device in devices) {
      await device.close();
    }
    if (scratch.existsSync()) await scratch.delete(recursive: true);
  }
}

/// The synced content of [device] as one comparable string.
Future<String> contentOf(LabDevice device) => device.db.content();

/// Whether every device holds the same synced content.
Future<bool> sameContent(Iterable<LabDevice> devices) async {
  final contents = {for (final device in devices) await contentOf(device)};
  return contents.length == 1;
}

/// The lines of the synced content that only one of the two devices holds
/// (empty when equal); a readable reason for a failed equality check.
Future<String> contentDiff(LabDevice first, LabDevice second) async {
  final left = (await contentOf(first)).split('\n').toSet();
  final right = (await contentOf(second)).split('\n').toSet();
  final onlyFirst = left.difference(right).map((line) => '< $line');
  final onlySecond = right.difference(left).map((line) => '> $line');
  return [...onlyFirst, ...onlySecond].join('\n');
}
