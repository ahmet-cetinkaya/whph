/// ACF-45 / Efe stale-restore rulings, pinned by seed 100006: the two stale
/// clusters are excluded with evidence, stranded revocations are counted per
/// identity, and the run is deterministic. Slow (sim-soak tag).
@Tags(['sim-soak'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'sim_env.dart';
import 'simulator.dart';

void main() {
  test('stale clusters are excluded with evidence and stranded revocations counted (seed 100006)', () async {
    final first = await runSimulation(seed: 100006, config: soakSuite.config, engine: engineUnderTest);
    expect(first.violations, isEmpty, reason: first.report(tag: soakSuite.tag));
    final excluded = first.stats.counters['endgame.staleExcluded'] ?? 0;
    final stranded = first.stats.counters['endgame.revocationStrandedInStaleCluster'] ?? 0;
    expect(excluded, greaterThan(0), reason: 'the stale clusters must be excluded');
    expect(stranded, greaterThan(0), reason: 'the stranded-revoked identities must be counted');

    final second = await runSimulation(seed: 100006, config: soakSuite.config, engine: engineUnderTest);
    expect(second.traceHash, first.traceHash, reason: 'exclusion sets must be deterministic');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('a clean seed without stale restores stays clean and uses no exclusion (seed 100003)', () async {
    final result = await runSimulation(seed: 100003, config: soakSuite.config, engine: engineUnderTest);
    expect(result.violations, isEmpty, reason: result.report(tag: soakSuite.tag));
    expect(result.stats.counters['endgame.staleExcluded'] ?? 0, 0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('with the repair prompt disabled, stranding must surface as violations (seed 100160)', () async {
    // Negative control: run only when SIM_NO_REPAIR is set by the caller.
    if (Platform.environment['SIM_NO_REPAIR'] != '1') return;
    final result = await runSimulation(seed: 100160, config: soakSuite.config, engine: engineUnderTest);
    expect(result.violations, isNotEmpty, reason: 'disabling repair must not mask divergence');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
