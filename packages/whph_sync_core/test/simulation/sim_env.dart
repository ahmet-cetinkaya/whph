/// Engine selection and environment switches of the convergence simulator.
///
/// * `SIM_SEED=<n>`: run only seed `n` (smoke, soak and replay suites).
/// * `SIM_ENGINE=<name>`: the replica under test; one of [simEngines].
/// * `SIM_EXPECT_CLEAN=1`: assert 0 violations for the engine under test even
///   when it is not expected to be correct (e.g. to watch the naive replica
///   fail with its reproducing seeds).
/// * `SIM_LOG=1`: print the real-engine driver's diagnostics (destructive and
///   membership events, unexpected session outcomes, final membership views,
///   held envelopes); combine with `SIM_SEED`.
library;

import 'dart:io';

import 'package:whph_sync_core/whph_sync_core.dart';

import 'naive_replica.dart';
import 'simulator.dart';

typedef ReplicaFactory = ReplicaStore Function(String nodeId);

/// A replica implementation the simulator can drive.
final class SimEngine {
  const SimEngine({required this.name, this.create, required this.expectedClean});

  final String name;

  /// Bare replicas driven through the simulator's plaintext batch protocol;
  /// `null` selects the real engine driver (`SyncDevice` sessions).
  final ReplicaFactory? create;

  /// Whether the engine must pass every oracle (the real engine, T12).
  final bool expectedClean;
}

const naiveEngine = SimEngine(name: 'naive', create: createNaiveReplica, expectedClean: false);

/// The real session engine (T12): `SyncDevice` + `SyncDevice.syncPair` over
/// `InMemoryTransport` with `TransportFaults` (see engine_simulation.dart).
const realEngine = SimEngine(name: 'engine', expectedClean: true);

/// Registered engines.
const simEngines = {'naive': naiveEngine, 'engine': realEngine};

const defaultEngineName = 'engine';

SimEngine get engineUnderTest {
  final name = Platform.environment['SIM_ENGINE'] ?? defaultEngineName;
  final engine = simEngines[name];
  if (engine == null) throw ArgumentError('Unknown SIM_ENGINE=$name; known: ${simEngines.keys.join(', ')}');
  return engine;
}

/// Whether suites assert 0 violations for [engineUnderTest].
bool get expectEngineClean => engineUnderTest.expectedClean || Platform.environment['SIM_EXPECT_CLEAN'] == '1';

/// Whether `SIM_LOG=1` is set.
bool get simLogEnabled => Platform.environment['SIM_LOG'] == '1';

/// `SIM_SEED`, if set.
int? get replaySeed {
  final raw = Platform.environment['SIM_SEED'];
  if (raw == null || raw.isEmpty) return null;
  return int.parse(raw);
}

/// Seeds of a suite, or only [replaySeed] when set.
List<int> suiteSeeds(SimSuite suite) => replaySeed != null ? [replaySeed!] : suite.seeds;

/// Suite presets.
final class SimSuite {
  const SimSuite({required this.tag, required this.firstSeed, required this.runs, required this.config});

  final String tag;
  final int firstSeed;
  final int runs;
  final SimConfig config;

  List<int> get seeds => [for (var i = 0; i < runs; i++) firstSeed + i];
}

const smokeSuite = SimSuite(tag: 'sim-smoke', firstSeed: 1000, runs: 20, config: SimConfig(devices: 5, ops: 1000));

const soakSuite = SimSuite(tag: 'sim-soak', firstSeed: 100000, runs: 1000, config: SimConfig(devices: 5, ops: 10000));
