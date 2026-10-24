/// Selects the session engine for the engine tests and the simulator:
/// `SESSION_ENGINE=async` runs every session through `AsyncSyncSession` over
/// the in-memory async adapter (T22b), anything else through `SyncSession`.
library;

import 'dart:io';

import 'package:whph_sync_core/whph_sync_core.dart';

final bool useAsyncEngine = Platform.environment['SESSION_ENGINE'] == 'async';

final Expando<InMemoryAsyncSessionDevice> _adapters = Expando('async session device');

InMemoryAsyncSessionDevice _adapterOf(SyncDevice device) => _adapters[device] ??= InMemoryAsyncSessionDevice(device);

/// [SyncDevice.syncPair] through the selected engine.
Future<SessionPair> runSessionPair(
  SyncDevice a,
  SyncDevice b, {
  TransportFaults faults = TransportFaults.none,
  SessionHooks hooksA = const SessionHooks(),
  SessionHooks hooksB = const SessionHooks(),
  TransportTrace? trace,
  bool retryAfterRestore = true,
}) {
  if (!useAsyncEngine) {
    return SyncDevice.syncPair(a, b,
        faults: faults, hooksA: hooksA, hooksB: hooksB, trace: trace, retryAfterRestore: retryAfterRestore);
  }
  return InMemoryAsyncSessionDevice.syncPair(_adapterOf(a), _adapterOf(b),
      faults: faults, hooksA: hooksA, hooksB: hooksB, trace: trace, retryAfterRestore: retryAfterRestore);
}
