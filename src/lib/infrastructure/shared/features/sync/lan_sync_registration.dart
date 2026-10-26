import 'dart:io';

import 'package:acore/acore.dart';
import 'package:whph_sync_core/whph_sync_core.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_change_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_connector.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_runtime.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/core/application/features/sync/services/sync_ledger_mark_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';
import 'package:whph/core/application/features/sync/services/sync_runtime_service.dart';
import 'package:whph/core/application/features/sync/services/sync_scheduler.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_change_store.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/shared/features/sync/drift_async_session_device.dart';
import 'package:whph/infrastructure/shared/features/sync/drift_sync_session_host.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_client.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_peer_connector.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';
import 'package:whph/infrastructure/shared/features/sync/legacy_sync_responder.dart';
import 'package:whph/infrastructure/shared/features/sync/pairing_rate_limiter.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';

/// Registers the LAN transport, the session engine over the Drift store and
/// the sync runtime (server and scheduler). Needs `registerSyncPersistence`
/// and `registerSyncSecurity`. The sync identity must exist (the D14 startup
/// check creates it) before a session or a pairing runs.
void registerSyncTransport(IContainer container) {
  container.registerSingleton<LegacyDeviceRegistry>((_) => LegacyDeviceRegistry());
  container.registerSingleton<PairingRateLimiter>((_) => PairingRateLimiter());
  container.registerSingleton<LanSyncClient>((_) => const LanSyncClient());
  container.registerSingleton<ISyncPeerConnector>((c) => LanSyncPeerConnector(c.resolve<LanSyncClient>()));
  container.registerSingleton<DriftAsyncSyncStore>((c) => DriftAsyncSyncStore(c.resolve<DriftSyncChangeStore>()));
  container.registerSingleton<DriftAsyncSessionDevice>(
    (c) => DriftAsyncSessionDevice(
      membershipService: c.resolve<SyncMembershipService>(),
      keyStore: c.resolve<ISyncKeyStore>(),
      changeStore: c.resolve<ISyncChangeStore>(),
      store: c.resolve<DriftAsyncSyncStore>(),
      marks: c.resolve<SyncLedgerMarkService>(),
      startupCheck: c.resolve<SyncStartupCheckService>(),
    ),
  );
  container.registerSingleton<AsyncSessionDevice>((c) => c.resolve<DriftAsyncSessionDevice>());
  container.registerSingleton<ISyncSessionHost>(
    (c) => DriftSyncSessionHost(
      device: c.resolve<DriftAsyncSessionDevice>(),
      platform: Platform.operatingSystem,
      appVersion: AppInfo.version,
      onPair: c.resolve<SyncPairingService>().respond,
    ),
  );
  container.registerSingleton<LanSyncServer>(
    (c) => LanSyncServer(
      host: c.resolve<ISyncSessionHost>(),
      legacyRegistry: c.resolve<LegacyDeviceRegistry>(),
      pairingLimiter: c.resolve<PairingRateLimiter>(),
    ),
  );
  container.registerSingleton<ISyncServerControl>((c) => c.resolve<LanSyncServer>());
  container.registerSingleton<ISyncRuntime>(
    (c) => SyncRuntimeService(
      startupCheck: c.resolve<SyncStartupCheckService>(),
      membershipService: c.resolve<SyncMembershipService>(),
      server: c.resolve<ISyncServerControl>(),
      scheduler: c.resolve<SyncScheduler>(),
      deviceName: DeviceInfoHelper.getDeviceName,
      databaseCreatedThisLaunch: () => AppDatabase.createdThisLaunch,
      runServerOnStart: PlatformUtils.isDesktop,
    ),
  );
}
