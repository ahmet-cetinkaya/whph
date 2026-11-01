import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_connector.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_client.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// [ISyncPeerConnector] over the LAN client.
class LanSyncPeerConnector implements ISyncPeerConnector {
  final LanSyncClient _client;

  const LanSyncPeerConnector(this._client);

  @override
  Future<ISyncTransport> connect(String address, {required int port, bool forPairing = false}) =>
      _client.connect(address, port: port, forPairing: forPairing);
}
