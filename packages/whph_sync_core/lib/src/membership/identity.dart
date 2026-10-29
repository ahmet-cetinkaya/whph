/// Device identity (D7) and the injectable source of random identifiers.
library;

import 'dart:math';
import 'dart:typed_data';

import '../crypto/primitives.dart';
import '../model/ids.dart';
import 'security_records.dart';

/// Source of random member, origin and group ids and key seeds.
///
/// Production passes nothing (`Random.secure()`); tests and the simulator
/// pass a seeded `Random` so every id is reproducible. Nonces and epoch keys
/// are drawn by the crypto layer from its own secure source; they never
/// influence control flow, so runs stay deterministic.
final class SyncIdSource {
  SyncIdSource([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  Uint8List bytes(int length) => Uint8List.fromList(List<int>.generate(length, (_) => _random.nextInt(256)));

  /// A random 128-bit member id as 32 lowercase hex characters.
  String memberId() => _hex(bytes(16));

  OriginId origin() => OriginId(bytes(Id128.length));

  GroupId group() => GroupId(bytes(Id128.length));

  /// A 32-byte private key seed (the caller zeroes it).
  Uint8List keySeed() => bytes(keyLength);

  static String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}

/// A device's member identity: member id, X25519 Noise static key and
/// Ed25519 signing key (key file content, D7).
final class DeviceIdentity {
  DeviceIdentity._(this.memberId, this.name, this.x25519, this.ed25519);

  /// Generates a fresh identity from [ids].
  static Future<DeviceIdentity> generate(SyncIdSource ids, {required String name}) async {
    final memberId = ids.memberId();
    final xs = ids.keySeed();
    final es = ids.keySeed();
    try {
      return DeviceIdentity._(
          memberId, name, await X25519KeyPair.fromPrivateKey(xs), await Ed25519KeyPair.fromSeed(es));
    } finally {
      zeroize(xs);
      zeroize(es);
    }
  }

  /// Rebuilds an identity from exported key material (key-file restore).
  static Future<DeviceIdentity> fromKeys({
    required String memberId,
    required String name,
    required List<int> x25519Private,
    required List<int> ed25519Seed,
  }) async =>
      DeviceIdentity._(
        memberId,
        name,
        await X25519KeyPair.fromPrivateKey(x25519Private),
        await Ed25519KeyPair.fromSeed(ed25519Seed),
      );

  final String memberId;
  final String name;
  final X25519KeyPair x25519;
  final Ed25519KeyPair ed25519;

  Uint8List get x25519Pub => x25519.publicKey;
  Uint8List get ed25519Pub => ed25519.publicKey;

  /// This device's `sync_member` entry.
  MemberEntry entry({required String addedBy}) =>
      MemberEntry(memberId: memberId, x25519Pub: x25519Pub, ed25519Pub: ed25519Pub, name: name, addedBy: addedBy);

  /// Zeroes both private keys.
  void destroy() {
    x25519.destroy();
    ed25519.destroy();
  }

  /// Member id only; never key bytes.
  @override
  String toString() => 'DeviceIdentity($memberId)';
}
