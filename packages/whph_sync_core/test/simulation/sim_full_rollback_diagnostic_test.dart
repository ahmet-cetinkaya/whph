@Tags(['sim-diagnostic'])
library;

import 'package:test/test.dart';

import 'engine_simulation.dart';
import 'simulator.dart';

/// Non-gating diagnostic: DB, key file and sync ledger rolled back together
/// (e.g. a home-folder snapshot) cannot be detected locally (U11 accepted
/// residual risk), so oracle violations are printed and never fail the test.
///
/// The test fails only when a run throws: that is a harness or engine crash,
/// not a convergence finding. It carries its own tag, never `sim-smoke` or
/// `sim-soak`, and is skipped unless run with `-P sim-diagnostic`.
const _seeds = [7001, 7002, 7003, 7004, 7005];
const _config = SimConfig(devices: 5, ops: 1000);
const _tuning = EngineSimTuning(dirSnapshotProbability: 0.01, fullRollbackProbability: 0.005);

void main() {
  test('full rollback diagnostic (violations reported, never asserted)', () async {
    var totalViolations = 0;
    for (final seed in _seeds) {
      final result = await EngineSimulation(seed, _config, 'engine', tuning: _tuning).run();
      totalViolations += result.violations.length;
      print(
        '[sim-diagnostic] full rollback seed=$seed violations=${result.violations.length} '
        'rollbacks=${result.stats.counters['op.fullRollback'] ?? 0}',
      );
    }
    print('[sim-diagnostic] total violations across ${_seeds.length} seeds: $totalViolations (not asserted)');
  });
}
