/// ACF-45 / Efe stale-restore rulings, pinned by seed 100006: the two stale
/// clusters are excluded with evidence, stranded revocations are counted per
/// identity, and the run is deterministic. Slow (sim-soak tag).
@Tags(['sim-soak'])
library;

import 'dart:io';

import 'package:test/test.dart';
import '../session/session_engine_switch.dart';
import 'engine_simulation.dart';
import 'sim_env.dart';
import 'simulator.dart';

/// Seed 100006 with the post-key-loss re-invite off: the members stranded on a
/// lost-key device's sealed origin are never re-invited, which is what
/// produces the stale clusters this test pins.
Future<SimResult> _runStale() => EngineSimulation(
        100006, soakSuite.config, 'engine',
        tuning: const EngineSimTuning(reinviteAfterKeyLoss: false))
    .run();

void main() {
  _engineered();
  test(
      'stale clusters are excluded with evidence and stranded revocations counted (seed 100006)',
      () async {
    final first = await _runStale();
    expect(first.violations, isEmpty, reason: first.report(tag: soakSuite.tag));
    final excluded = first.stats.counters['endgame.staleExcluded'] ?? 0;
    final stranded =
        first.stats.counters['endgame.revocationStrandedInStaleCluster'] ?? 0;
    expect(excluded, greaterThan(0),
        reason: 'the stale clusters must be excluded');
    expect(stranded, greaterThan(0),
        reason: 'the stranded-revoked identities must be counted');
    // Efe guard (4): determinism extended to the 100336 ruling's counters.
    final relaxedWinners =
        first.stats.counters['endgame.staleClusterWinnerRelaxed'] ?? 0;
    final strandedMembers =
        first.stats.counters['endgame.memberRowStrandedInStaleCluster'] ?? 0;
    expect(relaxedWinners, greaterThan(0),
        reason: '100006 must exercise the carrier-reachability rule');
    expect(strandedMembers, greaterThan(0),
        reason: '100006 must exercise the member-row strand rule');

    final second = await _runStale();
    expect(second.traceHash, first.traceHash,
        reason: 'exclusion sets must be deterministic');
    // F2: the counters and per-run stats must match too, not just the hash.
    expect(second.stats.counters['endgame.staleExcluded'], excluded);
    expect(second.stats.counters['endgame.revocationStrandedInStaleCluster'],
        stranded);
    expect(second.stats.counters['endgame.staleClusterWinnerRelaxed'],
        relaxedWinners);
    expect(second.stats.counters['endgame.memberRowStrandedInStaleCluster'],
        strandedMembers);
  },
      skip: useAsyncEngine
          ? 'seed 100006 without the post-key-loss re-invite is schedule-dependent under the async engine; '
              'the engine-independent evidence is test/session/stale_cluster_engineered_test.dart'
          : false,
      timeout: const Timeout(Duration(minutes: 10)));

  test(
      'a clean seed without stale restores stays clean and uses no exclusion (seed 100003)',
      () async {
    final result = await runSimulation(
        seed: 100003, config: soakSuite.config, engine: engineUnderTest);
    expect(result.violations, isEmpty,
        reason: result.report(tag: soakSuite.tag));
    expect(result.stats.counters['endgame.staleExcluded'] ?? 0, 0);
    // Efe guard (3): no-relaxation control — with no exclusion, both 100336
    // ruling counters must stay zero.
    expect(result.stats.counters['endgame.staleClusterWinnerRelaxed'] ?? 0, 0);
    expect(
        result.stats.counters['endgame.memberRowStrandedInStaleCluster'] ?? 0,
        0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test(
      'with the repair prompt disabled, stranding must surface as violations (seed 100160)',
      () async {
    // Negative control: run only when SIM_NO_REPAIR is set by the caller.
    if (Platform.environment['SIM_NO_REPAIR'] != '1') return;
    final result = await runSimulation(
        seed: 100160, config: soakSuite.config, engine: engineUnderTest);
    expect(result.violations, isNotEmpty,
        reason: 'disabling repair must not mask divergence');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// Engineered tests for the two sneak-through guards (Efe tests 2 and 7).
/// They drive the pure decision core `decideStaleExclusion` directly: a
/// never-stale acceptor must block its cluster's exclusion, and the
/// stranded-revoked relaxation is keyed to excluded clusters only.
void _engineered() {
  group('decideStaleExclusion engineered cases', () {
    test('a never-stale acceptor inside the cluster blocks exclusion', () {
      // a,b,c stale and auth-fail with the outside d; b NEVER stale but
      // completes with a and c -> the cluster {a,b,c} is not excludable.
      final excluded = decideStaleExclusion(
        names: ['a', 'b', 'c', 'd'],
        stale: {'a': true, 'b': false, 'c': true, 'd': false},
        pairAuthFail: {
          'a|b': false,
          'a|c': false,
          'b|c': false,
          'a|d': true,
          'b|d': true,
          'c|d': true
        },
        authFailRounds: {'a': 5, 'b': 5, 'c': 5, 'd': 5},
        otherFailRounds: {'a': 0, 'b': 0, 'c': 0, 'd': 0},
      );
      expect(excluded, isEmpty,
          reason: 'the never-stale b keeps the cluster gated');
    });

    test('an all-stale cluster auth-failing everyone outside IS excluded', () {
      final excluded = decideStaleExclusion(
        names: ['a', 'b', 'c'],
        stale: {'a': true, 'b': true, 'c': false},
        pairAuthFail: {'a|b': false, 'a|c': true, 'b|c': true},
        authFailRounds: {'a': 5, 'b': 5, 'c': 5},
        otherFailRounds: {'a': 0, 'b': 0, 'c': 0},
      );
      expect(excluded, {'a', 'b'});
    });

    test('a genuinely-other failure inside the cluster blocks exclusion', () {
      final excluded = decideStaleExclusion(
        names: ['a', 'b', 'c'],
        stale: {'a': true, 'b': true, 'c': false},
        pairAuthFail: {'a|b': false, 'a|c': true, 'b|c': true},
        authFailRounds: {'a': 5, 'b': 5, 'c': 5},
        otherFailRounds: {'a': 1, 'b': 0, 'c': 0},
      );
      expect(excluded, isEmpty,
          reason: 'a non-auth failure keeps the divergence gated');
    });

    test(
        'stranded-revoked relaxation requires ALL holders inside the excluded cluster (7)',
        () {
      final relaxed = strandedRevokedPubs(
        excluded: {'d3', 'd4'},
        recordsByRevokedHex: {
          'aaaa': {'d4'}, // all holders excluded -> relaxed
          'bbbb': {'d4', 'd1'}, // one holder converged -> NOT relaxed
          'cccc': {'d1'}, // no holder excluded -> NOT relaxed
        },
      );
      expect(relaxed, {'aaaa'});
    });

    test('(a1) converged-authored winner on a shared id is never relaxed', () {
      final relaxed = unreachableClusterWinners(
        excluded: {'d3'},
        authorOfWrite: {10: 'd0', 11: 'd3'},
        convergedHeldWriteIds: {},
      );
      expect(relaxed, {11});
    });

    test(
        '(a2) a cluster-authored winner a converged device holds stays required',
        () {
      final relaxed = unreachableClusterWinners(
        excluded: {'d3'},
        authorOfWrite: {11: 'd3', 12: 'd3'},
        convergedHeldWriteIds: {12},
      );
      expect(relaxed, {11});
    });

    test(
        '(b1) an identity with a self- or converged-authored member row stays expected',
        () {
      final stranded = strandedMemberIdentities(
        excluded: {'d3', 'd4'},
        rowsByIdentity: {
          'm-d3': {
            'row-d3': {'d3'}
          }, // self-authored by excluded d3 -> still strands (all authors inside)
          'm-d4': {
            'row-d4': {'d3'}
          }, // authored inside cluster -> stranded
          'm-d1': {
            'row-d1': {'d1'}
          }, // converged-authored -> expected
        },
      );
      expect(stranded, {'m-d3', 'm-d4'});
    });

    test(
        '(b2) any-row weakening strands an identity that has a converged-authored row',
        () {
      // Strict EVERY rule: d4 has two rows, one converged-authored -> kept.
      final stranded = strandedMemberIdentities(
        excluded: {'d3', 'd4'},
        rowsByIdentity: {
          'd4': {
            'row-a': {'d3'}, // cluster-authored
            'row-b': {'d1'}, // converged-authored -> gates
          },
        },
      );
      expect(stranded, isEmpty);
    });

    test('whole set stale: reported, not excluded', () {
      var reported = 0;
      final excluded = decideStaleExclusion(
        names: ['a', 'b'],
        stale: {'a': true, 'b': true},
        pairAuthFail: {'a|b': false},
        authFailRounds: {'a': 5, 'b': 5},
        otherFailRounds: {'a': 0, 'b': 0},
        onWholeSetStale: (size) => reported = size,
      );
      expect(excluded, isEmpty);
      expect(reported, 2);
    });
  });
}
