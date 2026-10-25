import 'package:acore/acore.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_client.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';
import 'package:whph/infrastructure/shared/features/sync/legacy_sync_responder.dart';
import 'package:whph/infrastructure/shared/features/sync/pairing_rate_limiter.dart';

/// Registers the LAN transport: client, server and the legacy-device list.
/// The server needs an [ISyncSessionHost] in the container, which T23
/// provides; T23 also wires this function into the app container.
void registerSyncTransport(IContainer container) {
  container.registerSingleton<LegacyDeviceRegistry>((_) => LegacyDeviceRegistry());
  container.registerSingleton<PairingRateLimiter>((_) => PairingRateLimiter());
  container.registerSingleton<LanSyncClient>((_) => const LanSyncClient());
  container.registerSingleton<LanSyncServer>(
    (_) => LanSyncServer(
      host: container.resolve<ISyncSessionHost>(),
      legacyRegistry: container.resolve<LegacyDeviceRegistry>(),
      pairingLimiter: container.resolve<PairingRateLimiter>(),
    ),
  );
}
