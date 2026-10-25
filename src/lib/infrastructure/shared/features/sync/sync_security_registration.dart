import 'dart:io';

import 'package:acore/acore.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_change_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_state_store.dart';
import 'package:whph/core/application/features/sync/services/reset_local_data_service.dart';
import 'package:whph/core/application/features/sync/services/sync_ledger_mark_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_state_store.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/shared/features/sync/file_sync_key_store.dart';
import 'package:whph/infrastructure/shared/features/sync/sync_ledger_location.dart';

/// Registers the key store, peer state store and membership service (D7).
/// [dataDirectory] is the resolved application data directory (the key file
/// lives there; the ledger goes to the per-target state directory, U11).
/// Requires `registerSyncPersistence` to have run first. T23 wires this.
///
/// [ledgerDirectory] replaces the per-target state directory; only tests that
/// must not touch the user's real ledger set it.
void registerSyncSecurity(IContainer container,
    {required Directory dataDirectory, Directory? ledgerDirectory}) {
  final ledger = ledgerDirectory ??
      resolveSyncLedgerLocation(
        target: detectSyncPackagingTarget(Platform.environment),
        dataDirectory: dataDirectory,
        environment: Platform.environment,
      ).directory;
  container.registerSingleton<ISyncKeyStore>(
    (_) =>
        FileSyncKeyStore(keyDirectory: dataDirectory, ledgerDirectory: ledger),
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
  container.registerSingleton<SyncLedgerMarkService>(
    (c) => SyncLedgerMarkService(
      keyStore: c.resolve<ISyncKeyStore>(),
      changeStore: c.resolve<ISyncChangeStore>(),
    ),
  );
  container.registerSingleton<SyncStartupCheckService>(
    (c) => SyncStartupCheckService(
      membershipService: c.resolve<SyncMembershipService>(),
      keyStore: c.resolve<ISyncKeyStore>(),
      changeStore: c.resolve<ISyncChangeStore>(),
      marks: c.resolve<SyncLedgerMarkService>(),
    ),
  );
  container.registerSingleton<ResetLocalDataService>(
    (c) => ResetLocalDataService(
      keyStore: c.resolve<ISyncKeyStore>(),
      createPreResetBackup: () =>
          AppDatabase.instance(c).createPreResetBackup(),
      resetDatabase: (backup) =>
          AppDatabase.instance(c).resetDatabase(preResetBackup: backup),
    ),
  );
}
