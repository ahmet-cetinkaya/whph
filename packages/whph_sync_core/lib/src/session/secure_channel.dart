/// Noise `XX` handshake over an [ISyncTransport] and chunked, encrypted
/// protocol frames (D7, T11 notes).
///
/// * Handshake messages 1 and 2 carry empty payloads; the initiator's D8
///   `Hello` travels in message 3 ([SecureChannel.handshake]).
/// * A Noise transport payload is at most [noiseMaxTransportPayload]
///   (65,519 B), while a protocol frame may reach [SyncLimits.maxFrameBytes]
///   (8 MiB). Each frame is therefore split into Noise messages whose
///   plaintext is `u8 more ‖ chunk` (`more` = 1 for every chunk but the last).
/// * Noise's strict nonce counter rejects a replayed, reordered or altered
///   message; the first failure tears the session down (FR-022).
/// * Sends are serialized (encryption order = wire order) so the reader and
///   writer tasks of a pipelined session can both send.
library;

import 'dart:async';
import 'dart:typed_data';

import '../crypto/noise.dart';
import '../crypto/primitives.dart';
import '../protocol/errors.dart';
import '../protocol/messages.dart';
import '../protocol/version.dart';
import 'transport.dart';

/// Largest chunk of a frame per Noise transport message.
const secureChunkBytes = noiseMaxTransportPayload - 1;

/// An authenticated, encrypted frame channel (after a completed handshake).
final class SecureChannel {
  SecureChannel._(this._noise, this._transport);

  final NoiseSession _noise;
  final ISyncTransport _transport;
  Future<void> _sendChain = Future.value();

  /// Protocol messages sent / received, by type (diagnostics).
  final Map<SyncMessageType, int> sent = {};
  final Map<SyncMessageType, int> received = {};

  /// Encrypted bytes sent.
  int bytesSent = 0;

  /// The peer's authenticated X25519 static key.
  Uint8List get remoteStatic => _noise.remoteStatic;

  /// Runs the `XX` handshake. The initiator sends [hello] in message 3; the
  /// responder returns it as the second element. [acceptRemoteStatic] is the
  /// membership check (reject only). Throws [NoiseException] or
  /// [TransportClosedException].
  static Future<(SecureChannel, Uint8List?)> handshake({
    required ISyncTransport transport,
    required bool initiator,
    required X25519KeyPair staticKey,
    required RemoteStaticCheck acceptRemoteStatic,
    Uint8List? hello,
  }) async {
    final hs = await NoiseHandshake.xx(
      initiator: initiator,
      staticKey: staticKey,
      acceptRemoteStatic: acceptRemoteStatic,
    );
    try {
      Uint8List? peerHello;
      if (initiator) {
        await transport.send(await hs.writeMessage());
        await hs.readMessage(await transport.receive());
        await transport.send(await hs.writeMessage(hello ?? Uint8List(0)));
      } else {
        await hs.readMessage(await transport.receive());
        await transport.send(await hs.writeMessage());
        peerHello = await hs.readMessage(await transport.receive());
      }
      return (SecureChannel._(hs.split(), transport), peerHello);
    } catch (_) {
      hs.close();
      rethrow;
    }
  }

  /// Encodes and sends [message] as one frame.
  Future<void> send(SyncMessage message) {
    final frame = SyncCodec.encode(message);
    sent[message.type] = (sent[message.type] ?? 0) + 1;
    return _sendChain = _sendChain.then((_) => _sendFrame(frame));
  }

  Future<void> _sendFrame(Uint8List frame) async {
    var offset = 0;
    do {
      final end = offset + secureChunkBytes < frame.length ? offset + secureChunkBytes : frame.length;
      final more = end < frame.length;
      final plain = Uint8List(1 + end - offset)
        ..[0] = more ? 1 : 0
        ..setRange(1, 1 + end - offset, frame, offset);
      final sealed = _noise.encrypt(plain);
      bytesSent += sealed.length;
      await _transport.send(sealed);
      offset = end;
    } while (offset < frame.length);
  }

  /// Receives and decodes the next frame. Throws [NoiseException] (tampered,
  /// replayed, reordered), [TransportClosedException] or a
  /// [SyncDecodeException] (malformed or oversized, FR-015).
  Future<SyncMessage> receive() async {
    final builder = BytesBuilder(copy: false);
    while (true) {
      final plain = _noise.decrypt(await _transport.receive());
      if (plain.isEmpty || plain[0] > 1) throw const MalformedMessageException('bad chunk header');
      builder.add(Uint8List.sublistView(plain, 1));
      if (builder.length > SyncLimits.maxFrameBytes) {
        throw FrameTooLargeException(builder.length, SyncLimits.maxFrameBytes);
      }
      if (plain[0] == 0) break;
    }
    final message = SyncCodec.decode(builder.takeBytes());
    received[message.type] = (received[message.type] ?? 0) + 1;
    return message;
  }

  /// Waits for queued sends, then closes the Noise session and the transport.
  Future<void> close() async {
    try {
      await _sendChain;
    } on Object {
      // The session is being torn down anyway.
    }
    _noise.close();
    await _transport.close();
  }

  /// Closes immediately (failure path).
  Future<void> abort() async {
    _noise.close();
    await _transport.close();
  }
}
