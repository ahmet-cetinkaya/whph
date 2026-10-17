@Tags(['sim-smoke'])
library;

import 'package:test/test.dart';

import 'sim_env.dart';
import 'simulator.dart';

/// A seed fully determines a run: replaying it gives the same trace hash.
/// Replays `SIM_SEED` when set, otherwise the first smoke seed.
void main() {
  final seed = replaySeed ?? smokeSuite.firstSeed;

  for (final engine in {naiveEngine, engineUnderTest}) {
    test('replaying seed $seed twice gives identical traces (${engine.name})', () async {
      final first = await runSimulation(seed: seed, config: smokeSuite.config, engine: engine);
      final second = await runSimulation(seed: seed, config: smokeSuite.config, engine: engine);
      print('[replay] engine=${engine.name} seed=$seed trace=${first.traceHash} / ${second.traceHash}');
      expect(second.traceHash, first.traceHash);
      expect(second.violations.map((v) => '$v'), first.violations.map((v) => '$v'));

      final other = await runSimulation(seed: seed + 1, config: smokeSuite.config, engine: engine);
      expect(other.traceHash, isNot(first.traceHash), reason: 'different seeds must produce different traces');
    });
  }
}
