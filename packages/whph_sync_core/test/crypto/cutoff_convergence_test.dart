// T11 acc 6: members holding different seqs of a revoked member's multiple
// origins end with identical accepted sets (1,000 schedules), using real
// signed revocation records, the max-merge cutoff and the self-extension rule.
import 'dart:math';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'crypto_test_support.dart';

late Ed25519KeyPair _x; // the member that gets revoked
late List<Ed25519KeyPair> _live;
late List<OriginId> _xOrigins;
late OriginRegistrySet _registry;
late MemberKeySet _members;

final class _Replica {
  _Replica(this.key) : revocations = RevocationSet(testGroup);

  final Ed25519KeyPair key;
  final RevocationSet revocations;

  /// Accepted prefix `1..held[o]` per origin of X.
  final Map<OriginId, int> held = {};

  bool get knowsRevocation => revocations.isRevoked(_x.publicKey);

  int heldOf(OriginId o) => held[o] ?? 0;

  /// Accepts X's seqs of [o] up to [upTo] (a prefix), limited by the cutoff.
  void receive(OriginId o, int upTo) {
    final cutoff = revocations.cutoffFor(o, _registry);
    final limit = cutoff == null ? upTo : min(upTo, cutoff);
    if (limit > heldOf(o)) held[o] = limit;
  }

  Future<void> selfExtend(List<RevocationRecord> published) async {
    final ext = revocations.selfExtension(_registry, heldOf);
    for (final e in ext.entries) {
      final r = await RevocationRecord.sign(groupId: testGroup, revokedPub: e.key, revoker: key, cutoffs: e.value);
      await revocations.merge([r], _members);
      published.add(r);
    }
  }

  String get signature => '${revocations.records.length}:${_xOrigins.map(heldOf).join(',')}';
}

/// A session between two live members: records first (and self-extension),
/// then changes of X's origins in both directions.
Future<void> _sync(_Replica a, _Replica b, List<RevocationRecord> published) async {
  final ra = a.revocations.records;
  final rb = b.revocations.records;
  await a.revocations.merge(rb, _members);
  await b.revocations.merge(ra, _members);
  await a.selfExtend(published);
  await b.selfExtend(published);
  for (final o in _xOrigins) {
    final ha = a.heldOf(o);
    final hb = b.heldOf(o);
    b.receive(o, ha);
    a.receive(o, hb);
  }
}

void main() {
  setUpAll(() async {
    _x = await Ed25519KeyPair.fromSeed(testKey(60));
    _live = [for (var i = 0; i < 4; i++) await Ed25519KeyPair.fromSeed(testKey(61 + i))];
    _xOrigins = [originOf(60), originOf(61), originOf(62)];
    _members = MemberKeySet([_x.publicKey, ..._live.map((k) => k.publicKey)]);
    _registry = OriginRegistrySet(testGroup, members: _members);
    await _registry.merge([
      for (final o in _xOrigins)
        await signOriginRegistration(groupId: testGroup, origin: o, member: _x, createdHlc: testHlc),
    ]);
  });

  test('1,000 schedules end with identical accepted sets (acc 6)', () async {
    final rng = Random(6060);
    var records = 0;
    var extensions = 0;
    for (var schedule = 0; schedule < 1000; schedule++) {
      final n = 2 + rng.nextInt(3); // 2..4 live members
      final replicas = [for (var i = 0; i < n; i++) _Replica(_live[i])];
      final published = <RevocationRecord>[];
      // X's own production per origin; members hold random prefixes of it
      // (some hold nothing of an origin, one origin may be unknown to all).
      final produced = {for (final o in _xOrigins) o: 5 + rng.nextInt(20)};
      for (final r in replicas) {
        for (final o in _xOrigins) {
          if (rng.nextInt(4) > 0) r.held[o] = rng.nextInt(produced[o]! + 1);
        }
      }

      var revoked = false;
      final steps = 4 + rng.nextInt(12);
      for (var s = 0; s < steps; s++) {
        final r = rng.nextInt(10);
        if (r < 2 || (!revoked && s == steps - 1)) {
          // A member revokes X listing the max seq it holds of each registered origin.
          final revoker = replicas[rng.nextInt(n)];
          final cutoffs = RevocationSet.initialCutoffs(_x.publicKey, _registry, revoker.heldOf);
          // Sometimes the revoker has not yet received one origin's registry
          // row: that origin is unlisted (cutoff 0 until someone extends).
          if (rng.nextInt(3) == 0) cutoffs.remove(_xOrigins[rng.nextInt(_xOrigins.length)]);
          final rec = await RevocationRecord.sign(
              groupId: testGroup, revokedPub: _x.publicKey, revoker: revoker.key, cutoffs: cutoffs);
          await revoker.revocations.merge([rec], _members);
          published.add(rec);
          revoked = true;
        } else if (r < 5) {
          // X keeps producing and pushes to a member that does not know yet.
          final target = replicas[rng.nextInt(n)];
          if (!target.knowsRevocation) {
            final o = _xOrigins[rng.nextInt(_xOrigins.length)];
            produced[o] = produced[o]! + 1 + rng.nextInt(5);
            target.receive(o, produced[o]!);
          }
        } else {
          final a = replicas[rng.nextInt(n)];
          final b = replicas[rng.nextInt(n)];
          if (!identical(a, b)) await _sync(a, b, published);
        }
      }

      // Anti-entropy among live members until quiescent.
      var rounds = 0;
      while (true) {
        final before = replicas.map((r) => r.signature).join('|');
        for (var i = 0; i < n; i++) {
          for (var j = i + 1; j < n; j++) {
            await _sync(replicas[i], replicas[j], published);
          }
        }
        if (replicas.map((r) => r.signature).join('|') == before) break;
        expect(++rounds, lessThan(20), reason: 'schedule $schedule does not quiesce');
      }

      final expected = {for (final o in _xOrigins) o: replicas.first.revocations.cutoffFor(o, _registry)};
      for (final r in replicas) {
        expect(r.knowsRevocation, isTrue);
        for (final o in _xOrigins) {
          final cutoff = r.revocations.cutoffFor(o, _registry);
          expect(cutoff, expected[o], reason: 'schedule $schedule: cutoff differs');
          // Accepted set = 1..cutoff on every member.
          expect(r.heldOf(o), cutoff, reason: 'schedule $schedule: accepted set differs');
          for (final seq in [cutoff!, cutoff + 1]) {
            expect(r.revocations.accepts(o, seq, _registry), seq <= cutoff);
          }
        }
      }
      records += published.length;
      extensions += published.where((p) => p.cutoffs.length < _xOrigins.length).length;
    }
    // ignore: avoid_print
    print('[T11] acc6: 1000 schedules converged; $records signed records ($extensions not listing every origin)');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
