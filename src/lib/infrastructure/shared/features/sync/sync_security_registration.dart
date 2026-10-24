import 'dart:io';

import 'package:acore/acore.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_change_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_state_store.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_state_store.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/shared/features/sync/file_sync_key_store.dart';
import 'package:whph/infrastructure/shared/features/sync/sync_ledger_location.dart';

/// Registers the key store, peer state store and membership service (D7).
/// [dataDirectory] is the resolved application data directory (the key file
/// lives there; the ledger goes to the per-target state directory, U11).
/// Requires `registerSyncPersistence` to have run first. T23 wires this.
void registerSyncSecurity(IContainer container,
    {required Directory dataDirectory}) {
  final ledger = resolveSyncLedgerLocation(
    target: detectSyncPackagingTarget(Platform.environment),
    dataDirectory: dataDirectory,
    environment: Platform.environment,
  );
  container.registerSingleton<ISyncKeyStore>(
    (_) => FileSyncKeyStore(
        keyDirectory: dataDirectory, ledgerDirectory: ledger.directory),
  );
  container.registerSingleton<ISyncPeerStateStore>(
      (_) => DriftSyncPeerStateStore(AppDatabase.instance(container)));
  container.registerSingleton<SyncMembershipService>(
    (c) => SyncMembershipService(
      keyStore: c.resolve<ISyncKeyStore>(),
      changeStore: c.resolve<ISyncChangeStore>(),
      peerStateStore: c.resolve<ISyncPeerStateStore>(),
    ),
  );
}
