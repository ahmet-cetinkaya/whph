import 'dart:async';
import 'dart:io';

import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/utils/network_utils.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_connection_limits.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/infrastructure/shared/features/sync/legacy_sync_responder.dart';
import 'package:whph/infrastructure/shared/features/sync/pairing_rate_limiter.dart';
import 'package:whph/infrastructure/shared/features/sync/web_socket_sync_transport.dart';

/// TCP port of the LAN sync server.
const int lanSyncPort = 44040;

/// WebSocket sub-protocol of an authenticated sync session (Noise `XX`).
const String lanSyncSubprotocol = 'whph-sync.1';

/// WebSocket sub-protocol of a QR pairing handshake (Noise `XXpsk3`).
const String lanPairingSubprotocol = 'whph-pair.1';

/// Idle time after which a legacy text connection is closed.
const Duration legacyIdleTimeout = Duration(minutes: 5);

const String _component = 'LanSyncServer';

/// Consolidated LAN server (D7, D10): one WebSocket listener for sync
/// sessions, pairing handshakes and the legacy v0.24.3 responder.
///
/// Start and stop are the desktop server toggle (PB-6): a stopped server does
/// not listen, so a connection attempt is refused by the OS.
class LanSyncServer {
  final ISyncSessionHost _host;
  final LegacySyncResponder _legacyResponder;
  final PairingRateLimiter _pairingLimiter;
  final LanConnectionLimits _limits;
  final int _requestedPort;
  final InternetAddress _bindAddress;
  final bool Function(String address) _isAllowedSource;
  final Duration _firstFrameTimeout;
  final Duration _idleFrameTimeout;
  final Set<WebSocket> _sockets = {};
  HttpServer? _server;

  LanSyncServer({
    required ISyncSessionHost host,
    LegacyDeviceRegistry? legacyRegistry,
    PairingRateLimiter? pairingLimiter,
    LanConnectionLimits? limits,
    int port = lanSyncPort,
    InternetAddress? bindAddress,
    bool Function(String address)? isAllowedSource,
    Duration firstFrameTimeout = defaultFirstFrameTimeout,
    Duration idleFrameTimeout = defaultIdleFrameTimeout,
  })  : _host = host,
        _legacyResponder = LegacySyncResponder(
          presence: host.presence,
          registry: legacyRegistry ?? LegacyDeviceRegistry(),
        ),
        _pairingLimiter = pairingLimiter ?? PairingRateLimiter(),
        _limits = limits ?? LanConnectionLimits(),
        _requestedPort = port,
        _bindAddress = bindAddress ?? InternetAddress.anyIPv4,
        _isAllowedSource = isAllowedSource ?? NetworkUtils.isPrivateIP,
        _firstFrameTimeout = firstFrameTimeout,
        _idleFrameTimeout = idleFrameTimeout;

  bool get isRunning => _server != null;

  /// The bound port; `null` while stopped.
  int? get port => _server?.port;

  int get activeConnectionCount => _limits.activeCount;

  /// Starts listening. Returns `false` when the port cannot be bound.
  Future<bool> start() async {
    if (_server != null) return true;
    try {
      final server = await HttpServer.bind(_bindAddress, _requestedPort);
      _server = server;
      unawaited(_serve(server));
      Logger.info('LAN sync server listening on port ${server.port}', component: _component);
      return true;
    } on SocketException catch (error) {
      Logger.warning('LAN sync server could not start: ${error.message}', component: _component);
      return false;
    }
  }

  /// Stops listening and closes every open connection.
  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
    for (final socket in _sockets.toList()) {
      await socket.close(WebSocketStatus.goingAway);
    }
    _sockets.clear();
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handleRequest(request));
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final source = request.connectionInfo?.remoteAddress.address ?? '';
    if (!_isAllowedSource(source)) return _refuse(request, HttpStatus.forbidden);
    if (!WebSocketTransformer.isUpgradeRequest(request)) return _refuse(request, HttpStatus.upgradeRequired);
    final protocol = _requestedProtocol(request);
    if (protocol == lanPairingSubprotocol && !_pairingAdmitted(source)) {
      return _refuse(request, HttpStatus.tooManyRequests);
    }
    if (!_limits.tryAdmit(source)) return _refuse(request, HttpStatus.serviceUnavailable);
    try {
      final socket = await WebSocketTransformer.upgrade(
        request,
        protocolSelector: protocol == null ? null : (_) => protocol,
        // Noise frames do not compress, and a compressed capture would hide
        // the plaintext of the SC-004 control.
        compression: CompressionOptions.compressionOff,
      );
      _sockets.add(socket);
      try {
        await _serveSocket(socket, protocol, source);
      } finally {
        _sockets.remove(socket);
      }
    } on Object catch (error) {
      Logger.debug('LAN connection ended: ${error.runtimeType}', component: _component);
    } finally {
      _limits.release(source);
    }
  }

  bool _pairingAdmitted(String source) => _pairingLimiter.tryAcquire(source);

  String? _requestedProtocol(HttpRequest request) {
    final offered = request.headers['sec-websocket-protocol']?.expand((v) => v.split(',')).map((v) => v.trim()) ?? [];
    for (final protocol in [lanSyncSubprotocol, lanPairingSubprotocol]) {
      if (offered.contains(protocol)) return protocol;
    }
    return null;
  }

  Future<void> _refuse(HttpRequest request, int status) async {
    request.response.statusCode = status;
    await request.response.close();
  }

  Future<void> _serveSocket(WebSocket socket, String? protocol, String source) async {
    if (protocol == null) return _serveLegacy(socket, source);
    final transport = WebSocketSyncTransport(
      socket,
      firstFrameTimeout: _firstFrameTimeout,
      idleFrameTimeout: _idleFrameTimeout,
    );
    try {
      if (protocol == lanPairingSubprotocol) {
        await _host.pair(transport, source);
      } else {
        final result = await _host.respond(transport, source);
        Logger.debug('LAN session ended: ${result.runtimeType}', component: _component);
      }
    } finally {
      await transport.close();
    }
  }

  Future<void> _serveLegacy(WebSocket socket, String source) async {
    var pending = Future<void>.value();
    final done = Completer<void>();
    final idle = _IdleTimer(legacyIdleTimeout, () => socket.close(WebSocketStatus.normalClosure));
    socket.listen(
      (message) {
        idle.touch();
        pending = pending.then((_) => _answerLegacy(socket, message, source));
      },
      onDone: () => unawaited(pending.whenComplete(_completeOnce(done))),
      onError: (_) => _completeOnce(done)(),
      cancelOnError: true,
    );
    try {
      await done.future;
    } finally {
      idle.cancel();
    }
  }

  void Function() _completeOnce(Completer<void> completer) => () => completer.isCompleted ? null : completer.complete();

  Future<void> _answerLegacy(WebSocket socket, Object? message, String source) async {
    if (message is! String) return socket.close(WebSocketStatus.unsupportedData);
    final reply = await _legacyResponder.handle(message, source: source);
    if (reply != null && socket.readyState == WebSocket.open) socket.add(reply);
  }
}

class _IdleTimer {
  final Duration _limit;
  final void Function() _onIdle;
  Timer? _timer;

  _IdleTimer(this._limit, this._onIdle) {
    touch();
  }

  void touch() {
    _timer?.cancel();
    _timer = Timer(_limit, _onIdle);
  }

  void cancel() => _timer?.cancel();
}
