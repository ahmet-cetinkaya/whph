/// Shared helpers for the T11 crypto tests. Keys here are deterministic,
/// public test data (never real secrets) and are never printed.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:whph_sync_core/whph_sync_core.dart';

Uint8List hex(String s) {
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String toHex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

List<Map<String, dynamic>> loadVectors(String fileName) {
  final json = jsonDecode(File('test/vectors/$fileName').readAsStringSync()) as Map<String, dynamic>;
  return (json['vectors'] as List).cast<Map<String, dynamic>>();
}

List<Uint8List> psksOf(Map<String, dynamic> v, String side) =>
    ((v['${side}_psks'] as List?) ?? const []).cast<String>().map(hex).toList();

/// Deterministic 32-byte test key material.
Uint8List testKey(int seed) => Uint8List.fromList(List<int>.generate(32, (i) => (seed * 31 + i * 7 + 1) & 0xff));

Future<X25519KeyPair> testStatic(int seed) => X25519KeyPair.fromPrivateKey(testKey(seed));

bool acceptAll(Uint8List _) => true;

/// A connected production-API `XX` or `XXpsk3` pair.
final class NoisePair {
  NoisePair(this.initiator, this.responder);

  final NoiseHandshake initiator;
  final NoiseHandshake responder;

  static Future<NoisePair> xx({
    int initSeed = 1,
    int respSeed = 2,
    RemoteStaticCheck? initAccepts,
    RemoteStaticCheck? respAccepts,
    List<int>? initPrologue,
    List<int>? respPrologue,
  }) async =>
      NoisePair(
        await NoiseHandshake.xx(
          initiator: true,
          staticKey: await testStatic(initSeed),
          acceptRemoteStatic: initAccepts ?? acceptAll,
          prologue: initPrologue,
        ),
        await NoiseHandshake.xx(
          initiator: false,
          staticKey: await testStatic(respSeed),
          acceptRemoteStatic: respAccepts ?? acceptAll,
          prologue: respPrologue,
        ),
      );

  /// `XXpsk3` with the scanner (initiator) expecting responder [expectSeed].
  static Future<NoisePair> xxPsk3({
    required List<int> initToken,
    List<int>? respToken,
    int initSeed = 1,
    int respSeed = 2,
    int? expectSeed,
  }) async {
    final respStatic = await testStatic(respSeed);
    final expected = await testStatic(expectSeed ?? respSeed);
    return NoisePair(
      await NoiseHandshake.xxPsk3(
        initiator: true,
        staticKey: await testStatic(initSeed),
        psk: derivePairingPsk(initToken),
        expectedResponderFingerprint: x25519Fingerprint(expected.publicKey),
      ),
      await NoiseHandshake.xxPsk3(
        initiator: false,
        staticKey: respStatic,
        psk: derivePairingPsk(respToken ?? initToken),
      ),
    );
  }

  /// Runs the three handshake messages (empty payloads on 1–2, [payload3]
  /// on 3); [tamper] may rewrite message `index` in flight.
  Future<void> run({
    Uint8List Function(int index, Uint8List message)? tamper,
    List<int> payload3 = const [0xAA, 0xBB],
  }) async {
    for (var i = 0; i < 3; i++) {
      final sender = i.isEven ? initiator : responder;
      final receiver = i.isEven ? responder : initiator;
      var msg = await sender.writeMessage(i == 2 ? payload3 : const []);
      if (tamper != null) msg = tamper(i, msg);
      await receiver.readMessage(msg);
    }
  }

  Future<(NoiseSession, NoiseSession)> runAndSplit() async {
    await run();
    return (initiator.split(), responder.split());
  }
}

// --- Change fixtures -------------------------------------------------------------

final testGroup = GroupId.fromHex('00112233445566778899aabbccddeeff');
final otherGroup = GroupId.fromHex('ffeeddccbbaa99887766554433221100');
final testHlc = Hlc.pack(1790000000000, 7);

OriginId originOf(int n) => OriginId(List<int>.generate(16, (i) => (n * 13 + i) & 0xff));

Change testChange({
  GroupId? group,
  OriginId? origin,
  int seq = 1,
  String tbl = 'Task',
  String pk = 'task-1',
  String col = 'title',
  ChangeValue? value,
  RowRef? cause,
  String node = 'member-a',
}) =>
    Change(
      groupId: group ?? testGroup,
      tbl: tbl,
      pk: pk,
      col: col,
      value: value ?? StringValue('value $seq'),
      hlc: testHlc + seq,
      node: node,
      origin: origin ?? originOf(1),
      originSeq: seq,
      cause: cause,
    );
