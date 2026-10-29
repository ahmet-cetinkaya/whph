import 'dart:async';
import 'dart:io';

import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';
import 'package:whph/infrastructure/shared/features/sync/web_socket_sync_transport.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// Time allowed to open the WebSocket.
const Duration lanConnectTimeout = Duration(seconds: 5);

/// Runs the initiator side of one session on an open transport.
typedef SyncSessionRunner = Future<SessionResult> Function(ISyncTransport transport);

/// Client of the LAN sync server (D7): opens the WebSocket with the right
/// sub-protocol and hands the transport to the session engine.
class LanSyncClient {
  final Duration _connectTimeout;
  final Duration _firstFrameTimeout;
  final Duration _idleFrameTimeout;

  const LanSyncClient({
    Duration connectTimeout = lanConnectTimeout,
    Duration firstFrameTimeout = defaultFirstFrameTimeout,
    Duration idleFrameTimeout = defaultIdleFrameTimeout,
  })  : _connectTimeout = connectTimeout,
        _firstFrameTimeout = firstFrameTimeout,
        _idleFrameTimeout = idleFrameTimeout;

  /// Opens a transport to [host]:[port] for a sync session, or a pairing
  /// handshake when [forPairing] is set. Throws [SocketException],
  /// [WebSocketException] or [TimeoutException] when the peer is not reachable
  /// or refuses the connection.
  Future<ISyncTransport> connect(String host, {int port = lanSyncPort, bool forPairing = false}) async {
    final subprotocol = forPairing ? lanPairingSubprotocol : lanSyncSubprotocol;
    final socket = await WebSocket.connect(
      'ws://$host:$port',
      protocols: [subprotocol],
      compression: CompressionOptions.compressionOff,
    ).timeout(_connectTimeout);
    return WebSocketSyncTransport(socket, firstFrameTimeout: _firstFrameTimeout, idleFrameTimeout: _idleFrameTimeout);
  }

  /// Runs one session with the device at [host]:[port]. An unreachable or
  /// refusing peer ends as `failed(notReachable)`.
  Future<SessionResult> runSession(String host, SyncSessionRunner runner, {int port = lanSyncPort}) async {
    final ISyncTransport transport;
    try {
      transport = await connect(host, port: port);
    } on Object catch (error) {
      Logger.debug('LAN connect failed: ${error.runtimeType}', component: 'LanSyncClient');
      return SessionFailed(SessionStats(), null, SessionFailure.notReachable);
    }
    try {
      return await runner(transport);
    } finally {
      await transport.close();
    }
  }
}
