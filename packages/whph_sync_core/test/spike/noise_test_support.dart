// S4 spike test helpers (vector loading, hex, handshake driver).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:whph_sync_core/spike.dart';

Uint8List hex(String s) {
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

List<Map<String, dynamic>> loadVectors(String fileName) {
  final json = jsonDecode(File('test/vectors/$fileName').readAsStringSync()) as Map<String, dynamic>;
  return (json['vectors'] as List).cast<Map<String, dynamic>>();
}

List<Uint8List> psksOf(Map<String, dynamic> v, String side) =>
    ((v['${side}_psks'] as List?) ?? const []).cast<String>().map(hex).toList();

/// Deterministic, non-secret test keys (never printed).
Uint8List testKey(int seed) => Uint8List.fromList(List<int>.generate(32, (i) => (seed * 31 + i * 7 + 1) & 0xff));

/// A connected initiator/responder pair.
class HandshakePair {
  HandshakePair(this.initiator, this.responder);

  final NoiseXxHandshake initiator;
  final NoiseXxHandshake responder;

  static Future<HandshakePair> create(
    String protocol, {
    List<List<int>> initPsks = const [],
    List<List<int>>? respPsks,
    List<int>? initStatic,
    List<int>? respStatic,
    List<int>? initExpectsRemote,
    List<int>? respExpectsRemote,
  }) async {
    return HandshakePair(
      await NoiseXxHandshake.create(
        protocolName: protocol,
        initiator: true,
        staticPrivate: initStatic ?? testKey(1),
        prologue: const [1, 2, 3],
        psks: initPsks,
        expectedRemoteStatic: initExpectsRemote,
      ),
      await NoiseXxHandshake.create(
        protocolName: protocol,
        initiator: false,
        staticPrivate: respStatic ?? testKey(2),
        prologue: const [1, 2, 3],
        psks: respPsks ?? initPsks,
        expectedRemoteStatic: respExpectsRemote,
      ),
    );
  }

  /// Runs the three XX messages; [tamper] may rewrite message `index` in flight.
  Future<void> run({Uint8List Function(int index, Uint8List message)? tamper}) async {
    for (var i = 0; i < 3; i++) {
      final sender = i.isEven ? initiator : responder;
      final receiver = i.isEven ? responder : initiator;
      var msg = await sender.writeMessage(const [0xAA, 0xBB]);
      if (tamper != null) msg = tamper(i, msg);
      await receiver.readMessage(msg);
    }
  }
}

/// Public key of an X25519 private key.
Future<Uint8List> x25519Public(List<int> privateKey) async {
  final pair = await const DartX25519().newKeyPairFromSeed(privateKey);
  return Uint8List.fromList((await pair.extractPublicKey()).bytes);
}
