import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:whph_sync_core/whph_sync_core.dart';

/// Waiting time for the first frame of a connection (handshake timeout, D7).
const Duration defaultFirstFrameTimeout = Duration(seconds: 10);

/// Waiting time for any later frame (idle timeout).
const Duration defaultIdleFrameTimeout = Duration(seconds: 90);

/// [ISyncTransport] over a `dart:io` [WebSocket]: one binary message per
/// frame (Noise messages, D7). Text messages are protocol violations and
/// close the connection. The socket delivers messages in order; this class
/// queues them so a slow reader never loses a frame.
class WebSocketSyncTransport implements ISyncTransport {
  final WebSocket _socket;
  final Duration _firstFrameTimeout;
  final Duration _idleFrameTimeout;
  final Queue<Uint8List> _inbox = Queue();
  final Queue<Completer<Uint8List>> _waiting = Queue();
  late final StreamSubscription<dynamic> _subscription;
  bool _closed = false;
  bool _remoteDone = false;
  int _framesReceived = 0;

  WebSocketSyncTransport(
    this._socket, {
    Duration firstFrameTimeout = defaultFirstFrameTimeout,
    Duration idleFrameTimeout = defaultIdleFrameTimeout,
  })  : _firstFrameTimeout = firstFrameTimeout,
        _idleFrameTimeout = idleFrameTimeout {
    _subscription = _socket.listen(_onMessage, onDone: _onRemoteDone, onError: (_) => _onRemoteDone());
  }

  @override
  bool get isClosed => _closed;

  @override
  Future<void> send(Uint8List frame) async {
    if (_closed) throw const TransportClosedException();
    try {
      _socket.add(frame);
    } on Object {
      await close();
      throw const TransportClosedException('send failed');
    }
  }

  @override
  Future<Uint8List> receive() async {
    if (_inbox.isNotEmpty) return _inbox.removeFirst();
    if (_closed || _remoteDone) throw const TransportClosedException();
    final waiter = Completer<Uint8List>();
    _waiting.add(waiter);
    final timeout = _framesReceived == 0 ? _firstFrameTimeout : _idleFrameTimeout;
    return waiter.future.timeout(timeout, onTimeout: () {
      _waiting.remove(waiter);
      unawaited(close());
      throw const TransportClosedException('timeout');
    });
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _failWaiters();
    try {
      // The subscription stays active until the close handshake ends; a
      // cancelled one would leave the socket waiting for the peer's reply.
      await _socket.close();
    } on Object {
      // The peer is already gone; closing is best effort.
    }
    unawaited(_subscription.cancel());
  }

  void _onMessage(dynamic message) {
    if (message is! List<int> || message.length > noiseMaxMessageLength) {
      unawaited(close());
      return;
    }
    _framesReceived++;
    final frame = Uint8List.fromList(message);
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete(frame);
    } else {
      _inbox.add(frame);
    }
  }

  void _onRemoteDone() {
    _remoteDone = true;
    _failWaiters();
  }

  void _failWaiters() {
    while (_waiting.isNotEmpty) {
      _waiting.removeFirst().completeError(const TransportClosedException());
    }
  }
}
