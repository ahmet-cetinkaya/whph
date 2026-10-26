// A real device for the async session engine: Drift database, file key store,
// membership service and the Drift-backed session device and host (T22e).
import 'dart:io';

import 'package:whph/core/application/features/sync/services/sync_ledger_mark_service.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_change_store.dart';
import 'package:whph/infrastructure/shared/features/sync/drift_async_session_device.dart';
import 'package:whph/infrastructure/shared/features/sync/drift_sync_session_host.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'sync_security_test_support.dart';

const String _testPlatform = 'linux';
const String _testAppVersion = '9.9.9';

class DriftEngineDevice {
  final SecurityDevice security;
  final DriftAsyncSessionDevice device;
  final DriftSyncSessionHost host;

  DriftEngineDevice._(this.security, this.device, this.host);

  static Future<DriftEngineDevice> open(String name, Directory parent,
      {int Function()? nowMs,
      SessionHooks hooks = const SessionHooks(),
      DriftAsyncSyncStore? store}) async {
    final security = await SecurityDevice.open(name, parent);
    return DriftEngineDevice.over(security, nowMs: nowMs, hooks: hooks, store: store);
  }

  factory DriftEngineDevice.over(SecurityDevice security,
      {int Function()? nowMs, SessionHooks hooks = const SessionHooks(), DriftAsyncSyncStore? store}) {
    final marks = SyncLedgerMarkService(
        keyStore: security.keyStore,
        changeStore: security.database.store,
        delay: (_) async {});
    final startupCheck = SyncStartupCheckService(
        membershipService: security.service,
        keyStore: security.keyStore,
        changeStore: security.database.store,
        marks: marks);
    final device = DriftAsyncSessionDevice(
      membershipService: security.service,
      keyStore: security.keyStore,
      changeStore: security.database.store,
      store: store ?? DriftAsyncSyncStore(security.database.store),
      marks: marks,
      startupCheck: startupCheck,
      config: SyncEngineConfig(delay: (_) async {}),
      nowMs: nowMs,
    );
    final host = DriftSyncSessionHost(
        device: device,
        platform: _testPlatform,
        appVersion: _testAppVersion,
        hooks: hooks);
    return DriftEngineDevice._(security, device, host);
  }

  String get memberId => security.membership.memberId;

  Future<SessionResult> initiate(ISyncTransport transport, String peer) =>
      host.initiate(transport, peer);

  Future<SessionResult> respond(ISyncTransport transport) =>
      host.respond(transport, 'test');

  Future<void> close() => security.close();
}

/// Writes [count] note rows whose titles each carry a unique marker; returns
/// the markers.
Future<List<String>> seedNoteMarkers(SecurityDevice device, int count,
    {String prefix = 'MARKER'}) async {
  final markers = <String>[];
  for (var i = 0; i < count; i++) {
    final marker = '$prefix-${i.toString().padLeft(3, '0')}-secret-title';
    markers.add(marker);
    await device.database.insertNote('$prefix-row-$i', marker);
  }
  return markers;
}
