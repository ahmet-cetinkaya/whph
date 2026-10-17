@Tags(['sim-soak'])
library;

import 'package:test/test.dart';

import 'sim_env.dart';
import 'simulator.dart';

/// `sim-soak`: 1,000 runs x 5 devices x 10,000 ops, one test per seed so
/// `--total-shards/--shard-index` split the runs, e.g.
/// `fvm dart test --tags sim-soak --total-shards 16 --shard-index 0`.
///
/// Asserts 0 violations when the engine under test is expected clean (or with
/// `SIM_EXPECT_CLEAN=1`); otherwise it only reports violation counts.
void main() {
  final engine = engineUnderTest;
  final expectClean = expectEngineClean;
  for (final seed in suiteSeeds(soakSuite)) {
    test('soak seed $seed (${engine.name})', () async {
      final watch = Stopwatch()..start();
      final result = await runSimulation(seed: seed, config: soakSuite.config, engine: engine);
      print(
        '[sim-soak] engine=${engine.name} seed=$seed trace=${result.traceHash} '
        'violations=${result.violations.length} elapsedMs=${watch.elapsedMilliseconds}',
      );
      if (expectClean && !result.clean) fail(result.report(tag: soakSuite.tag));
    });
  }
}
