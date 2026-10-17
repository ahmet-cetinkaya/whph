@Tags(['sim-smoke'])
library;

import 'package:test/test.dart';

import 'sim_env.dart';
import 'simulator.dart';

/// `sim-smoke`: 20 runs x 5 devices x 1,000 ops.
///
/// * The harness self-check runs the naive LWW-by-wall-clock replica and
///   passes only when the oracle catches it (proves the oracle can fail).
/// * The engine-under-test group asserts 0 violations. It is skipped while the
///   engine under test is not expected to be clean (T1: the naive replica);
///   `SIM_EXPECT_CLEAN=1` forces it, e.g. to print the naive failing seeds.
void main() {
  final seeds = suiteSeeds(smokeSuite);

  test('harness self-check: the oracle catches the naive replica', () async {
    final caught = <SimResult>[];
    for (final seed in seeds) {
      final result = await runSimulation(seed: seed, config: smokeSuite.config, engine: naiveEngine);
      if (!result.clean) caught.add(result);
    }
    print(
      '[sim-smoke self-check] naive replica caught in ${caught.length}/${seeds.length} runs; '
      'failing seeds: ${caught.map((r) => r.seed).join(', ')}',
    );
    if (caught.isNotEmpty) print(caught.first.report(tag: smokeSuite.tag));
    expect(caught, isNotEmpty, reason: 'the oracle must detect the naive replica in at least one smoke run');
  });

  final engine = engineUnderTest;
  group('engine under test (${engine.name})', () {
    for (final seed in seeds) {
      test('seed $seed', () async {
        final result = await runSimulation(seed: seed, config: smokeSuite.config, engine: engine);
        if (!result.clean) fail(result.report(tag: smokeSuite.tag));
      });
    }
  }, skip: expectEngineClean ? false : 'engine "${engine.name}" is not expected clean; set SIM_EXPECT_CLEAN=1 to run');
}
