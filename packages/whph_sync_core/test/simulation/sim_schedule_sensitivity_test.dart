@Tags(['sim-diagnostic'])
library;

import 'package:test/test.dart';

import 'engine_simulation.dart';
import 'simulator.dart';

/// Non-gating diagnostic: seed 100006 (the engineered stale-cluster seed) is
/// schedule dependent. When the invite row of a member stays unsent on a
/// sealed origin (its inviter lost its key), the peers that never received it
/// cannot verify that member's changes, which stay held as unverified. Whether
/// the run reaches that state depends on which sessions complete before a
/// transport fault, not on the engine: the synchronous engine passes the seed
/// as is and fails it after the perturbations below (each shifts the random
/// stream from one step on), exactly like `SESSION_ENGINE=async` does as is.
///
/// Violations are printed, never asserted; the test fails only on a crash.
/// Run with `-P sim-diagnostic` (about 80 s per run).
const _seed = 100006;
const _config = SimConfig(devices: 5, ops: 10000);
const _perturbedSteps = [3957, 3970];

void main() {
  test(
      'seed $_seed outcome depends on the schedule (violations reported, never asserted)',
      () async {
    for (final step in _perturbedSteps) {
      final tuning = EngineSimTuning(perturbAtStep: step);
      final result =
          await EngineSimulation(_seed, _config, 'engine', tuning: tuning)
              .run();
      print(
          '[sim-diagnostic] schedule seed=$_seed perturbAtStep=$step violations=${result.violations.length}');
    }
  });
}
