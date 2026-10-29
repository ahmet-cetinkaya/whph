// Devices for the part-1 acceptance suites (T27): each device is a real Drift
// database with its key files and membership, and every sync goes through the
// application's SyncEngineService, the Drift session host and loopback
// transports that can be cut. Wall clocks are controlled per device.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/sync_run_report.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_connector.dart';
import 'package:whph/core/application/features/sync/services/sync_engine_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_status_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../../infrastructure/persistence/sync/drift_sync_test_support.dart';
import '../../../infrastructure/shared/features/sync/drift_session_test_support.dart';
import '../../../infrastructure/shared/features/sync/sync_app_test_support.dart';
import '../../../infrastructure/shared/features/sync/sync_security_test_support.dart';

const int _millisPerHour = 60 * 60 * 1000;
const int _enginePort = 1;
const int _maxRounds = 6;

/// Routes a connection to the responder side of the peer named by [address],
/// over an in-memory link that carries the faults set for the next session.
class _FleetConnector implements ISyncPeerConnector {
  final Map<String, FleetDevice> peersByName;
  TransportFaults faults = TransportFaults.none;
  TransportTrace? trace;
  final List<Future<void>> _responses = [];

  _FleetConnector(this.peersByName);

  @override
  Future<ISyncTransport> connect(String address, {required int port, bool forPairing = false}) async {
    final peer = peersByName[address];
    if (peer == null) throw const SocketException('peer is off the network');
    final (client, server) = InMemoryTransport.pair(faults: faults, trace: trace);
    _responses
        .add(peer.engineDevice.respond(server).then<void>((_) {}, onError: (Object _) {}).whenComplete(server.close));
    return client;
  }

  Future<void> settle() => Future.wait(_responses);
}

/// One member device and the engine that starts its sessions.
class FleetDevice {
  final String name;
  final DriftEngineDevice engineDevice;
  int clockOffsetMs;
  late final SyncEngineService engine;
  late final _FleetConnector _connector;

  FleetDevice._(this.name, this.engineDevice, this.clockOffsetMs);

  SyncTestDevice get database => engineDevice.security.database;
  String get memberId => engineDevice.memberId;

  Future<void> sql(String statement) => database.sql(statement);

  /// The device clock now, in epoch milliseconds, including its offset.
  int get nowMs => DateTime.now().millisecondsSinceEpoch + clockOffsetMs;

  /// Moves this device's clock [hours] ahead of real time from now on, so its
  /// next edits carry a later recorded time (hybrid clocks never run back).
  Future<void> setClockAheadHours(int hours) async {
    clockOffsetMs = hours * _millisPerHour;
    await sql('UPDATE sync_state SET hlc = MAX(hlc, ($nowMs) << $hlcBits)');
  }

  Future<void> insertTask(String id, String title) =>
      sql("INSERT INTO task_table (id, created_date, title) VALUES ('$id', 1, '$title')");

  Future<void> setTaskTitle(String id, String title) => sql("UPDATE task_table SET title = '$title' WHERE id = '$id'");

  Future<void> setTaskReminder(String id, int reminderTime) =>
      sql("UPDATE task_table SET planned_date_reminder_time = $reminderTime WHERE id = '$id'");

  Future<void> deleteTask(String id) => sql("UPDATE task_table SET deleted_date = ${nowMs ~/ 1000} WHERE id = '$id'");

  Future<void> setNoteContent(String id, String content) =>
      sql("UPDATE note_table SET content = '$content' WHERE id = '$id'");

  /// Every row of [table] as synced content: all columns except the local
  /// `modified_date` revision (D4) and `created_date` (not a synced column), ordered by id.
  Future<List<Map<String, Object?>>> rowsOf(String table) async => [
        for (final row in await database.rows('SELECT * FROM $table ORDER BY id'))
          {...row}
            ..remove('modified_date')
            ..remove('created_date'),
      ];

  Future<Map<String, Object?>?> rowById(String table, String id) async {
    final rows = await rowsOf(table);
    return rows.where((row) => row['id'] == id).firstOrNull;
  }

  Future<List<String>> liveIds(String table) async => [
        for (final row in await database.rows('SELECT id FROM $table WHERE deleted_date IS NULL ORDER BY id'))
          row['id'] as String,
      ];
}

class AcceptanceFleet {
  final Directory scratch;
  final Map<String, FleetDevice> devices = {};

  AcceptanceFleet._(this.scratch);

  static Future<AcceptanceFleet> open() async =>
      AcceptanceFleet._(await Directory.systemTemp.createTemp('sync-acceptance-'));

  /// Adds a device; with [inviter] it is paired through the real handover.
  Future<FleetDevice> add(String name, {FleetDevice? inviter, int clockAheadHours = 0}) async {
    late final FleetDevice device;
    final engineDevice = await DriftEngineDevice.open(name, scratch, nowMs: () => device.nowMs);
    device = FleetDevice._(name, engineDevice, 0);
    devices[name] = device;
    device._connector = _FleetConnector(devices);
    final statusStore = DriftSyncPeerStatusStore(device.database.db);
    device.engine = SyncEngineService(
      membershipService: engineDevice.security.service,
      statusStore: statusStore,
      peerStateStore: engineDevice.security.peerStates,
      connector: device._connector,
      host: engineDevice.host,
      upgradeService: DoneUpgradeService(),
      device: engineDevice.device,
      port: _enginePort,
      now: SteppingClock().call,
    );
    if (inviter != null) await pairDevices(inviter.engineDevice.security, engineDevice.security);
    if (clockAheadHours != 0) await device.setClockAheadHours(clockAheadHours);
    return device;
  }

  FleetDevice operator [](String name) => devices[name]!;

  /// One session started by [from] towards [into], optionally over a faulty
  /// link. Returns the engine's report of that session.
  Future<SyncPeerReport> session(
    String from,
    String into, {
    TransportFaults faults = TransportFaults.none,
    TransportTrace? trace,
  }) async {
    final initiator = this[from];
    final responder = this[into];
    initiator._connector
      ..faults = faults
      ..trace = trace;
    await initiator.engineDevice.security.peerStates.saveAddresses(responder.memberId, [into]);
    final report = await initiator.engine.syncPeer(responder.memberId);
    await initiator._connector.settle();
    expect(report.peers, hasLength(1), reason: '$from does not know $into as a member yet: skipped');
    return report.peers.single;
  }

  /// Sessions over the given undirected [links] until a whole round changes
  /// nothing, so membership and changes reach every device that the links
  /// connect, directly or through relays.
  Future<void> settleOver(List<(String, String)> links) async {
    var previous = await _fingerprint();
    for (var round = 0; round < _maxRounds; round++) {
      for (final (first, second) in links) {
        await session(first, second);
        await session(second, first);
      }
      final current = await _fingerprint();
      if (current == previous) return;
      previous = current;
    }
    fail('devices did not settle within $_maxRounds rounds over $links');
  }

  Future<String> _fingerprint() async {
    final parts = <String>[];
    for (final device in devices.values) {
      parts.add('${await device.database.store.readVector()}');
    }
    return parts.join('|');
  }

  Future<void> close() async {
    for (final device in devices.values) {
      await device.engineDevice.close();
    }
    await scratch.delete(recursive: true);
  }
}

/// Every device holds the same synced content in each of [tables] (FR-001).
Future<void> expectIdenticalData(Iterable<FleetDevice> devices, List<String> tables) async {
  final list = devices.toList();
  for (final table in tables) {
    final reference = await list.first.rowsOf(table);
    for (final other in list.skip(1)) {
      expect(await other.rowsOf(table), reference,
          reason: '$table differs between ${list.first.name} and ${other.name}');
    }
  }
}
