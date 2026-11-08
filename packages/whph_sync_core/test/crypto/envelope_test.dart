// T11 acc 3: XChaCha20-Poly1305 envelopes with the D7 AD; nonce source.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'crypto_test_support.dart';

final _e1 = EpochId(1, 'member-a');
final _e2 = EpochId(2, 'member-b');

GroupKeyring _keyring() => GroupKeyring()
  ..add(_e1, testKey(21))
  ..add(_e2, testKey(22));

/// Copies [env] with some metadata replaced (a relabelling attack).
ChangeEnvelope _relabel(
  ChangeEnvelope env, {
  String? tbl,
  String? pk,
  String? col,
  int? hlc,
  OriginId? origin,
  int? originSeq,
  Object? cause = _keep,
  EpochId? epoch,
  List<int>? nonce,
  List<int>? ciphertext,
  int? protocolVersion,
}) =>
    ChangeEnvelope(
      tbl: tbl ?? env.tbl,
      pk: pk ?? env.pk,
      col: col ?? env.col,
      hlc: hlc ?? env.hlc,
      node: env.node,
      origin: origin ?? env.origin,
      originSeq: originSeq ?? env.originSeq,
      cause: identical(cause, _keep) ? env.cause : cause as RowRef?,
      epoch: epoch ?? env.epoch,
      nonce: nonce ?? env.nonce,
      ciphertext: ciphertext ?? env.ciphertext,
      protocolVersion: protocolVersion ?? env.protocolVersion,
    );

const _keep = Object();

void main() {
  late EnvelopeCipher cipher;
  late NonceSource nonces;

  setUp(() {
    cipher = EnvelopeCipher(groupId: testGroup, keyring: _keyring());
    nonces = NonceSource();
  });

  Matcher rejected() => isA<EnvelopeRejected>();

  test('seal/open round trip under the highest epoch; plaintext not visible', () {
    final change = testChange(value: StringValue('secret marker XYZ'));
    final env = cipher.seal(change, nonces);
    expect(env.epoch, _e2);
    expect(String.fromCharCodes(env.ciphertext), isNot(contains('secret marker')));
    final opened = cipher.open(env);
    expect(opened, isA<EnvelopeOpened>());
    expect((opened as EnvelopeOpened).change, change);
    // Wire round trip.
    expect((cipher.open(ChangeEnvelope.decode(env.encode())) as EnvelopeOpened).change, change);
  });

  test('all value kinds round-trip', () {
    for (final v in [const NullValue(), const IntValue(-5), StringValue(''), BytesValue(Uint8List(300))]) {
      final c = testChange(value: v);
      expect((cipher.open(cipher.seal(c, nonces)) as EnvelopeOpened).change, c);
    }
  });

  group('relabelling rejects', () {
    late ChangeEnvelope env;
    setUp(() => env = cipher.seal(testChange(cause: const RowRef('Task', 'task-0')), nonces));

    test('onto another tbl, pk or col', () {
      expect(cipher.open(_relabel(env, tbl: 'Note')), rejected());
      expect(cipher.open(_relabel(env, pk: 'task-2')), rejected());
      expect(cipher.open(_relabel(env, col: 'description')), rejected());
    });

    test('onto another hlc, origin or seq', () {
      expect(cipher.open(_relabel(env, hlc: env.hlc + 1)), rejected());
      expect(cipher.open(_relabel(env, origin: originOf(2))), rejected());
      expect(cipher.open(_relabel(env, originSeq: env.originSeq + 1)), rejected());
    });

    test('onto another held epoch', () {
      expect(cipher.open(_relabel(env, epoch: _e1)), rejected());
    });

    test('into another group (same keys)', () {
      final other = EnvelopeCipher(groupId: otherGroup, keyring: _keyring());
      expect(other.open(env), rejected());
    });

    test('under another protocol version (relabelled sealing version)', () {
      expect(env.protocolVersion, syncProtocolVersion);
      expect(cipher.open(_relabel(env, protocolVersion: syncProtocolVersion + 1)), rejected());
      expect(cipher.open(_relabel(env, protocolVersion: 1)), rejected());
    });

    test('altering, removing or adding cause', () {
      expect(cipher.open(_relabel(env, cause: const RowRef('Task', 'task-9'))), rejected());
      expect(cipher.open(_relabel(env, cause: const RowRef('Habit', 'task-0'))), rejected());
      expect(cipher.open(_relabel(env, cause: null)), rejected());
      final noCause = cipher.seal(testChange(), nonces);
      expect(cipher.open(_relabel(noCause, cause: const RowRef('Task', 'task-0'))), rejected());
    });

    test('altered ciphertext, tag or nonce', () {
      for (var i = 0; i < env.ciphertext.length; i++) {
        final ct = Uint8List.fromList(env.ciphertext)..[i] ^= 1;
        expect(cipher.open(_relabel(env, ciphertext: ct)), rejected(), reason: 'byte $i');
      }
      expect(cipher.open(_relabel(env, nonce: Uint8List.fromList(env.nonce)..[23] ^= 1)), rejected());
      expect(cipher.open(_relabel(env, ciphertext: env.ciphertext.sublist(0, 10))), rejected());
    });
  });

  group('L1: sealing protocol version travels with the envelope', () {
    test('an envelope sealed at v2 still opens after the receiver upgrades (relayed or held)', () {
      final env = cipher.seal(testChange(value: StringValue('held')), nonces);
      final held = ChangeEnvelope.decode(env.encode()); // e.g. sync_held_envelope
      expect(held.protocolVersion, syncProtocolVersion);
      final upgraded =
          EnvelopeCipher(groupId: testGroup, keyring: _keyring(), protocolVersion: syncProtocolVersion + 1);
      expect((upgraded.open(held) as EnvelopeOpened).change.value, StringValue('held'));
      // And the other way round: a newer sealer, an older opener.
      final newer = upgraded.seal(testChange(value: StringValue('new')), nonces);
      expect(newer.protocolVersion, syncProtocolVersion + 1);
      final relayed = ChangeEnvelope.decode(newer.encode());
      expect((cipher.open(relayed) as EnvelopeOpened).change.value, StringValue('new'));
      // The AD binds exactly the carried version.
      expect(relayed.associatedData(groupId: testGroup),
          relayed.associatedData(groupId: testGroup, protocolVersion: syncProtocolVersion + 1));
    });

    test('the wire form carries the version; 0 is rejected', () {
      final env = cipher.seal(testChange(), nonces);
      final bytes = env.encode();
      final flipped = _relabel(env, protocolVersion: 7).encode();
      expect(ChangeEnvelope.decode(flipped).protocolVersion, 7);
      expect(flipped.length, bytes.length);
      expect(() => _relabel(env, protocolVersion: 0), throwsRangeError);
    });
  });

  group('epoch keys', () {
    test('unknown epoch → typed MissingEpochKey (no exception, no key leak)', () {
      final env = cipher.seal(testChange(), nonces);
      final holdsOnlyE1 = EnvelopeCipher(groupId: testGroup, keyring: GroupKeyring()..add(_e1, testKey(21)));
      final r = holdsOnlyE1.open(env);
      expect(r, isA<MissingEpochKey>());
      expect((r as MissingEpochKey).epoch, _e2);
      expect(r.toString(), isNot(contains(toHex(testKey(22)))));
    });

    test('wrong key for a held epoch → rejected', () {
      final env = cipher.seal(testChange(), nonces);
      final wrong = EnvelopeCipher(
          groupId: testGroup,
          keyring: GroupKeyring()
            ..add(_e1, testKey(21))
            ..add(_e2, testKey(99)));
      expect(wrong.open(env), rejected());
    });

    test('sealing without any key or for another group throws', () {
      final empty = EnvelopeCipher(groupId: testGroup, keyring: GroupKeyring());
      expect(() => empty.seal(testChange(), nonces), throwsStateError);
      expect(() => cipher.seal(testChange(group: otherGroup), nonces), throwsArgumentError);
    });
  });

  group('NonceSource', () {
    test('24-byte nonces, one random prefix per source, strictly increasing counter', () {
      final a = NonceSource();
      final b = NonceSource();
      final seen = <String>{};
      for (var i = 0; i < 10000; i++) {
        final n = a.next();
        expect(n.length, 24);
        expect(seen.add(toHex(n)), isTrue);
        expect(ByteData.sublistView(n).getUint64(16), i);
      }
      final nb = b.next();
      expect(toHex(nb.sublist(0, 16)), isNot(toHex(a.next().sublist(0, 16))));
      expect(a.issued, 10001);
    });

    test('envelopes sealed in one batch never share a nonce', () {
      final seen = <String>{};
      for (var i = 1; i <= 1000; i++) {
        expect(seen.add(toHex(cipher.seal(testChange(seq: i), nonces).nonce)), isTrue);
      }
    });

    test('toString does not reveal the prefix', () {
      final n = NonceSource();
      final prefix = toHex(n.next().sublist(0, 16));
      expect(n.toString(), isNot(contains(prefix)));
    });
  });

  test('sealing 1,000 changes (nonce + AEAD) is fast (informational)', () {
    final changes = [for (var i = 1; i <= 1000; i++) testChange(seq: i, value: StringValue('x' * 200))];
    final sw = Stopwatch()..start();
    for (final c in changes) {
      cipher.seal(c, nonces);
    }
    sw.stop();
    // ignore: avoid_print
    print('[T11] seal 1,000 × 200 B envelopes: ${sw.elapsedMilliseconds} ms');
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}
