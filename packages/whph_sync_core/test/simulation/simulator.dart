/// Seeded, deterministic multi-device convergence simulator (SC-001).
///
/// One run drives N replicas through M local operations (creates, field edits,
/// deletes, delete + re-create, identity-rule creations, D12 time-bucket adds
/// and set-totals) interleaved with sync sessions under random partitions,
/// interrupted sessions, duplicated, reordered and delayed (stale) delivery and
/// per-device clock offsets, then syncs all pairs until quiescent and checks
/// the result against the independent oracle in `oracle/`.
///
/// Every random choice comes from `Random(seed)` and every clock is simulated,
/// so a seed fully determines the run; [SimResult.traceHash] fingerprints it.
///
/// Two drivers exist: the plaintext batch protocol below drives a bare
/// [ReplicaStore] (the naive self-check replica), and `engine_simulation.dart`
/// drives the real engine (`SyncDevice` sessions over `InMemoryTransport`).
library;

import 'dart:math';

import 'package:whph_sync_core/whph_sync_core.dart';

import 'engine_simulation.dart';
import 'oracle/oracle_checks.dart';
import 'oracle/reference_oracle.dart';
import 'sim_env.dart';

final class SimConfig {
  const SimConfig({
    required this.devices,
    required this.ops,
    this.maxClockOffsetMs = 24 * 60 * 60 * 1000,
    this.sessionProbability = 0.25,
    this.repartitionProbability = 0.005,
    this.partitionedProbability = 0.5,
    this.duplicateProbability = 0.15,
    this.reorderProbability = 0.2,
    this.cutProbability = 0.2,
    this.keepStaleProbability = 0.05,
    this.staleDeliveryProbability = 0.05,
    this.maxFinalRounds = 50,
  });

  final int devices;

  /// Local user operations per run.
  final int ops;

  /// Per-device clock offsets are uniform in `[-max, +max]`.
  final int maxClockOffsetMs;

  /// Per step, the chance of a sync session between two connected devices.
  final double sessionProbability;

  /// Per step, the chance of drawing a new network partition.
  final double repartitionProbability;

  /// When drawing a partition, the chance the network is split at all.
  final double partitionedProbability;

  /// Per session direction: chance of a duplicated message, of reordered
  /// messages, and of a cut after k messages.
  final double duplicateProbability;
  final double reorderProbability;
  final double cutProbability;

  /// Per delivered message, the chance it is also kept for a late redelivery;
  /// per step, the chance one kept message is redelivered.
  final double keepStaleProbability;
  final double staleDeliveryProbability;

  final int maxFinalRounds;
}

final class SimStats {
  int writes = 0;
  int sessions = 0;
  int messages = 0;
  int duplicated = 0;
  int reordered = 0;
  int cut = 0;
  int staleDelivered = 0;
  int partitions = 0;
  int finalRounds = 0;

  /// Named counters (real-engine driver: op mix, session outcomes, discards).
  final Map<String, int> counters = {};

  void count(String name, [int by = 1]) => counters[name] = (counters[name] ?? 0) + by;

  @override
  String toString() {
    final base = 'writes=$writes sessions=$sessions messages=$messages duplicated=$duplicated reordered=$reordered '
        'cut=$cut stale=$staleDelivered partitions=$partitions finalRounds=$finalRounds';
    if (counters.isEmpty) return base;
    final names = counters.keys.toList()..sort();
    return '$base\n  counters: ${names.map((n) => '$n=${counters[n]}').join(' ')}';
  }
}

final class SimResult {
  SimResult({
    required this.seed,
    required this.engine,
    required this.config,
    required this.traceHash,
    required this.violations,
    required this.stats,
  });

  final int seed;
  final String engine;
  final SimConfig config;

  /// FNV-1a 64 over every op, delivery and the final state, as hex.
  final String traceHash;
  final List<OracleViolation> violations;
  final SimStats stats;

  bool get clean => violations.isEmpty;

  Map<OracleViolationKind, int> get counts {
    final counts = <OracleViolationKind, int>{};
    for (final v in violations) {
      counts[v.kind] = (counts[v.kind] ?? 0) + 1;
    }
    return counts;
  }

  String get countsText => counts.entries.map((e) => '${e.key.name}=${e.value}').join(', ');

  /// Human-readable failure report including the reproducing seed.
  String report({required String tag, int maxExamples = 8}) {
    final buffer = StringBuffer()
      ..writeln(
        '${clean ? 'SIM OK' : 'SIM FAILURE'} engine=$engine seed=$seed '
        'devices=${config.devices} ops=${config.ops} trace=$traceHash',
      )
      ..writeln('  stats: $stats');
    if (!clean) {
      buffer.writeln('  violations (${violations.length}): $countsText');
      // The first example of each kind, up to maxExamples.
      final seen = <OracleViolationKind>{};
      for (final v in violations) {
        if (seen.length >= maxExamples) break;
        if (seen.add(v.kind)) buffer.writeln('    - $v');
      }
      buffer.writeln(
        '  reproduce (in packages/whph_sync_core): '
        'SIM_SEED=$seed SIM_ENGINE=$engine SIM_EXPECT_CLEAN=1 fvm dart test --tags $tag',
      );
    }
    return buffer.toString();
  }
}

/// Runs [config] with [seed] against [engine]: bare replicas from
/// [SimEngine.create], or the real session engine when it is `null`.
Future<SimResult> runSimulation({required int seed, required SimConfig config, required SimEngine engine}) async {
  final create = engine.create;
  if (create == null) {
    if (simLogEnabled) engineSimLog ??= print;
    return EngineSimulation(seed, config, engine.name).run();
  }
  return _Simulation(seed, config, engine.name, create).run();
}

const _itemTable = 'item';
const _bucketTable = 'bucket';
const _itemFields = ['title', 'body'];
const _identityPool = 12;
const _taskOwners = ['task-0', 'task-1', 'task-2'];
const _habitOwners = ['habit-0', 'habit-1', 'habit-2'];
const _hourMs = 60 * 60 * 1000;
const _dayMs = 24 * _hourMs;

/// Simulated epoch start (2025-06-15T00:00:00Z) for determinism.
const _startMs = 1749945600000;

final class _BucketRow {
  const _BucketRow(this.pk, this.owner, this.hourMs, this.device);

  final String pk;
  final String owner;
  final int hourMs;
  final int device;
}

final class _InFlight {
  const _InFlight(this.src, this.dst, this.batch);

  final int src;
  final int dst;
  final ChangeBatch batch;
}

final class _Simulation {
  _Simulation(this.seed, this.config, this.engineName, ReplicaFactory create) : _rng = Random(seed) {
    for (var d = 0; d < config.devices; d++) {
      _names.add('d$d');
    }
    _stores.addAll(_names.map(create));
    _oracle = ReferenceOracle(_names);
    for (var d = 0; d < config.devices; d++) {
      _offsets.add(_rng.nextInt(2 * config.maxClockOffsetMs + 1) - config.maxClockOffsetMs);
      _groups.add(0);
      _createdCount.add(0);
    }
    final day0 = _startMs - _startMs % _dayMs;
    for (var day = 0; day < 2; day++) {
      for (var hour = 8; hour < 12; hour++) {
        _bucketHours.add(day0 + day * _dayMs + hour * _hourMs);
      }
    }
  }

  final int seed;
  final SimConfig config;
  final String engineName;
  final Random _rng;
  final List<String> _names = [];
  final List<ReplicaStore> _stores = [];
  late final ReferenceOracle _oracle;
  final List<int> _offsets = [];
  final List<int> _groups = [];
  final List<int> _createdCount = [];
  final List<int> _bucketHours = [];
  final _trace = SimTraceHasher();
  final _stats = SimStats();
  final List<OracleViolation> _violations = [];

  /// Replica-reported `origin#originSeq` -> oracle write id.
  final Map<String, int> _identity = {};
  final List<String> _itemPks = [];
  final Set<String> _itemPkSet = {};
  final Map<String, List<_BucketRow>> _bucketsByOwner = {};
  final Set<String> _bucketPkSet = {};
  final List<_InFlight> _stale = [];
  int _now = _startMs;
  int _step = 0;

  SimResult run() {
    _trace.add('seed|$seed|$engineName|${config.devices}|${config.ops}|${_offsets.join(',')}');
    for (_step = 0; _step < config.ops; _step++) {
      _now += 1 + _rng.nextInt(1000);
      if (_rng.nextDouble() < config.repartitionProbability) _repartition();
      _localOp(_rng.nextInt(config.devices));
      if (_rng.nextDouble() < config.sessionProbability) _randomSession();
      if (_stale.isNotEmpty && _rng.nextDouble() < config.staleDeliveryProbability) _deliverStale();
    }
    _finalSync();
    final observed = [for (var d = 0; d < config.devices; d++) _observe(d)];
    _violations.addAll(checkFinalState(_oracle, observed));
    _traceFinalState();
    return SimResult(
      seed: seed,
      engine: engineName,
      config: config,
      traceHash: _trace.hex,
      violations: _violations,
      stats: _stats,
    );
  }

  // ---------------------------------------------------------------- clocks

  int _wall(int d) => _now + _offsets[d];

  // ------------------------------------------------------------ local ops

  void _localOp(int d) {
    final r = _rng.nextDouble();
    if (r < 0.12) {
      _create(d);
    } else if (r < 0.45) {
      _edit(d);
    } else if (r < 0.53) {
      _delete(d);
    } else if (r < 0.59) {
      _recreate(d);
    } else if (r < 0.69) {
      _upsertRevive(d, 'id-${_rng.nextInt(_identityPool)}');
    } else if (r < 0.87) {
      _bucketAdd(d);
    } else if (r < 0.94) {
      _taskSetTotal(d);
    } else {
      _habitSetTotal(d);
    }
  }

  void _write(int d, CellKey key, Object? value, {OracleBucketInfo? bucket}) {
    final wall = _wall(d);
    final record = _stores[d].writeLocal(key, value, nowMs: wall);
    final w = _oracle.recordWrite(
      device: _names[d],
      wallMs: wall,
      table: key.table,
      pk: key.pk,
      col: key.col,
      value: value,
      bucket: bucket,
    );
    _identity['${record.origin}#${record.originSeq}'] = w.id;
    _stats.writes++;
    _trace.add('w|$d|$key|$value|$wall');
  }

  String _value(int d, String col) => '${_names[d]}:$_step:$col';

  bool _hasRow(int d, String table, String pk) => _stores[d].read(CellKey(table, pk, CellKey.existenceCol)) != null;

  void _create(int d) {
    final pk = 'i-${_names[d]}-${_createdCount[d]++}';
    _upsertRevive(d, pk);
  }

  /// Insert or revive (D5 `upsertRevive`): writes every field, plus a `~`
  /// revival cell unless the row is locally alive already.
  void _upsertRevive(int d, String pk) {
    if (_itemPkSet.add(pk)) _itemPks.add(pk);
    final revive = !(_hasRow(d, _itemTable, pk) && _stores[d].isRowAlive(_itemTable, pk));
    for (final col in _itemFields) {
      _write(d, CellKey(_itemTable, pk, col), _value(d, col));
    }
    if (revive) _write(d, CellKey(_itemTable, pk, CellKey.existenceCol), null);
  }

  /// A random item that exists on [d] with the given effective existence.
  String? _pickItem(int d, {required bool alive}) {
    if (_itemPks.isEmpty) return null;
    for (var attempt = 0; attempt < 8; attempt++) {
      final pk = _itemPks[_rng.nextInt(_itemPks.length)];
      if (_hasRow(d, _itemTable, pk) && _stores[d].isRowAlive(_itemTable, pk) == alive) return pk;
    }
    return null;
  }

  void _edit(int d) {
    final pk = _pickItem(d, alive: true);
    if (pk == null) return _create(d);
    final col = _itemFields[_rng.nextInt(_itemFields.length)];
    _write(d, CellKey(_itemTable, pk, col), _value(d, col));
  }

  void _delete(int d) {
    final pk = _pickItem(d, alive: true);
    if (pk == null) return _create(d);
    _write(d, CellKey(_itemTable, pk, CellKey.existenceCol), _wall(d));
  }

  /// Delete + re-create: revives a locally deleted row under the same id.
  void _recreate(int d) {
    final pk = _pickItem(d, alive: false);
    if (pk == null) return _delete(d);
    _upsertRevive(d, pk);
  }

  // ---------------------------------------------------- time buckets (D12)

  String _bucketPk(String owner, int hourMs, int d) => '$owner@$hourMs@${_names[d]}';

  int? _bucketValue(int reader, String pk) {
    if (!_hasRow(reader, _bucketTable, pk) || !_stores[reader].isRowAlive(_bucketTable, pk)) return null;
    final value = _stores[reader].read(CellKey(_bucketTable, pk, CellKey.rowCol))?.value;
    return value is int ? value : null;
  }

  /// Writes this device's own bucket; never another device's row.
  void _setOwnBucket(int d, String owner, int hourMs, int value) {
    final pk = _bucketPk(owner, hourMs, d);
    if (_bucketPkSet.add(pk)) (_bucketsByOwner[owner] ??= []).add(_BucketRow(pk, owner, hourMs, d));
    final exists = _hasRow(d, _bucketTable, pk);
    if (exists && _bucketValue(d, pk) == value) return; // UPDATE with no change captures nothing.
    final info = OracleBucketInfo(ownerDevice: _names[d], group: '$owner@$hourMs');
    _write(d, CellKey(_bucketTable, pk, CellKey.rowCol), value, bucket: info);
    if (!exists) _write(d, CellKey(_bucketTable, pk, CellKey.existenceCol), null, bucket: info);
  }

  String _randomOwner(List<String> owners) => owners[_rng.nextInt(owners.length)];

  int _randomHour() => _bucketHours[_rng.nextInt(_bucketHours.length)];

  void _bucketAdd(int d) {
    final owners = _rng.nextBool() ? _taskOwners : _habitOwners;
    final owner = _randomOwner(owners);
    final hour = _randomHour();
    final current = _bucketValue(d, _bucketPk(owner, hour, d)) ?? 0;
    _setOwnBucket(d, owner, hour, current + 1 + _rng.nextInt(3600));
  }

  /// Task set-total is day-level: own bucket at the target hour = target − Σ
  /// other devices' live buckets of that day as seen here; own buckets at the
  /// day's other hours are set to 0.
  void _taskSetTotal(int d) {
    final owner = _randomOwner(_taskOwners);
    final hour = _randomHour();
    final target = _rng.nextInt(7201);
    final dayStart = hour - hour % _dayMs;
    var others = 0;
    final ownOtherHours = <int>[];
    for (final row in _bucketsByOwner[owner] ?? const <_BucketRow>[]) {
      if (row.hourMs < dayStart || row.hourMs >= dayStart + _dayMs) continue;
      if (row.device != d) {
        others += _bucketValue(d, row.pk) ?? 0;
      } else if (row.hourMs != hour) {
        ownOtherHours.add(row.hourMs);
      }
    }
    _setOwnBucket(d, owner, hour, target - others);
    for (final other in ownOtherHours) {
      if (_hasRow(d, _bucketTable, _bucketPk(owner, other, d))) _setOwnBucket(d, owner, other, 0);
    }
  }

  /// Habit set-total is hour-level: own bucket = target − Σ other devices'
  /// live buckets at that hour as seen here.
  void _habitSetTotal(int d) {
    final owner = _randomOwner(_habitOwners);
    final hour = _randomHour();
    final target = _rng.nextInt(7201);
    var others = 0;
    for (final row in _bucketsByOwner[owner] ?? const <_BucketRow>[]) {
      if (row.hourMs == hour && row.device != d) others += _bucketValue(d, row.pk) ?? 0;
    }
    _setOwnBucket(d, owner, hour, target - others);
  }

  // -------------------------------------------------------------- network

  void _repartition() {
    _stats.partitions++;
    final split = _rng.nextDouble() < config.partitionedProbability;
    for (var d = 0; d < config.devices; d++) {
      _groups[d] = split ? _rng.nextInt(3) : 0;
    }
    _trace.add('p|${_groups.join(',')}');
  }

  void _randomSession() {
    final a = _rng.nextInt(config.devices);
    final peers = [
      for (var b = 0; b < config.devices; b++)
        if (b != a && _groups[b] == _groups[a]) b,
    ];
    if (peers.isEmpty) return;
    _session(a, peers[_rng.nextInt(peers.length)], perturb: true);
  }

  /// A bidirectional session; returns whether either replica changed.
  bool _session(int a, int b, {required bool perturb}) {
    _stats.sessions++;
    final ab = _transfer(a, b, perturb: perturb);
    final ba = _transfer(b, a, perturb: perturb);
    return ab || ba;
  }

  /// [dst] pulls what it is missing from [src].
  bool _transfer(int src, int dst, {required bool perturb}) {
    final maxCells = perturb ? 1 + _rng.nextInt(16) : 64;
    final messages = List<ChangeBatch>.of(_stores[src].changesSince(_stores[dst].vector, maxCellsPerBatch: maxCells));
    if (perturb && messages.isNotEmpty) {
      if (_rng.nextDouble() < config.duplicateProbability) {
        _stats.duplicated++;
        messages.insert(_rng.nextInt(messages.length + 1), messages[_rng.nextInt(messages.length)]);
      }
      if (messages.length > 1 && _rng.nextDouble() < config.reorderProbability) {
        _stats.reordered++;
        for (var swaps = 1 + _rng.nextInt(messages.length); swaps > 0; swaps--) {
          final i = _rng.nextInt(messages.length);
          final j = _rng.nextInt(messages.length);
          final tmp = messages[i];
          messages[i] = messages[j];
          messages[j] = tmp;
        }
      }
      if (_rng.nextDouble() < config.cutProbability) {
        _stats.cut++;
        messages.removeRange(_rng.nextInt(messages.length + 1), messages.length);
      }
    }
    var changed = false;
    for (final message in messages) {
      if (_deliver(src, dst, message)) changed = true;
      if (perturb && _rng.nextDouble() < config.keepStaleProbability) {
        if (_stale.length >= 64) _stale.removeAt(_rng.nextInt(_stale.length));
        _stale.add(_InFlight(src, dst, message));
      }
    }
    return changed;
  }

  void _deliverStale() {
    final message = _stale.removeAt(_rng.nextInt(_stale.length));
    if (_groups[message.src] != _groups[message.dst]) return;
    _stats.staleDelivered++;
    _deliver(message.src, message.dst, message.batch);
  }

  int? _writeIdOf(CellRecord? record) => record == null ? null : _identity['${record.origin}#${record.originSeq}'];

  bool _deliver(int src, int dst, ChangeBatch batch) {
    _stats.messages++;
    final store = _stores[dst];
    final before = [for (final cell in batch.cells) _writeIdOf(store.read(cell.key))];
    final changed = store.applyBatch(batch);
    for (var i = 0; i < batch.cells.length; i++) {
      final cell = batch.cells[i];
      final cellKey = oracleCellKey(cell.key.table, cell.key.pk, cell.key.col);
      final id = _writeIdOf(cell);
      if (id == null) {
        _violations.add(
          OracleViolation(OracleViolationKind.unknownVersion, _names[dst], cellKey, 'delivered unrecorded $cell'),
        );
        continue;
      }
      _oracle.recordDelivery(_names[dst], id);
      final regression = checkNoRegression(
        _oracle,
        device: _names[dst],
        cellKey: cellKey,
        before: before[i],
        after: _writeIdOf(store.read(cell.key)),
      );
      if (regression != null) _violations.add(regression);
    }
    _trace.add('m|$src|$dst|${batch.origin}|${batch.fromSeq}|${batch.toSeq}|${batch.cells.length}|$changed');
    return changed;
  }

  void _finalSync() {
    _stale.clear();
    for (var d = 0; d < config.devices; d++) {
      _groups[d] = 0;
    }
    var changed = true;
    while (changed && _stats.finalRounds < config.maxFinalRounds) {
      _stats.finalRounds++;
      changed = false;
      for (var a = 0; a < config.devices; a++) {
        for (var b = a + 1; b < config.devices; b++) {
          if (_session(a, b, perturb: false)) changed = true;
        }
      }
    }
    if (changed) {
      _violations.add(
        OracleViolation(OracleViolationKind.notQuiescent, '*', '*', 'after ${config.maxFinalRounds} rounds'),
      );
    }
  }

  // --------------------------------------------------------------- checks

  ObservedReplica _observe(int d) {
    final store = _stores[d];
    final cells = <String, ObservedCell>{};
    final rows = <String, bool>{};
    for (final record in store.cells) {
      final key = record.key;
      cells[oracleCellKey(key.table, key.pk, key.col)] = ObservedCell(
        value: record.value,
        writeId: _writeIdOf(record),
        author: record.node,
      );
      rows.putIfAbsent(oracleRowKey(key.table, key.pk), () => store.isRowAlive(key.table, key.pk));
    }
    return ObservedReplica(device: _names[d], cells: cells, rowsAlive: rows);
  }

  void _traceFinalState() {
    for (final store in _stores) {
      for (final record in store.cells) {
        _trace.add('f|${store.nodeId}|${record.key}|${record.value}|${record.node}|${record.originSeq}');
      }
    }
    for (final v in _violations) {
      _trace.add('v|$v');
    }
  }
}

/// FNV-1a 64-bit over the UTF-16 code units of each event, with a separator.
final class SimTraceHasher {
  static const _prime = 0x100000001b3;
  int _hash = 0xcbf29ce484222325;

  void add(String event) {
    for (final unit in event.codeUnits) {
      _hash = (_hash ^ unit) * _prime;
    }
    _hash = (_hash ^ 0x1e) * _prime;
  }

  String get hex =>
      (_hash >>> 32).toRadixString(16).padLeft(8, '0') + (_hash & 0xffffffff).toRadixString(16).padLeft(8, '0');
}
