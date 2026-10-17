// S4 spike code — replaced by lib/src/crypto in T11; not for production use.
//
// Throughput benchmark for the D7 per-change crypto path over the pure-Dart
// `cryptography` package: BLAKE2b-256 change hashes, one Ed25519 manifest
// signature per `manifestSize` changes, and XChaCha20-Poly1305 envelopes.
// Output is numbers only; no key material or plaintext is ever printed.

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// Benchmark parameters. [changes] is the end-to-end sample size; the result
/// projects linearly to [projectTo] changes.
class CryptoBenchConfig {
  const CryptoBenchConfig({
    this.changes = 20000,
    this.manifestSize = 1000,
    this.valueBytes = 200,
    this.adBytes = 120,
    this.canonicalOverheadBytes = 150,
    this.ed25519Ops = 100,
    this.hashOps = 20000,
    this.aeadSmallOps = 2000,
    this.aeadLargeOps = 64,
    this.projectTo = 200000,
  });

  final int changes;
  final int manifestSize;

  /// Size of the encrypted cell value (envelope plaintext).
  final int valueBytes;

  /// Envelope AD size (group, epoch, tbl, pk, col, hlc, origin, seq, cause, version).
  final int adBytes;

  /// Canonical change = value + this much metadata (group, tbl, pk, col, hlc, node, origin, seq, cause).
  final int canonicalOverheadBytes;
  final int ed25519Ops;
  final int hashOps;
  final int aeadSmallOps;
  final int aeadLargeOps;
  final int projectTo;
}

/// Benchmark results; [toLines] renders `[S4] key=value` lines.
class CryptoBenchResult {
  CryptoBenchResult(this.config, this.metrics);

  final CryptoBenchConfig config;
  final Map<String, num> metrics;

  List<String> toLines() => [
        for (final e in metrics.entries)
          '[S4] ${e.key}=${e.value is double ? (e.value as double).toStringAsFixed(3) : e.value}',
      ];
}

const DartBlake2b _blake2b256 = DartBlake2b(hashLengthInBytes: 32);
const DartXchacha20 _xchacha = DartXchacha20.poly1305Aead();
final DartEd25519 _ed25519 = DartEd25519(sha512: const DartSha512());

Uint8List _randomBytes(Random rng, int n) => Uint8List.fromList(List<int>.generate(n, (_) => rng.nextInt(256)));

double _perSecond(int ops, Stopwatch sw) => ops / (sw.elapsedMicroseconds / 1e6);

bool _equalBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Runs the primitive microbenchmarks and the end-to-end manifest pipeline.
Future<CryptoBenchResult> runCryptoBench([CryptoBenchConfig config = const CryptoBenchConfig()]) async {
  final metrics = <String, num>{};
  // Non-secret deterministic filler data; keys come from the secure RNG.
  final rng = Random(42);

  // --- Ed25519 sign / verify (64-byte message) -------------------------------
  final signingKey = await _ed25519.newKeyPair();
  final publicKey = await signingKey.extractPublicKey();
  final msg64 = _randomBytes(rng, 64);
  var sig = await _ed25519.sign(msg64, keyPair: signingKey);
  var sw = Stopwatch()..start();
  for (var i = 0; i < config.ed25519Ops; i++) {
    sig = await _ed25519.sign(msg64, keyPair: signingKey);
  }
  sw.stop();
  metrics['ed25519_sign_ops_per_s'] = _perSecond(config.ed25519Ops, sw);
  sw = Stopwatch()..start();
  for (var i = 0; i < config.ed25519Ops; i++) {
    if (!await _ed25519.verify(msg64, signature: sig)) throw StateError('verify failed');
  }
  sw.stop();
  metrics['ed25519_verify_ops_per_s'] = _perSecond(config.ed25519Ops, sw);

  // --- BLAKE2b-256 over one canonical change ---------------------------------
  final canonicalLen = config.valueBytes + config.canonicalOverheadBytes;
  final canonical = _randomBytes(rng, canonicalLen);
  sw = Stopwatch()..start();
  for (var i = 0; i < config.hashOps; i++) {
    _blake2b256.hashSync(canonical);
  }
  sw.stop();
  metrics['blake2b256_canonical_bytes'] = canonicalLen;
  metrics['blake2b256_hashes_per_s'] = _perSecond(config.hashOps, sw);

  // --- XChaCha20-Poly1305 bulk throughput -----------------------------------
  final aeadKey = SecretKeyData.random(length: 32);
  final ad = _randomBytes(rng, config.adBytes);
  for (final (label, size, ops) in [
    ('1kib', 1024, config.aeadSmallOps),
    ('64kib', 65536, config.aeadLargeOps),
  ]) {
    final plain = _randomBytes(rng, size);
    final nonce = _xchacha.newNonce();
    late SecretBox box;
    sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      box = _xchacha.encryptSync(plain, secretKey: aeadKey, nonce: nonce, aad: ad);
    }
    sw.stop();
    metrics['xchacha20poly1305_encrypt_${label}_mb_per_s'] = _perSecond(ops * size, sw) / 1e6;
    sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      _xchacha.decryptSync(box, secretKey: aeadKey, aad: ad);
    }
    sw.stop();
    metrics['xchacha20poly1305_decrypt_${label}_mb_per_s'] = _perSecond(ops * size, sw) / 1e6;
  }

  // Random 24-byte nonce generation (the default nonce source of encryptSync).
  sw = Stopwatch()..start();
  for (var i = 0; i < config.aeadSmallOps; i++) {
    _xchacha.newNonce();
  }
  sw.stop();
  metrics['xchacha20_random_nonces_per_s'] = _perSecond(config.aeadSmallOps, sw);

  // --- End-to-end: hash + sign manifests + encrypt; verify + hash + check + decrypt
  final n = config.changes;
  final groupId = _randomBytes(rng, 16);
  final originId = _randomBytes(rng, 16);
  final changes = List<Uint8List>.generate(n, (_) => _randomBytes(rng, canonicalLen));
  final ads = List<Uint8List>.generate(n, (_) => _randomBytes(rng, config.adBytes));

  final senderSw = Stopwatch()..start();
  final phase = Stopwatch()..start();
  final hashes = List<Uint8List>.filled(n, Uint8List(0));
  for (var i = 0; i < n; i++) {
    hashes[i] = Uint8List.fromList(_blake2b256.hashSync(changes[i]).bytes);
  }
  metrics['e2e_sender_hash_ms'] = _lap(phase);
  final manifests = <(int, int, Uint8List, Signature)>[];
  for (var from = 0; from < n; from += config.manifestSize) {
    final to = min(from + config.manifestSize, n);
    final body = _manifestBytes(groupId, originId, from, to, hashes);
    manifests.add((from, to, body, await _ed25519.sign(body, keyPair: signingKey)));
  }
  metrics['e2e_sender_sign_ms'] = _lap(phase);
  final envelopes = List<SecretBox?>.filled(n, null);
  for (var i = 0; i < n; i++) {
    // Envelope plaintext = the cell value (tail of the canonical bytes).
    final value = Uint8List.sublistView(changes[i], config.canonicalOverheadBytes);
    envelopes[i] = _xchacha.encryptSync(value, secretKey: aeadKey, aad: ads[i]);
  }
  senderSw.stop();
  metrics['e2e_sender_encrypt_ms'] = _lap(phase);

  final receiverSw = Stopwatch()..start();
  var verifyUs = 0;
  for (final (from, to, body, signature) in manifests) {
    final verifySw = Stopwatch()..start();
    final checked = Signature(signature.bytes, publicKey: publicKey);
    if (!await _ed25519.verify(body, signature: checked)) throw StateError('manifest verify failed');
    verifyUs += verifySw.elapsedMicroseconds;
    for (var i = from; i < to; i++) {
      final value = _xchacha.decryptSync(envelopes[i]!, secretKey: aeadKey, aad: ads[i]);
      final canonicalRebuilt = Uint8List(canonicalLen)
        ..setRange(0, config.canonicalOverheadBytes, changes[i])
        ..setRange(config.canonicalOverheadBytes, canonicalLen, value);
      final h = _blake2b256.hashSync(canonicalRebuilt).bytes;
      // Membership: the manifest lists the hash for every seq in (from, to].
      final offset = _manifestHeaderBytes + (i - from) * 32;
      if (!_equalBytes(h, Uint8List.sublistView(body, offset, offset + 32))) throw StateError('hash not in manifest');
    }
  }
  receiverSw.stop();
  metrics['e2e_receiver_verify_ms'] = verifyUs / 1000;
  metrics['e2e_receiver_decrypt_hash_check_ms'] = (receiverSw.elapsedMicroseconds - verifyUs) / 1000;

  final totalUs = senderSw.elapsedMicroseconds + receiverSw.elapsedMicroseconds;
  final perChangeUs = totalUs / n;
  metrics['e2e_changes'] = n;
  metrics['e2e_manifest_size'] = config.manifestSize;
  metrics['e2e_manifests'] = manifests.length;
  metrics['e2e_sender_ms'] = senderSw.elapsedMicroseconds / 1000;
  metrics['e2e_receiver_ms'] = receiverSw.elapsedMicroseconds / 1000;
  metrics['e2e_per_change_us'] = perChangeUs;
  metrics['projected_changes'] = config.projectTo;
  metrics['projected_seconds'] = perChangeUs * config.projectTo / 1e6;
  return CryptoBenchResult(config, metrics);
}

/// Returns the elapsed milliseconds since the last lap and restarts [sw].
double _lap(Stopwatch sw) {
  final ms = sw.elapsedMicroseconds / 1000;
  sw.reset();
  return ms;
}

const int _manifestHeaderBytes = 16 + 16 + 8 + 8;

/// Manifest signing input: group_id ‖ origin ‖ from_seq ‖ to_seq ‖ hashes.
Uint8List _manifestBytes(Uint8List groupId, Uint8List originId, int from, int to, List<Uint8List> hashes) {
  final out = Uint8List(_manifestHeaderBytes + (to - from) * 32);
  out.setRange(0, 16, groupId);
  out.setRange(16, 32, originId);
  final view = ByteData.sublistView(out);
  view.setUint64(32, from);
  view.setUint64(40, to);
  for (var i = from; i < to; i++) {
    out.setRange(_manifestHeaderBytes + (i - from) * 32, _manifestHeaderBytes + (i - from + 1) * 32, hashes[i]);
  }
  return out;
}
