/// The frame transport a sync session runs over (`ISyncTransport`, D19/§3.3)
/// and a deterministic in-memory implementation with fault injection.
///
/// A transport carries opaque frames (Noise handshake and transport
/// messages) in order between the two ends of one session. The LAN
/// WebSocket implementation is T22; the in-memory one here drives the engine
/// tests and the simulator. It uses no timers: every hand-off completes a
/// `Completer`, so a run is a deterministic sequence of microtasks.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

/// The transport was closed (by either end, or cut by a fault).
final class TransportClosedException implements Exception {
  const TransportClosedException([this.reason = 'closed']);

  final String reason;

  @override
  String toString() => 'TransportClosedException($reason)';
}

/// One end of an ordered, bidirectional frame channel.
abstract interface class ISyncTransport {
  /// Sends one frame. Throws [TransportClosedException] once closed.
  Future<void> send(Uint8List frame);

  /// The next inbound frame. Throws [TransportClosedException] when the
  /// channel is closed and every frame sent before the close was received.
  Future<Uint8List> receive();

  /// Closes this end. Frames already sent are still delivered to the peer.
  Future<void> close();

  bool get isClosed;
}

/// Faults injected by an in-memory link. Frame indexes count every frame
/// sent on the link, in send order, starting at 0 (both directions share
/// one counter).
final class TransportFaults {
  const TransportFaults({this.cutAfter, this.duplicate = const {}, this.reorder = const {}, this.tamper});

  /// No faults.
  static const none = TransportFaults();

  /// Cut the link once this many frames were sent: frames `0..cutAfter-1`
  /// are delivered, later sends fail and both ends see the link closed.
  final int? cutAfter;

  /// Frames delivered twice (a replay; Noise must reject the copy).
  final Set<int> duplicate;

  /// Frames delivered after the next frame of the same direction. When the
  /// sender sends nothing more within a bounded number of microtask turns
  /// (it waits for a reply), the held frame is delivered late instead, so a
  /// reorder never deadlocks a session.
  final Set<int> reorder;

  /// Replaces the bytes of a frame in transit (Noise must reject it).
  final Uint8List Function(int index, Uint8List frame)? tamper;

  @override
  String toString() => 'TransportFaults(cut=$cutAfter, dup=$duplicate, reorder=$reorder, '
      'tamper=${tamper != null})';
}

/// Counters of one in-memory link.
final class TransportTrace {
  /// Frames sent (all directions).
  int framesSent = 0;

  /// Frames delivered into an inbox (duplicates count twice).
  int framesDelivered = 0;
  int bytesSent = 0;

  /// Whether the link was cut by [TransportFaults.cutAfter].
  bool cut = false;

  @override
  String toString() => 'TransportTrace(sent=$framesSent, delivered=$framesDelivered, bytes=$bytesSent, cut=$cut)';
}

/// Creates connected in-memory transport pairs.
abstract final class InMemoryTransport {
  /// A connected pair `(initiator end, responder end)`.
  static (ISyncTransport, ISyncTransport) pair({
    TransportFaults faults = TransportFaults.none,
    TransportTrace? trace,
  }) {
    final link = _Link(faults, trace ?? TransportTrace());
    return (link.a, link.b);
  }
}

final class _Link {
  _Link(this.faults, this.trace) {
    a = _End(this);
    b = _End(this);
  }

  final TransportFaults faults;
  final TransportTrace trace;
  late final _End a;
  late final _End b;
  int _sent = 0;
  bool _cut = false;

  _End _other(_End end) => identical(end, a) ? b : a;

  void send(_End from, Uint8List frame) {
    if (_cut || from._closed) throw const TransportClosedException('send on a closed transport');
    final index = _sent++;
    final cutAfter = faults.cutAfter;
    if (cutAfter != null && index >= cutAfter) {
      _cut = true;
      trace.cut = true;
      a._peerClosed();
      b._peerClosed();
      a._closeLocal();
      b._closeLocal();
      throw const TransportClosedException('link cut');
    }
    trace
      ..framesSent += 1
      ..bytesSent += frame.length;
    final to = _other(from);
    final bytes = faults.tamper?.call(index, Uint8List.fromList(frame)) ?? Uint8List.fromList(frame);
    final copies = faults.duplicate.contains(index) ? 2 : 1;
    final held = from._reordered;
    if (faults.reorder.contains(index) && held == null) {
      final frame = _HeldFrame(bytes, copies);
      from._reordered = frame;
      _flushLater(from, frame, _reorderPatience);
      return;
    }
    for (var i = 0; i < copies; i++) {
      to._deliver(bytes);
    }
    if (held != null) {
      from._reordered = null;
      held.deliverTo(to);
    }
  }

  /// Microtask turns a reordered frame waits for a later frame to overtake it.
  static const _reorderPatience = 64;

  void _flushLater(_End from, _HeldFrame frame, int turns) {
    scheduleMicrotask(() {
      if (!identical(from._reordered, frame) || _cut) return;
      if (turns > 0) return _flushLater(from, frame, turns - 1);
      from._reordered = null;
      frame.deliverTo(_other(from));
    });
  }
}

final class _HeldFrame {
  _HeldFrame(this.bytes, this.copies);

  final Uint8List bytes;
  final int copies;

  void deliverTo(_End to) {
    for (var i = 0; i < copies; i++) {
      to._deliver(bytes);
    }
  }
}

final class _End implements ISyncTransport {
  _End(this._link);

  final _Link _link;
  final Queue<Uint8List> _inbox = Queue();
  Completer<Uint8List>? _waiting;
  bool _closed = false;
  bool _peerDone = false;
  _HeldFrame? _reordered;

  @override
  bool get isClosed => _closed;

  void _deliver(Uint8List frame) {
    if (_closed) return;
    _link.trace.framesDelivered++;
    final waiting = _waiting;
    if (waiting != null) {
      _waiting = null;
      waiting.complete(frame);
    } else {
      _inbox.add(frame);
    }
  }

  void _peerClosed() {
    _peerDone = true;
    final waiting = _waiting;
    if (waiting != null && _inbox.isEmpty) {
      _waiting = null;
      waiting.completeError(const TransportClosedException('peer closed'));
    }
  }

  void _closeLocal() {
    _closed = true;
    final waiting = _waiting;
    if (waiting != null) {
      _waiting = null;
      waiting.completeError(const TransportClosedException('closed'));
    }
  }

  @override
  Future<void> send(Uint8List frame) async => _link.send(this, frame);

  @override
  Future<Uint8List> receive() {
    if (_inbox.isNotEmpty) return Future.value(_inbox.removeFirst());
    if (_closed) return Future.error(const TransportClosedException('closed'));
    if (_peerDone) return Future.error(const TransportClosedException('peer closed'));
    if (_waiting != null) throw StateError('concurrent receive');
    return (_waiting = Completer<Uint8List>()).future;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    final held = _reordered;
    if (held != null && !_link._cut) {
      _reordered = null;
      held.deliverTo(_link._other(this));
    }
    _closeLocal();
    _link._other(this)._peerClosed();
  }
}
