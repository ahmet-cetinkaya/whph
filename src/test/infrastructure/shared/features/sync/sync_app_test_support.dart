// Harness for the T23 tests: the sync engine of device A over the real
// session engine, reaching device B through in-memory transports.
import 'dart:async';
import 'dart:io';

import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/models/sync_run_report.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_connector.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/application/features/sync/services/sync_engine_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_status_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'drift_session_test_support.dart';

const String loopbackAddress = 'loopback';
const int _loopbackPort = 1;

/// Connects to a responder in the same process, or fails like a peer that is
/// off the network.
class LoopbackConnector implements ISyncPeerConnector {
  Future<Object?> Function(ISyncTransport peerEnd)? responder;
  bool reachable = true;

  /// What the responder side of each connection ended with (a result or an
  /// error).
  final List<Object?> responderOutcomes = [];
  final List<Future<void>> _responses = [];

  @override
  Future<ISyncTransport> connect(String address, {required int port, bool forPairing = false}) async {
    final answer = responder;
    if (!reachable || answer == null) throw const SocketException('peer is off the network');
    final (client, server) = InMemoryTransport.pair();
    _responses.add(answer(server)
        .then<void>(responderOutcomes.add, onError: (Object error) => responderOutcomes.add(error))
        .whenComplete(server.close));
    return client;
  }

  /// Waits until the responder side of every opened connection is done.
  Future<void> settle() => Future.wait(_responses);
}

/// A host that ends every session with [result].
class ScriptedHost implements ISyncSessionHost {
  SessionResult result;

  ScriptedHost(this.result);

  @override
  Future<SessionResult> initiate(ISyncTransport transport, String peerMemberId) async => result;

  @override
  Future<SyncPresence> presence() => throw UnimplementedError();

  @override
  Future<SessionResult> respond(ISyncTransport transport, String source) => throw UnimplementedError();

  @override
  Future<void> pair(ISyncTransport transport, String source) => throw UnimplementedError();
}

class DoneUpgradeService implements ISyncUpgradeService {
  @override
  Future<SyncUpgradeProgress> getProgress() async => const SyncUpgradeProgress(phase: SyncUpgradePhase.done);

  @override
  Future<void> run() async {}
}

/// A wall clock that moves one minute per reading.
class SteppingClock {
  DateTime _now = DateTime.utc(2026, 1, 1);

  DateTime call() => _now = _now.add(const Duration(minutes: 1));
}

/// The engine of [local] towards [remote], with the local status store.
class EngineFixture {
  final DriftEngineDevice local;
  final DriftEngineDevice remote;
  final LoopbackConnector connector = LoopbackConnector();
  final DriftSyncPeerStatusStore statusStore;
  final SteppingClock clock = SteppingClock();
  late final SyncEngineService engine;

  EngineFixture._(this.local, this.remote, this.statusStore);

  static Future<EngineFixture> create(DriftEngineDevice local, DriftEngineDevice remote,
      {ISyncSessionHost? host}) async {
    final fixture = EngineFixture._(local, remote, DriftSyncPeerStatusStore(local.security.database.db));
    fixture.connector.responder = remote.respond;
    fixture.engine = SyncEngineService(
      membershipService: local.security.service,
      statusStore: fixture.statusStore,
      peerStateStore: local.security.peerStates,
      connector: fixture.connector,
      host: host ?? local.host,
      upgradeService: DoneUpgradeService(),
      device: local.device,
      port: _loopbackPort,
      now: fixture.clock.call,
    );
    await local.security.peerStates.saveAddresses(remote.memberId, [loopbackAddress]);
    return fixture;
  }

  Future<SyncPeerReport> syncOnce() async {
    final report = await engine.syncPeer(remote.memberId);
    await connector.settle();
    return report.peers.single;
  }

  Future<DateTime?> lastSuccess() async => (await statusStore.read(remote.memberId))?.lastSuccessLocal;

  Future<SyncResultCategory?> lastResult() async => (await statusStore.read(remote.memberId))?.lastResult;
}

Future<Set<String>> noteTitles(DriftEngineDevice device) async => {
      for (final row in await device.security.database.rows('SELECT title FROM note_table')) '${row['title']}',
    };
