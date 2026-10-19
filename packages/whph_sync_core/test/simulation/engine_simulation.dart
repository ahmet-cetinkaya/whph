/// Real-engine driver of the convergence simulator (T12 part B, SC-001).
///
/// Drives `SyncDevice`s through `SyncDevice.syncPair` sessions over
/// `InMemoryTransport` with random `TransportFaults` (cut, duplicated and
/// reordered frames), under random network partitions and per-device clock
/// offsets, and checks the outcome against the independent oracle.
///
/// Devices: `d0..d{n-1}` are the final devices compared at the end. Two
/// outsiders model membership changes and are never compared:
///
/// * `o{n}` is a member of G1 from the start and is removed by a random G1
///   member at a random step in `[ops/4, 3·ops/4]`; it keeps writing and
///   syncing afterwards (a completed exchange with a device that already
///   knew the revocation is a [OracleViolationKind.groupLeak]);
/// * `o{n+1}` forms G2 with `d{n-1}`; at a random step in `[ops/10, ops/2]`
///   `d{n-1}` joins G1 with a confirmed group switch (NB-1). Afterwards
///   `o{n+1}` keeps writing and attempting sessions with G1 members; any
///   completed exchange is a [OracleViolationKind.groupLeak].
///
/// Besides the item and D12 bucket ops of the plaintext simulator, the run has
/// cascade deletes, revival edits, explicit revivals and, at low rates, clock
/// jumps, DB-only snapshots/restores, whole-directory snapshots/restores,
/// key loss with an old DB (+ removal of the old member id and re-pairing),
/// replace-import (`local_reset`) and injected apply failures.
///
/// Every random choice comes from `Random(seed)`; device ids from
/// `SyncIdSource(Random(derived seed))`; the trace hash covers logical events
/// only (ops, session outcomes, final content), never ciphertext.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:whph_sync_core/whph_sync_core.dart';

import 'oracle/oracle_checks.dart';
import 'sim_env.dart';
import 'oracle/reference_oracle.dart';
import 'simulator.dart';
import 'stranded_members.dart';

/// Per-step rates and engine settings of the real-engine driver.
final class EngineSimTuning {
  const EngineSimTuning({
    this.clockJumpProbability = 0.002,
    this.dbSnapshotProbability = 0.005,
    this.dbRestoreProbability = 0.002,
    this.dirSnapshotProbability = 0.002,
    this.dirRestoreProbability = 0.001,
    this.fullRollbackProbability = 0,
    this.keyLostProbability = 0.001,
    this.replaceImportProbability = 0.001,
    this.applyFaultProbability = 0.002,
    this.outsiderAttemptProbability = 0.01,
    this.transportFaultProbability = 0.3,
    this.maxFaultFrame = 40,
    this.maxBatchChanges = 64,
    this.maxFinalRounds = 30,
    this.maxSnapshotsPerDevice = 4,
  });

  final double clockJumpProbability;
  final double dbSnapshotProbability;
  final double dbRestoreProbability;
  final double dirSnapshotProbability;
  final double dirRestoreProbability;

  /// Per step: DB, key file and sync ledger rolled back together. Zero in the
  /// gating suites: the rollback is undetectable locally (U11 accepted
  /// residual risk), so only the non-gating diagnostic enables it.
  final double fullRollbackProbability;
  final double keyLostProbability;
  final double replaceImportProbability;
  final double applyFaultProbability;

  /// After the group switch, per step: the G2 outsider tries a session with
  /// a G1 member.
  final double outsiderAttemptProbability;

  /// Per session: the chance of a transport fault (cut, duplicate or reorder
  /// at a random frame index below [maxFaultFrame]).
  final double transportFaultProbability;
  final int maxFaultFrame;
  final int maxBatchChanges;
  final int maxFinalRounds;
  final int maxSnapshotsPerDevice;
}

const _item = 'item';
const _bucket = 'bucket';
const _fields = ['title', 'body'];
const _identityPool = 12;
const _taskOwners = ['task-0', 'task-1', 'task-2'];
const _habitOwners = ['habit-0', 'habit-1', 'habit-2'];
const _hourMs = 60 * 60 * 1000;
const _dayMs = 24 * _hourMs;
const _revokedCategory = 'revokedAboveCutoff';

/// Simulated epoch start (2025-06-15T00:00:00Z) for determinism.
const _startMs = 1749945600000;

/// Failure categories a session may end in (anything else is an engine bug).
const _allowedFailures = {
  SessionFailure.notReachable,
  SessionFailure.securityError,
  SessionFailure.busy,
  SessionFailure.restoreDetected,
  SessionFailure.notAuthorized,
  SessionFailure.refusedByPeer,
  SessionFailure.removedFromGroup,
  SessionFailure.notPaired,
  SessionFailure.peerPreparing,
};

Future<void> _noDelay(Duration _) async {}

/// Diagnostics sink (tests leave it `null`; a debugging session may set it to
/// `print` to follow membership events and session outcomes).
void Function(String line)? engineSimLog;

bool _isUserTable(String table) => table == _item || table == _bucket;

final class _Saved<T> {
  _Saved(this.value, this.knowledge, this.step);

  final T value;
  final OracleKnowledge knowledge;
  final int step;
}

final class _BucketRow {
  const _BucketRow(this.pk, this.hourMs, this.device);

  final String pk;
  final int hourMs;
  final String device;
}

/// The app data directory and the sync ledger (kept outside it) at one moment.
final class _DirectoryState {
  const _DirectoryState(this.directory, this.ledger);

  final DirectorySnapshot directory;
  final InMemorySyncLedger ledger;
}

/// Efe ruling (stale-restore), pure decision core: partition [names] into
/// clusters of mutual non-auth-failure ([pairAuthFail], normalized keys
/// "a|b"), and exclude exactly the clusters whose EVERY member is stale,
/// whose members all failed auth (K consecutive [authFailRounds], no
/// [otherFailRounds]) with every outside device. A cluster holding a
/// never-stale device is never excludable. A stale set covering everything
/// is reported, not excluded.
Set<String> decideStaleExclusion({
  required List<String> names,
  required Map<String, bool> stale,
  required Map<String, bool> pairAuthFail,
  required Map<String, int> authFailRounds,
  required Map<String, int> otherFailRounds,
  void Function(Set<String> cluster)? onExcluded,
  void Function(int size)? onWholeSetStale,
  int k = 2,
}) {
  bool fails(String a, String b) {
    final key = [a, b]..sort();
    return pairAuthFail['${key[0]}|${key[1]}'] ?? true;
  }

  final clusters = <Set<String>>[];
  for (final n in names) {
    final accepted = {
      n,
      for (final x in names)
        if (x != n && !fails(x, n)) x,
    };
    final peers = clusters.where((c) => c.contains(n)).firstOrNull;
    if (peers == null) {
      clusters.add(accepted);
    } else {
      peers.addAll(accepted);
    }
  }
  var merged = true;
  while (merged) {
    merged = false;
    for (var i = 0; i < clusters.length && !merged; i++) {
      for (var j = i + 1; j < clusters.length && !merged; j++) {
        if (clusters[i].any(clusters[j].contains)) {
          clusters[i].addAll(clusters[j]);
          clusters.removeAt(j);
          merged = true;
        }
      }
    }
  }
  final out = <String>{};
  for (final cluster in clusters) {
    if (!cluster.every((n) => stale[n] ?? false)) continue;
    if (cluster.any((n) => otherFailRounds[n]! > 0 || authFailRounds[n]! < k)) continue;
    final outside = names.where((n) => !cluster.contains(n)).toList();
    if (outside.isEmpty) {
      onWholeSetStale?.call(cluster.length);
      continue;
    }
    if (!outside.every((x) => cluster.every((n) => fails(x, n)))) continue;
    out.addAll(cluster);
    onExcluded?.call(cluster);
  }
  return out;
}

final class _Dev {
  _Dev(this.name, {required this.isFinal});

  final String name;
  final bool isFinal;
  late final SyncDevice device;
  int offset = 0;
  int created = 0;
  int partition = 0;
  int faultSessions = 0;

  /// Efe ruling (stale restore): the device restored a snapshot whose member
  /// set lacked an identity current at restore time. Set causally at op time;
  /// the endgame evidence check decides the oracle exclusion.
  bool staleRestored = false;

  /// This device's result of its most recent final-phase session (evidence
  /// for the stale-restore exclusion; null before the first round).
  SessionResult? roundOutcome;

  final List<_Saved<DeviceDbSnapshot>> dbSnapshots = [];
  final List<_Saved<_DirectoryState>> dirSnapshots = [];

  /// The ledger injected at creation, so a full rollback can restore it.
  final InMemorySyncLedger ledger = InMemorySyncLedger();

  SyncStore get store => device.store;
  Membership get membership => device.membership;

  void forgetSnapshots() {
    dbSnapshots.clear();
    dirSnapshots.clear();
  }
}

/// One real-engine run (see the library documentation).
///
/// Fault injection note (card A-4): [InMemorySyncLedger]'s fault flags
/// (`failAllSentMarkWrites`, `failNextSentMarkWrites`) gate BOTH the sent
/// mark and the written watermark, because both go through the same
/// `_replace` write path; a count set for one also consumes for the other.
final class EngineSimulation {
  EngineSimulation(this.seed, this.config, this.engineName, {this.tuning = const EngineSimTuning()})
      : _rng = Random(seed);

  final int seed;
  final SimConfig config;
  final String engineName;
  final EngineSimTuning tuning;
  final Random _rng;

  final List<_Dev> _devs = [];
  late final List<_Dev> _finals;
  late final _Dev _revokee;
  late final _Dev _outsider;
  late final _Dev _switcher;
  late final ReferenceOracle _oracle;
  late final Uint8List _revokeePub;
  GroupId? _g1;
  late final int _removeAt;
  late final int _switchAt;
  bool _removed = false;
  bool _switched = false;

  /// Every member id a sim device ever had -> its name.
  final Map<String, String> _simOfMember = {};
  final List<String> _itemPks = [];
  final Set<String> _itemPkSet = {};
  final List<int> _bucketHours = [];
  final Map<String, List<_BucketRow>> _bucketsByOwner = {};
  final Set<String> _bucketPkSet = {};

  final _trace = SimTraceHasher();
  final _stats = SimStats();
  final List<OracleViolation> _violations = [];
  int _now = _startMs;
  int _step = 0;

  Future<SimResult> run() async {
    await _setup();
    for (_step = 0; _step < config.ops; _step++) {
      _now += 1 + _rng.nextInt(1000);
      if (_rng.nextDouble() < config.repartitionProbability) _repartition();
      if (!_switched && _step >= _switchAt) await _groupSwitch();
      if (!_removed && _step >= _removeAt) await _removeRevokee();
      await _op();
      for (final d in _devs) {
        await _repairStranded(d);
      }
      if (_rng.nextDouble() < config.sessionProbability) await _randomSession();
      if (_switched && _rng.nextDouble() < tuning.outsiderAttemptProbability) await _outsiderAttempt();
      for (final d in _devs) {
        d.store.assertSupersededIndexConsistent();
      }
      if (engineSimLog != null) _logMembershipChanges();
    }
    if (!_switched) _violate(OracleViolationKind.membership, _switcher.name, 'switch', 'group switch never ran');
    if (!_removed) _violate(OracleViolationKind.membership, _revokee.name, 'removal', 'removal never ran');
    await _finalPhase();
    for (final v in _violations) {
      _trace.add('v|$v');
    }
    return SimResult(
      seed: seed,
      engine: engineName,
      config: config,
      traceHash: _trace.hex,
      violations: _violations,
      stats: _stats,
    );
  }

  void _log(String line) => engineSimLog?.call('[$_step] $line');

  final Map<String, String> _lastMembership = {};

  void _logMembershipChanges() {
    for (final d in _devs) {
      final m = d.membership;
      final known = (m.members.keys.map((k) => k.substring(0, 6)).toList()..sort()).join(',');
      final state = 'known=$known active=${_names(m.activeMembers.map((e) => e.memberId))} '
          'anchors=${(m.anchors.map((a) => a.memberId.substring(0, 6)).toList()..sort()).join(',')}';
      if (_lastMembership[d.name] != state) {
        _lastMembership[d.name] = state;
        _log('membership ${d.name} $state');
      }
    }
  }

  void _violate(OracleViolationKind kind, String device, String subject, String detail) =>
      _violations.add(OracleViolation(kind, device, subject, detail));

  T _pick<T>(List<T> list) => list[_rng.nextInt(list.length)];

  int _randomOffset() => _rng.nextInt(2 * config.maxClockOffsetMs + 1) - config.maxClockOffsetMs;

  // ------------------------------------------------------------------ setup

  Future<void> _setup() async {
    final n = config.devices;
    if (n < 3) throw ArgumentError.value(n, 'devices', 'the engine driver needs at least 3 final devices');
    for (var i = 0; i < n + 2; i++) {
      final dev = _Dev(i < n ? 'd$i' : 'o$i', isFinal: i < n)..offset = _randomOffset();
      final idSeed = _rng.nextInt(1 << 32);
      dev.device = await SyncDevice.create(
        name: dev.name,
        ledger: dev.ledger,
        clock: () => _now + dev.offset,
        ids: SyncIdSource(Random(idSeed)),
        config: SyncEngineConfig(window: 1 + _rng.nextInt(4), maxBatchChanges: tuning.maxBatchChanges, delay: _noDelay),
      );
      _simOfMember[dev.device.memberId] = dev.name;
      _devs.add(dev);
    }
    _oracle = ReferenceOracle([for (final d in _devs) d.name]);
    _finals = _devs.sublist(0, n);
    _revokee = _devs[n];
    _outsider = _devs[n + 1];
    _switcher = _devs[n - 1];
    for (final joiner in [..._finals.sublist(1, n - 1), _revokee]) {
      await SyncDevice.pair(inviter: _devs.first.device, joiner: joiner.device);
    }
    await SyncDevice.pair(inviter: _outsider.device, joiner: _switcher.device);
    _g1 = _devs.first.membership.groupId;
    _revokeePub = Uint8List.fromList(_revokee.membership.identity.ed25519Pub);
    final ops = config.ops;
    _removeAt = ops ~/ 4 + _rng.nextInt(ops ~/ 2 + 1);
    _switchAt = ops ~/ 10 + _rng.nextInt(ops ~/ 2 - ops ~/ 10 + 1);
    final day0 = _startMs - _startMs % _dayMs;
    for (var day = 0; day < 2; day++) {
      for (var hour = 8; hour < 12; hour++) {
        _bucketHours.add(day0 + day * _dayMs + hour * _hourMs);
      }
    }
    _trace.add('seed|$seed|$engineName|$n|${config.ops}|${_devs.map((d) => '${d.name}:${d.offset}').join(',')}'
        '|${_devs.map((d) => d.device.memberId).join(',')}|remove@$_removeAt|switch@$_switchAt');
  }

  bool _inG1(_Dev d) => d.membership.hasGroup && d.membership.groupId == _g1 && !d.membership.removed;

  List<_Dev> _g1Finals({_Dev? except}) => [
        for (final d in _finals)
          if (d != except && _inG1(d)) d
      ];

  // -------------------------------------------------------------------- ops

  Future<void> _op() async {
    final r = _rng.nextDouble();
    var edge = 0.0;
    bool hit(double p) => r < (edge += p);
    if (hit(tuning.clockJumpProbability)) return _clockJump(_pick(_devs));
    if (hit(tuning.dbSnapshotProbability)) return await _dbSnapshot(_pick(_finals));
    if (hit(tuning.dbRestoreProbability)) return _dbRestore(_pick(_finals));
    if (hit(tuning.dirSnapshotProbability)) return await _dirSnapshot(_pick(_finals));
    if (hit(tuning.dirRestoreProbability)) return _dirRestore(_pick(_finals));
    if (hit(tuning.fullRollbackProbability)) return _fullRollback(_pick(_finals));
    if (hit(tuning.keyLostProbability)) return _keyLost(_pick(_finals));
    if (hit(tuning.replaceImportProbability)) return _replaceImport(_pick(_finals));
    if (hit(tuning.applyFaultProbability)) return _applyFault(_pick(_finals));
    _localOp(_pick(_devs));
  }

  void _localOp(_Dev d) {
    final r = _rng.nextDouble();
    if (r < 0.11) {
      _create(d);
    } else if (r < 0.40) {
      _edit(d);
    } else if (r < 0.47) {
      _delete(d);
    } else if (r < 0.52) {
      _recreate(d);
    } else if (r < 0.55) {
      _cascade(d);
    } else if (r < 0.58) {
      _reviveEdit(d);
    } else if (r < 0.60) {
      _reviveExplicit(d);
    } else if (r < 0.69) {
      _stats.count('op.identityUpsert');
      _upsertRevive(d, 'id-${_rng.nextInt(_identityPool)}');
    } else if (r < 0.86) {
      _bucketAdd(d);
    } else if (r < 0.93) {
      _taskSetTotal(d);
    } else {
      _habitSetTotal(d);
    }
  }

  CellRecord _write(_Dev d, CellKey key, Object? value, {OracleBucketInfo? bucket}) {
    final wall = d.device.now();
    final record = d.device.write(key, value);
    _record(d, record, wall, expected: value, bucket: bucket);
    return record;
  }

  /// Reports a local write the engine stamped to the oracle.
  void _record(_Dev d, CellRecord r, int wall, {required Object? expected, OracleBucketInfo? bucket}) {
    if (r.node != d.device.memberId || r.value != expected) {
      _violate(OracleViolationKind.unknownVersion, d.name, '${r.key}', 'local write stored as $r');
    }
    final cause = r.cause;
    _oracle.recordWrite(
      device: d.name,
      wallMs: wall,
      table: r.key.table,
      pk: r.key.pk,
      col: r.key.col,
      value: r.value,
      hlc: r.clock,
      node: r.node,
      cause: cause == null ? null : oracleRowKey(cause.table, cause.pk),
      bucket: bucket,
    );
    _stats.writes++;
    _trace.add('w|${d.name}|${r.key}|${r.value}|${r.clock}|${r.cause}');
  }

  void _event(String event) {
    _trace.add(event);
    _log(event);
  }

  String _value(_Dev d, String col) => '${d.name}:$_step:$col';

  RowExistence _existence(_Dev d, String table, String pk) => d.store.existenceOf(RowRef(table, pk));

  void _create(_Dev d) {
    _stats.count('op.create');
    _upsertRevive(d, 'i-${d.name}-${d.created++}');
  }

  /// Insert or revive (D5 `upsertRevive`): writes every field, plus a `~`
  /// revival cell unless the row is locally alive already.
  void _upsertRevive(_Dev d, String pk) {
    if (_itemPkSet.add(pk)) _itemPks.add(pk);
    final revive = _existence(d, _item, pk) != RowExistence.alive;
    for (final col in _fields) {
      _write(d, CellKey(_item, pk, col), _value(d, col));
    }
    if (revive) _write(d, CellKey(_item, pk, CellKey.existenceCol), null);
  }

  /// A random item that exists on [d] with the given effective existence.
  String? _pickItem(_Dev d, {required bool alive}) {
    if (_itemPks.isEmpty) return null;
    final want = alive ? RowExistence.alive : RowExistence.deleted;
    for (var attempt = 0; attempt < 8; attempt++) {
      final pk = _pick(_itemPks);
      if (_existence(d, _item, pk) == want) return pk;
    }
    return null;
  }

  void _edit(_Dev d) {
    final pk = _pickItem(d, alive: true);
    if (pk == null) return _create(d);
    _stats.count('op.edit');
    final col = _pick(_fields);
    _write(d, CellKey(_item, pk, col), _value(d, col));
  }

  void _delete(_Dev d) {
    final pk = _pickItem(d, alive: true);
    if (pk == null) return _create(d);
    _stats.count('op.delete');
    _write(d, CellKey(_item, pk, CellKey.existenceCol), d.device.now());
  }

  /// Delete + re-create: revives a locally deleted row under the same id.
  void _recreate(_Dev d) {
    final pk = _pickItem(d, alive: false);
    if (pk == null) return _delete(d);
    _stats.count('op.recreate');
    _upsertRevive(d, pk);
  }

  /// Cascade delete (D5b): an alive parent and 1–2 alive children, each
  /// child tombstone carrying `cause = parent`.
  void _cascade(_Dev d) {
    final parent = _pickItem(d, alive: true);
    if (parent == null) return _create(d);
    final want = 1 + _rng.nextInt(2);
    final children = <String>{};
    for (var attempt = 0; attempt < 8 && children.length < want; attempt++) {
      final child = _pickItem(d, alive: true);
      if (child != null && child != parent) children.add(child);
    }
    if (children.isEmpty) return _delete(d);
    _stats.count('op.cascade');
    final wall = d.device.now();
    d.device.cascadeDelete(RowRef(_item, parent), [for (final c in children) RowRef(_item, c)]);
    for (final pk in [parent, ...children]) {
      final record = d.store.read(CellKey(_item, pk, CellKey.existenceCol))!;
      _record(d, record, wall, expected: wall);
    }
  }

  /// FR-006: an edit of a locally deleted item (revives it where it wins).
  void _reviveEdit(_Dev d) {
    final pk = _pickItem(d, alive: false);
    if (pk == null) return _edit(d);
    _stats.count('op.reviveEdit');
    final col = _pick(_fields);
    _write(d, CellKey(_item, pk, col), _value(d, col));
  }

  /// An explicit `~ = null` revival of a locally deleted item.
  void _reviveExplicit(_Dev d) {
    final pk = _pickItem(d, alive: false);
    if (pk == null) return _edit(d);
    _stats.count('op.reviveExplicit');
    _write(d, CellKey(_item, pk, CellKey.existenceCol), null);
  }

  // ---------------------------------------------------- time buckets (D12)

  String _bucketPk(String owner, int hourMs, _Dev d) => '$owner@$hourMs@${d.name}';

  int? _bucketValue(_Dev reader, String pk) {
    if (_existence(reader, _bucket, pk) != RowExistence.alive) return null;
    final value = reader.store.read(CellKey(_bucket, pk, CellKey.rowCol))?.value;
    return value is int ? value : null;
  }

  /// Writes this device's own bucket; never another device's row.
  void _setOwnBucket(_Dev d, String owner, int hourMs, int value) {
    final pk = _bucketPk(owner, hourMs, d);
    if (_bucketPkSet.add(pk)) (_bucketsByOwner[owner] ??= []).add(_BucketRow(pk, hourMs, d.name));
    final exists = _existence(d, _bucket, pk) != RowExistence.absent;
    if (exists && _bucketValue(d, pk) == value) return; // UPDATE with no change captures nothing.
    final info = OracleBucketInfo(ownerDevice: d.name, group: '$owner@$hourMs');
    _write(d, CellKey(_bucket, pk, CellKey.rowCol), value, bucket: info);
    if (!exists) _write(d, CellKey(_bucket, pk, CellKey.existenceCol), null, bucket: info);
  }

  void _bucketAdd(_Dev d) {
    _stats.count('op.bucketAdd');
    final owner = _pick(_rng.nextBool() ? _taskOwners : _habitOwners);
    final hour = _pick(_bucketHours);
    final current = _bucketValue(d, _bucketPk(owner, hour, d)) ?? 0;
    _setOwnBucket(d, owner, hour, current + 1 + _rng.nextInt(3600));
  }

  /// Task set-total is day-level (see the plaintext simulator).
  void _taskSetTotal(_Dev d) {
    _stats.count('op.taskSetTotal');
    final owner = _pick(_taskOwners);
    final hour = _pick(_bucketHours);
    final target = _rng.nextInt(7201);
    final dayStart = hour - hour % _dayMs;
    var others = 0;
    final ownOtherHours = <int>[];
    for (final row in _bucketsByOwner[owner] ?? const <_BucketRow>[]) {
      if (row.hourMs < dayStart || row.hourMs >= dayStart + _dayMs) continue;
      if (row.device != d.name) {
        others += _bucketValue(d, row.pk) ?? 0;
      } else if (row.hourMs != hour) {
        ownOtherHours.add(row.hourMs);
      }
    }
    _setOwnBucket(d, owner, hour, target - others);
    for (final other in ownOtherHours) {
      if (_existence(d, _bucket, _bucketPk(owner, other, d)) != RowExistence.absent) _setOwnBucket(d, owner, other, 0);
    }
  }

  /// Habit set-total is hour-level.
  void _habitSetTotal(_Dev d) {
    _stats.count('op.habitSetTotal');
    final owner = _pick(_habitOwners);
    final hour = _pick(_bucketHours);
    final target = _rng.nextInt(7201);
    var others = 0;
    for (final row in _bucketsByOwner[owner] ?? const <_BucketRow>[]) {
      if (row.hourMs == hour && row.device != d.name) others += _bucketValue(d, row.pk) ?? 0;
    }
    _setOwnBucket(d, owner, hour, target - others);
  }

  // ------------------------------------------------- destructive/membership

  void _clockJump(_Dev d) {
    _stats.count('op.clockJump');
    d.offset = _randomOffset();
    _trace.add('clock|${d.name}|${d.offset}');
  }

  void _keep<T>(List<_Saved<T>> list, _Saved<T> saved) {
    list.add(saved);
    if (list.length > tuning.maxSnapshotsPerDevice) list.removeAt(0);
  }

  Future<void> _dbSnapshot(_Dev d) async {
    _stats.count('op.dbSnapshot');
    _keep(d.dbSnapshots, _Saved(await d.device.snapshotDb(), _oracle.knowledgeOf(d.name), _step));
    _trace.add('snapDb|${d.name}');
  }

  /// DB-only restore of an earlier snapshot (key file and sync ledger current).
  Future<void> _dbRestore(_Dev d) async {
    if (d.dbSnapshots.isEmpty) return _stats.count('skip.dbRestore');
    _stats.count('op.dbRestore');
    final saved = _pick(d.dbSnapshots);
    final memberIdsBefore = d.device.memberId;
    final action = await d.device.restoreDb(saved.value);
    _oracle.startIncarnation(d.name, saved.knowledge);
    _markStaleRestored(d, saved.step, memberIdsBefore);
    _event('restoreDb|${d.name}|${saved.step}|${action.name}');
  }

  /// Causal stale-restore trigger (Efe ruling): the restored snapshot's
  /// member set lacks an identity that is current at restore time. The sim
  /// has global knowledge, like [ReferenceOracle.startIncarnation].
  void _markStaleRestored(_Dev d, int snapshotStep, String memberIdsBefore) {
    final snapshotMembers = d.membership.members.keys.toSet();
    final currents = {
      for (final other in _devs)
        if (other != d) other.device.memberId,
    };
    if (snapshotMembers.containsAll(currents)) return;
    d.staleRestored = true;
    _stats.count('op.staleRestore');
    _event('staleRestore|${d.name}|from=$snapshotStep|missing=${currents.difference(snapshotMembers).length}');
  }

  Future<void> _dirSnapshot(_Dev d) async {
    _stats.count('op.dirSnapshot');
    final state = _DirectoryState(await d.device.snapshotDirectory(), d.ledger.snapshot());
    _keep(d.dirSnapshots, _Saved(state, _oracle.knowledgeOf(d.name), _step));
    _trace.add('snapDir|${d.name}');
  }

  /// Whole-directory restore (DB and key file) while the sync ledger, which
  /// lives outside the data directory, stays current: startup rule 4 sees the
  /// DB behind the ledger and switches origin (U11, gating).
  Future<void> _dirRestore(_Dev d) async {
    if (d.dirSnapshots.isEmpty) return _stats.count('skip.dirRestore');
    _stats.count('op.dirRestore');
    final saved = _pick(d.dirSnapshots);
    final action = await d.device.restoreDirectory(saved.value.directory);
    _oracle.startIncarnation(d.name, saved.knowledge);
    _markStaleRestored(d, saved.step, d.device.memberId);
    _event('restoreDir|${d.name}|${saved.step}|${action.name}');
  }

  /// Full rollback (DB, key file and sync ledger together, e.g. a home-folder
  /// snapshot). Nothing local can detect it (U11 accepted residual risk), so
  /// the op is a non-gating diagnostic: [EngineSimTuning.fullRollbackProbability]
  /// is zero unless the diagnostic suite enables it.
  Future<void> _fullRollback(_Dev d) async {
    if (d.dirSnapshots.isEmpty) return _stats.count('skip.fullRollback');
    _stats.count('op.fullRollback');
    final saved = _pick(d.dirSnapshots);
    d.ledger.restoreFrom(saved.value.ledger);
    final action = await d.device.restoreDirectory(saved.value.directory);
    _oracle.startIncarnation(d.name, saved.knowledge);
    _markStaleRestored(d, saved.step, d.device.memberId);
    _event('fullRollback|${d.name}|${saved.step}|${action.name}');
  }

  /// Key loss with an old DB: new identity, the old member id removed by an
  /// active G1 member, then re-pairing into G1.
  Future<void> _keyLost(_Dev d) async {
    if (!_inG1(d) || d.dbSnapshots.isEmpty) return _stats.count('skip.keyLost');
    final removers = [
      for (final x in _g1Finals(except: d))
        if (x.membership.memberById(d.device.memberId) != null) x
    ];
    if (removers.isEmpty) return _stats.count('skip.keyLost');
    _stats.count('op.keyLost');
    final saved = _pick(d.dbSnapshots);
    final loseLedger = _rng.nextBool();
    final oldId = d.device.memberId;
    final action = await d.device.loseKeyFile(oldDb: saved.value, loseLedger: loseLedger);
    _oracle.startIncarnation(d.name, saved.knowledge);
    _simOfMember[d.device.memberId] = d.name;
    d.forgetSnapshots();
    final remover = _pick(removers);
    await remover.device.removeMember(oldId);
    remover.forgetSnapshots();
    final inviter = _pick(_g1Finals(except: d));
    await SyncDevice.pair(inviter: inviter.device, joiner: d.device);
    inviter.forgetSnapshots();
    _event('keyLost|${d.name}|${saved.step}|$loseLedger|${action.name}|${d.device.memberId}'
        '|removedBy=${remover.name}|invitedBy=${inviter.name}');
  }

  /// Models the user acting on the "re-invite X" prompt (not built yet; the
  /// app will derive it from the stranded member ids of the origin switch):
  /// the remover re-invites every device whose invite row was left behind.
  Future<void> _reinviteStranded(_Dev lost, Set<String> stranded, _Dev remover) async {
    for (final memberId in stranded) {
      final name = _simOfMember[memberId];
      final joiner = _devs.where((x) => x.name == name && x != lost && _inG1(x)).firstOrNull;
      if (joiner == null) continue;
      final inviters = _g1Finals(except: joiner).where((x) => x != lost).toList();
      if (inviters.isEmpty) continue;
      // Class-C discriminator (Efe ruling): a stranded member whose key is
      // revoked can only come back as a FRESH identity via an aware inviter;
      // pair() with the revoked key would throw, so skip instead.
      final joinerPub = joiner.membership.identity.ed25519Pub;
      final revokedSomewhere = inviters.any((x) => x.membership.isExcluded(joinerPub));
      if (revokedSomewhere) {
        _stats.count('skip.reinviteRevoked');
        _event('reinviteSkipped|revoked|${joiner.name}|${joiner.device.memberId.substring(0, 6)}');
        continue;
      }
      _stats.count('op.reinvite');
      final inviter = inviters.contains(remover) ? remover : _pick(inviters);
      await SyncDevice.pair(inviter: inviter.device, joiner: joiner.device);
      inviter.forgetSnapshots();
    }
    remover.forgetSnapshots();
  }

  /// Replace-import (`local_reset`): a random subset of existing items'
  /// fields with fresh values.
  Future<void> _replaceImport(_Dev d) async {
    final keys = <CellKey>{};
    final want = 1 + _rng.nextInt(12);
    for (var attempt = 0; attempt < 3 * want && keys.length < 2 * want && _itemPks.isNotEmpty; attempt++) {
      final pk = _pick(_itemPks);
      if (_existence(d, _item, pk) == RowExistence.absent) continue;
      for (final col in _fields) {
        if (_rng.nextBool()) keys.add(CellKey(_item, pk, col));
      }
    }
    if (keys.isEmpty) return _stats.count('skip.replaceImport');
    _stats.count('op.replaceImport');
    final cells = [for (final key in keys) (key, '${d.name}:$_step:import:${key.pk}:${key.col}')];
    final wall = d.device.now();
    await d.device.replaceImport(cells);
    for (final (key, value) in cells) {
      _record(d, d.store.read(key)!, wall, expected: value);
    }
    _event('replaceImport|${d.name}|${cells.length}');
  }

  /// Injected apply failure (Scenario 1.9): changes of one item fail on [d]
  /// for its next 1–3 sessions.
  void _applyFault(_Dev d) {
    if (d.faultSessions > 0 || _itemPks.isEmpty) return _stats.count('skip.applyFault');
    _stats.count('op.applyFault');
    final pk = _pick(_itemPks);
    d.faultSessions = 1 + _rng.nextInt(3);
    d.store.applyFault = (change) => change.tbl == _item && change.pk == pk;
    _event('fault|${d.name}|$pk|${d.faultSessions}');
  }

  /// `d{n-1}` leaves G2 and joins G1 (confirmed group switch, NB-1).
  Future<void> _groupSwitch() async {
    final inviters = _g1Finals(except: _switcher);
    if (inviters.isEmpty) return;
    final inviter = _pick(inviters);
    final before = {for (final m in inviter.membership.activeMembers) m.memberId};
    await SyncDevice.pair(inviter: inviter.device, joiner: _switcher.device, confirmGroupSwitch: true);
    _switched = true;
    _stats.count('op.groupSwitch');
    _switcher.forgetSnapshots();
    inviter.forgetSnapshots();
    final after = {for (final m in _switcher.membership.activeMembers) m.memberId};
    final expected = {...before, _switcher.device.memberId};
    if (after.length != expected.length || !after.containsAll(expected)) {
      _violate(OracleViolationKind.membership, _switcher.name, 'groupSwitch',
          'view ${_names(after)} != inviter view before ∪ joiner ${_names(expected)}');
    }
    _event('switch|${_switcher.name}|${inviter.name}');
  }

  /// A random G1 member that knows the revokee removes it (FR-026).
  Future<void> _removeRevokee() async {
    final removers = [
      for (final x in _g1Finals())
        if (x.membership.memberById(_revokee.device.memberId) != null) x
    ];
    if (removers.isEmpty) return;
    final remover = _pick(removers);
    await remover.device.removeMember(_revokee.device.memberId);
    remover.forgetSnapshots();
    _removed = true;
    _stats.count('op.removeMember');
    _event('remove|${_revokee.name}|${remover.name}');
  }

  String _names(Iterable<String> memberIds) =>
      (memberIds.map((id) => _simOfMember[id] ?? id.substring(0, 6)).toList()..sort()).join(',');

  // --------------------------------------------------------------- network

  void _repartition() {
    _stats.partitions++;
    final split = _rng.nextDouble() < config.partitionedProbability;
    for (final d in _devs) {
      d.partition = split ? _rng.nextInt(3) : 0;
    }
    _trace.add('p|${_devs.map((d) => d.partition).join(',')}');
  }

  TransportFaults _randomFaults() {
    if (_rng.nextDouble() >= tuning.transportFaultProbability) return TransportFaults.none;
    final frame = _rng.nextInt(tuning.maxFaultFrame);
    switch (_rng.nextInt(3)) {
      case 0:
        _stats.cut++;
        return TransportFaults(cutAfter: frame);
      case 1:
        _stats.duplicated++;
        return TransportFaults(duplicate: {frame});
      default:
        _stats.reordered++;
        return TransportFaults(reorder: {frame});
    }
  }

  Future<void> _randomSession() async {
    final a = _pick(_devs);
    final group = a.membership.groupId;
    if (group == null) return;
    final peers = [
      for (final b in _devs)
        if (b != a && b.partition == a.partition && b.membership.groupId == group) b
    ];
    if (peers.isEmpty) return;
    final b = _pick(peers);
    await _session(a, b, _randomFaults());
  }

  /// After the switch the G2 outsider keeps trying G1 members.
  Future<void> _outsiderAttempt() async {
    final peers = [
      for (final b in _devs)
        if (b != _outsider && b.partition == _outsider.partition && b.membership.groupId == _g1) b
    ];
    if (peers.isEmpty) return;
    final b = _pick(peers);
    _stats.count('session.outsiderAttempt');
    if (_rng.nextBool()) {
      await _session(_outsider, b, _randomFaults());
    } else {
      await _session(b, _outsider, _randomFaults());
    }
  }

  /// Why an exchange between [a] and [b] must not complete, or `null`.
  String? _forbidden(_Dev a, _Dev b) {
    if (_switched && (a == _outsider || b == _outsider)) return 'G2 outsider after the group switch';
    if (a == _revokee && b.membership.isRevokedEd(_revokeePub)) return '${b.name} knew the revocation';
    if (b == _revokee && a.membership.isRevokedEd(_revokeePub)) return '${a.name} knew the revocation';
    return null;
  }

  bool _mutuallyAccepted(_Dev a, _Dev b) =>
      a.membership.groupId != null &&
      a.membership.groupId == b.membership.groupId &&
      a.membership.acceptsStatic(b.membership.identity.x25519Pub) &&
      b.membership.acceptsStatic(a.membership.identity.x25519Pub);

  /// Before-versions of held envelopes' cells (they may be applied by the
  /// session's held retry).
  Map<CellKey, CellRecord?> _heldCells(_Dev d) => {
        for (final h in d.store.heldEnvelopes)
          if (_isUserTable(h.envelope.tbl)) h.key: d.store.read(h.key)
      };

  void _touch(_Dev d, Map<CellKey, CellRecord?> touched, ChangeBatchMessage batch) {
    for (final e in batch.envelopes) {
      if (!_isUserTable(e.tbl)) continue;
      final key = CellKey(e.tbl, e.pk, e.col);
      touched.putIfAbsent(key, () => d.store.read(key));
    }
  }

  /// Efe ruling (class C): model the user acting on the repair prompt.
  /// After ANY stranding op (keyLost, restoreDir, fullRollback), a device
  /// with needsRepairing re-pairs itself when its own rows are unrooted, and
  /// an active member re-invites the members whose rows stranded on the
  /// sealed origin. Revoked keys are never re-invited (they may only return
  /// as fresh identities).
  Future<void> _repairStranded(_Dev d) async {
    if (!d.device.needsRepairing || simRepairDisabled) return;
    _stats.count('op.repair');
    final stranded = strandedMemberIds(d.store, d.device.memberId);
    _event('repair|${d.name}|stranded=${stranded.length}');
    if (stranded.isNotEmpty) {
      final others = _g1Finals(except: d).where((x) => x != d).toList();
      if (others.isNotEmpty) await _reinviteStranded(d, stranded, _pick(others));
    }
    // Re-pair the device itself: its own member/invite rows are unrooted for
    // peers (sessions fail notAuthorized until an inviter re-vouches them).
    final inviters = [
      for (final x in _g1Finals(except: d))
        if (x.membership.memberById(d.device.memberId) != null || stranded.isNotEmpty) x,
    ];
    if (inviters.isNotEmpty) {
      _stats.count('op.repairRejoin');
      final inviter = _pick(inviters);
      await SyncDevice.pair(inviter: inviter.device, joiner: d.device);
      inviter.forgetSnapshots();
      _event('repairRejoin|${d.name}|${inviter.name}');
    }
  }

  /// One session ([a] initiates). Returns whether it was not quiet: any
  /// stored version changed, anything was applied, or it did not complete.
  Future<bool> _session(_Dev a, _Dev b, TransportFaults faults) async {
    _stats.sessions++;
    final forbidden = _forbidden(a, b);
    final expectExchange = identical(faults, TransportFaults.none) && _mutuallyAccepted(a, b);
    final faultA = a.faultSessions > 0;
    final faultB = b.faultSessions > 0;
    final touchedA = _heldCells(a);
    final touchedB = _heldCells(b);
    final countA = a.store.cellCount;
    final countB = b.store.cellCount;
    final pair = await SyncDevice.syncPair(
      a.device,
      b.device,
      faults: faults,
      hooksA: SessionHooks(beforeApply: (batch) => _touch(a, touchedA, batch)),
      hooksB: SessionHooks(beforeApply: (batch) => _touch(b, touchedB, batch)),
    );
    _checkOutcome(a, b, pair.initiator, faultA, forbidden, expectExchange);
    _checkOutcome(b, a, pair.responder, faultB, forbidden, expectExchange);
    a.roundOutcome = pair.initiator;
    b.roundOutcome = pair.responder;
    final changedA = _afterSession(a, touchedA, countA);
    final changedB = _afterSession(b, touchedB, countB);
    for (final d in [a, b]) {
      if (d.faultSessions > 0 && --d.faultSessions == 0) d.store.applyFault = null;
    }
    if (pair.retried) _stats.count('session.retriedAfterRestore');
    final applied = pair.initiator.stats.applied +
        pair.responder.stats.applied +
        pair.initiator.stats.heldRetriedApplied +
        pair.responder.stats.heldRetriedApplied;
    _stats.messages += pair.initiator.stats.envelopesReceived + pair.responder.stats.envelopesReceived;
    final event = 's|${a.name}|${b.name}|$faults|${_outcome(pair.initiator)}|${_outcome(pair.responder)}'
        '|${pair.retried}|$changedA|$changedB';
    _trace.add(event);
    if (_step >= config.ops || !pair.bothComplete && faults == TransportFaults.none) _log(event);
    return changedA || changedB || applied > 0 || !pair.bothComplete;
  }

  String _outcome(SessionResult r) {
    final String name;
    switch (r) {
      case SessionComplete():
        name = 'complete';
      case SessionPartial(:final reasons):
        name = 'partial(${(reasons.map((x) => x.name).toList()..sort()).join('+')})';
      case SessionFailed(:final category):
        name = 'failed.${category.name}';
    }
    _stats.count('session.$name');
    return '$name/${r.stats.applied}/${r.stats.envelopesReceived}';
  }

  void _checkOutcome(_Dev x, _Dev peer, SessionResult r, bool faultActive, String? forbidden, bool expectExchange) {
    String? problem;
    switch (r) {
      case SessionComplete():
        break;
      case SessionPartial(:final reasons, :final stats):
        for (final reason in reasons) {
          switch (reason) {
            case PartialReason.itemsFailed:
              if (!faultActive) problem = 'itemsFailed without an injected apply fault';
            case PartialReason.itemsRejected:
              if (stats.rejectedByReason.keys.any((k) => k != _revokedCategory)) {
                problem = 'items rejected ${stats.rejectedByReason}';
              }
            case PartialReason.storageError:
              problem = 'storageError without a sync-ledger fault';
          }
        }
      case SessionFailed(:final category, :final error):
        if (!_allowedFailures.contains(category)) {
          problem = 'failed ${category.name}: $error';
        } else if (expectExchange &&
            category != SessionFailure.restoreDetected &&
            category != SessionFailure.peerPreparing) {
          problem = 'failed ${category.name} without faults between mutually accepted members';
        }
    }
    final subject = '${x.name}<->${peer.name}@$_step';
    if (problem != null) _violate(OracleViolationKind.sessionOutcome, x.name, subject, problem);
    if (forbidden != null && r.exchanged) _violate(OracleViolationKind.groupLeak, x.name, subject, forbidden);
  }

  int? _idOf(CellRecord r) {
    return _oracle.writeIdOfCopy(r.key.table, r.key.pk, r.key.col, r.node, r.clock, r.value);
  }

  /// The oracle write a held envelope carries, matched by version and, when the
  /// device holds the epoch key, by value, so an old copy under a reused
  /// version is unrecorded like a stored one ([_idOf]). Without the key only
  /// the version can be matched.
  int? _heldWriteId(_Dev d, ChangeEnvelope e) {
    final membership = d.membership;
    final groupId = membership.groupId;
    final versionOnly = _oracle.writeIdOfVersion(e.tbl, e.pk, e.col, e.node, e.hlc);
    if (groupId == null) {
      _stats.count('final.heldVersionOnly');
      return versionOnly;
    }
    final opened = EnvelopeCipher(groupId: groupId, keyring: membership.keyring).open(e);
    if (opened is! EnvelopeOpened) {
      _stats.count('final.heldVersionOnly');
      return versionOnly;
    }
    return _oracle.writeIdOfCopy(e.tbl, e.pk, e.col, e.node, e.hlc, opened.change.value.toDart());
  }

  /// FR-007 around a session: every touched cell keeps its version or moves
  /// to one the oracle orders after it; newly stored versions join the
  /// device's causal knowledge. Returns whether any version changed.
  bool _afterSession(_Dev d, Map<CellKey, CellRecord?> touched, int countBefore) {
    var changed = false;
    for (final entry in touched.entries) {
      final before = entry.value;
      final after = d.store.read(entry.key);
      final cellKey = oracleCellKey(entry.key.table, entry.key.pk, entry.key.col);
      if (after == null) {
        if (before != null) _violate(OracleViolationKind.regression, d.name, cellKey, 'lost $before in a session');
        continue;
      }
      if (before != null && before.clock == after.clock && before.node == after.node) continue;
      changed = true;
      final afterId = _idOf(after);
      if (afterId == null) {
        _violate(OracleViolationKind.unknownVersion, d.name, cellKey, 'stored unrecorded $after');
        continue;
      }
      _oracle.observeStored(d.name, afterId);
      if (before == null) continue;
      final v = checkNoRegression(_oracle, device: d.name, cellKey: cellKey, before: _idOf(before), after: afterId);
      if (v != null) _violations.add(v);
    }
    if (d.store.cellCount < countBefore) {
      _violate(OracleViolationKind.regression, d.name, '*', 'cell count ${d.store.cellCount} < $countBefore');
    }
    return changed;
  }

  // ------------------------------------------------------------ final phase

  Future<void> _finalPhase() async {
    for (final d in _devs) {
      d.store.applyFault = null;
      d.faultSessions = 0;
      d.partition = 0;
    }
    // Required (H) and optional versions, before the final sync.
    final required = <int>{};
    final optional = <int>{};
    for (final d in _finals) {
      if (d.device.needsRepairing) {
        _stats.count('endgame.needsRepairing');
        continue;
      }
      for (final record in d.store.cells) {
        if (!_isUserTable(record.key.table)) continue;
        final id = _idOf(record);
        if (id == null) {
          _violate(OracleViolationKind.unknownVersion, d.name, '${record.key}', 'holds unrecorded $record');
        } else {
          required.add(id);
        }
      }
      for (final h in d.store.heldEnvelopes) {
        final e = h.envelope;
        if (!_isUserTable(e.tbl)) continue;
        final id = _heldWriteId(d, e);
        if (id == null) {
          _violate(OracleViolationKind.unknownVersion, d.name, '${h.key}', 'holds unrecorded envelope $h');
        } else if (h.category == _revokedCategory) {
          optional.add(id);
        } else {
          required.add(id);
        }
      }
    }
    optional.removeAll(required);
    _stats
      ..count('final.required', required.length)
      ..count('final.optional', optional.length);

    if (engineSimLog != null) _logMembershipViews();
    final quiesceSet = [
      for (final d in _finals)
        if (!d.device.needsRepairing) d
    ];
    var quietRounds = 0;
    final authFailRounds = {for (final d in quiesceSet) d.name: 0};
    final otherFailRounds = {for (final d in quiesceSet) d.name: 0};
    for (var round = 0; round < tuning.maxFinalRounds && quietRounds < 2; round++) {
      _stats.finalRounds++;
      var busy = false;
      final roundAuthFail = {for (final d in quiesceSet) d.name: 0};
      final roundOtherFail = {for (final d in quiesceSet) d.name: 0};
      _lastRoundAuthFail.clear();
      final provisionallyExcluded = <String>{
        for (final d in quiesceSet)
          if (authFailRounds[d.name]! >= 2 && otherFailRounds[d.name]! == 0) d.name,
      };
      for (var i = 0; i < quiesceSet.length; i++) {
        for (var j = i + 1; j < quiesceSet.length; j++) {
          final involvesExcluded =
              provisionallyExcluded.contains(quiesceSet[i].name) || provisionallyExcluded.contains(quiesceSet[j].name);
          if (await _session(quiesceSet[i], quiesceSet[j], TransportFaults.none)) {
            if (!involvesExcluded) busy = true;
          }
          _recordAuthEvidence(quiesceSet[i], quiesceSet[j], roundAuthFail, roundOtherFail);
          _recordPairOutcome(quiesceSet[i], quiesceSet[j]);
        }
      }
      for (final d in quiesceSet) {
        authFailRounds[d.name] = roundAuthFail[d.name]! > 0 ? authFailRounds[d.name]! + 1 : 0;
        otherFailRounds[d.name] = roundOtherFail[d.name]!;
      }
      quietRounds = busy ? 0 : quietRounds + 1;
    }
    if (quietRounds < 2) {
      _violate(OracleViolationKind.notQuiescent, '*', '*', 'after ${tuning.maxFinalRounds} rounds');
    }

    // Efe ruling (stale restore): exclude a staleRestored device only on
    // auth-only failure evidence to every converged device for K consecutive
    // final rounds; a device some converged device still accepts keeps its
    // violations (real bug). Excluded devices' cells leave required/optional
    // and observed.
    final excluded = _staleExcluded(quiesceSet, authFailRounds, otherFailRounds);
    if (excluded.isNotEmpty) {
      final excludedCells = <int>{};
      final convergedCells = <int>{};
      for (final d in quiesceSet) {
        final target = excluded.contains(d.name) ? excludedCells : convergedCells;
        for (final record in d.store.cells) {
          if (!_isUserTable(record.key.table)) continue;
          final id = _idOf(record);
          if (id != null) target.add(id);
        }
        for (final h in d.store.heldEnvelopes) {
          final id = _heldWriteId(d, h.envelope);
          if (id != null) target.add(id);
        }
      }
      required.removeWhere((id) => excludedCells.contains(id) && !convergedCells.contains(id));
      optional.removeWhere((id) => excludedCells.contains(id) && !convergedCells.contains(id));
    }
    if (engineSimLog != null) {
      _log('--- post-rounds ---');
      _logMembershipViews();
      _logRevocationState();
      _logRegistrations();
      await _logRegistrationRemerge();
    }
    final observed = [for (final d in quiesceSet.where((d) => !excluded.contains(d.name))) _observe(d)];
    final check = checkEngineFinalState(
      _oracle,
      observed,
      required: required,
      optional: optional,
      outsiders: {_revokee.name, _outsider.name},
    );
    _violations.addAll(check.violations);
    for (final e in check.discards.entries) {
      _stats.count('discard.${e.key}', e.value);
    }
    _checkMembership(excluded);
    if (engineSimLog != null) _logHeldEnvelopes();
    var held = 0;
    for (final d in _finals) {
      held += d.store.heldEnvelopes.length;
    }
    _stats
      ..count('final.heldEnvelopes', held)
      ..count('final.incarnations', _oracle.incarnations);
    _traceFinalState();
  }

  // ------------------------------------------------------------ diagnostics

  String _epochName(EpochId e) => '${e.counter}.${_names([e.creator])}';

  void _logMembershipViews() {
    for (final d in _devs) {
      final m = d.membership;
      final view = _names(m.activeMembers.map((e) => e.memberId));
      final known = m.members.keys.map((k) => k.substring(0, 6)).join(',');
      _log('member ${d.name} id=${d.device.memberId.substring(0, 6)} group=${m.groupId == _g1 ? 'G1' : m.groupId} '
          'removed=${m.removed} view=$view known=$known held=${d.store.heldEnvelopes.length} '
          'epochs=${m.keyring.epochs.length}');
    }
  }

  /// Efe discriminator (intra-cluster divergence): every revocation row a
  /// device stores, and the ids its active view still counts, with the
  /// excluded set - so "has the record but view ignores it" vs "record never
  /// arrived" is decidable from the log.
  void _logRevocationState() {
    for (final d in _finals) {
      final revs = [
        for (final pk in d.store.rowsOf(SecurityTables.revocation))
          () {
            final cell = d.store.storedCell(CellKey(SecurityTables.revocation, pk, CellKey.rowCol));
            final value = cell?.record.value;
            if (value is! Uint8List) return null;
            try {
              final r = decodeRevocationRecord(value);
              return _short(r.revokedPub);
            } on Object {
              return null;
            }
          }(),
      ].nonNulls.toList()
        ..sort();
      final excluded = (d.membership.revocations?.revokedMembers ?? const []).map(_short).toList()..sort();
      _log('revstate ${d.name} rows=${revs.join(',')} excluded=${excluded.join(',')} '
          'active=${d.membership.activeMembers.map((e) => '${_short(e.ed25519Pub)}@${_simOfMember[e.memberId] ?? e.memberId.substring(0, 6)}').toList().join(',')} '
          'memberrows=${d.membership.members.keys.map((k) => '${_simOfMember[k] ?? k.substring(0, 6)}:${k.substring(0, 6)}').toList().join(',')}');
    }
  }

  static String _short(List<int> bytes) => bytes.take(6).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// ACF-45 probe: registrations the OTHER finals have but this device's
  /// store lacks - 'missing on receiver' made visible per origin.
  Future<void> _logRegistrationRemerge() async {
    final all = <String, OriginRegistration>{};
    for (final d in _finals) {
      for (final r in d.store.registrations) {
        all.putIfAbsent(r.origin.hex, () => r);
      }
    }
    for (final d in _finals) {
      final mine = d.store.registrations.map((r) => r.origin.hex).toSet();
      for (final e in all.entries) {
        if (mine.contains(e.key)) continue;
        final row = e.value;
        final ok = await verifyOriginRegistration(d.membership.groupId!, row);
        _log('remerge ${d.name} ${e.key.substring(0, 6)} verify=$ok');
      }
    }
  }

  /// ACF-45 probe: registrations per device (origin->signer), so owner
  /// availability on each peer is decidable from the log.
  void _logRegistrations() {
    for (final d in _finals) {
      final regs = [
        for (final r in d.store.registrations) '${r.origin.hex.substring(0, 6)}<-${_short(r.memberPub)}',
      ]..sort();
      _log('regs ${d.name} ${regs.join(',')}');
    }
  }

  /// Held envelopes by reason, missing epoch keys vs. own grants, and the
  /// authors of member rows, per final device.
  void _logHeldEnvelopes() {
    for (final d in _finals) {
      final m = d.membership;
      final byReason = <String, int>{};
      final missing = <String, int>{};
      for (final h in d.store.heldEnvelopes) {
        final e = h.envelope;
        final table = _isUserTable(e.tbl) ? 'user' : e.tbl;
        final k = '$table/${h.reason.name}/${h.category}/signer=${_names([e.node])}';
        byReason[k] = (byReason[k] ?? 0) + 1;
        if (h.reason == HeldReason.missingKey) missing[_epochName(e.epoch)] = (missing[_epochName(e.epoch)] ?? 0) + 1;
      }
      final heldEpochs = (m.keyring.epochs.toList()..sort()).map(_epochName).join(' ');
      final ownPub = m.identity.ed25519Pub;
      final granted = [
        for (final g in m.grants)
          if (_same(g.memberPub, ownPub)) _epochName(g.epoch)
      ].join(' ');
      _log('held ${d.name} $byReason');
      _log('epochs ${d.name} missingKeyFor=$missing held=$heldEpochs grantedToMe=$granted');
      for (final pk in d.store.rowsOf(SecurityTables.member)) {
        final c = d.store.read(CellKey(SecurityTables.member, pk, CellKey.rowCol));
        _log('memberRow ${d.name} ${pk.substring(0, 6)} by=${c == null ? '-' : _names([c.node])} '
            'origin=${c?.origin.substring(0, 6)}#${c?.originSeq}');
      }
    }
  }

  /// Per-device evidence of one final-phase session: auth-only failure
  /// (notAuthorized/refusedByPeer) counts toward the stale exclusion; any
  /// other failure kind blocks it (Efe ruling).
  void _recordAuthEvidence(_Dev a, _Dev b, Map<String, int> roundAuthFail, Map<String, int> roundOtherFail) {
    // A pair is an auth failure when either side saw notAuthorized or
    // refusedByPeer; the responder-side mirror of a refused handshake can
    // surface as notReachable, which is still this pair's auth rejection.
    final pairAuthFail = _authOnlyFailure(a.roundOutcome) ||
        _authOnlyFailure(b.roundOutcome) ||
        (a.roundOutcome is SessionFailed && b.roundOutcome is SessionFailed);
    if (pairAuthFail && (a.roundOutcome is SessionFailed || b.roundOutcome is SessionFailed)) {
      roundAuthFail[a.name] = roundAuthFail[a.name]! + 1;
      roundAuthFail[b.name] = roundAuthFail[b.name]! + 1;
      return;
    }
    for (final entry in [a, b]) {
      final r = entry.roundOutcome;
      if (r is SessionFailed) roundOtherFail[entry.name] = roundOtherFail[entry.name]! + 1;
    }
  }

  /// Efe ruling (amended): partition the quiesce set into clusters by
  /// mutual-complete sessions. A cluster is excludable-as-stale iff EVERY
  /// device in it is stale-marked AND every device outside it auth-fails it
  /// (K consecutive rounds, no other failure kind). Clusters holding a
  /// never-stale device are never excludable: their divergence gates.
  Set<String> _staleExcluded(List<_Dev> quiesceSet, Map<String, int> authFailRounds, Map<String, int> otherFailRounds) {
    final names = [for (final d in quiesceSet) d.name];
    final stale = {for (final d in quiesceSet) d.name: d.staleRestored};
    final pairAuthFail = {
      for (final e in _lastRoundAuthFail.entries) e.key: e.value,
    };
    return decideStaleExclusion(
      names: names,
      stale: stale,
      pairAuthFail: pairAuthFail,
      authFailRounds: authFailRounds,
      otherFailRounds: otherFailRounds,
      onExcluded: (cluster) => _stats.count('endgame.staleExcluded', cluster.length),
      onWholeSetStale: (size) => _stats.count('endgame.staleClusterDivergence', size),
    );
  }

  /// Pairwise final-phase outcomes of the LAST round: 'a|b' -> true when
  /// either side saw an auth-only failure (cluster edges need mutual
  /// completes, so any failure breaks the edge).
  final Map<String, bool> _lastRoundAuthFail = {};

  void _recordPairOutcome(_Dev a, _Dev b) {
    final key = [a.name, b.name]..sort();
    _lastRoundAuthFail['${key[0]}|${key[1]}'] = _authOnlyFailure(a.roundOutcome) || _authOnlyFailure(b.roundOutcome);
  }

  bool _authOnlyFailure(SessionResult? r) =>
      r is SessionFailed && (r.category == SessionFailure.notAuthorized || r.category == SessionFailure.refusedByPeer);

  /// T12 acc 8: every final device's view is exactly the final devices'
  /// current identities (the revokee and old key-lost identities revoked, no
  /// G2 member ever known in G1).
  void _checkMembership(Set<String> excluded) {
    final expected = {for (final d in _finals) d.device.memberId};
    // Efe ruling (stranded-revoked, A+C): an identity whose every revocation
    // record was authored inside the excluded stale cluster cannot be
    // expected revoked on the converged set; inside the stale cluster it IS
    // still expected revoked (holders kept their records).
    final strandedRevoked = _strandedRevokedPubs(excluded);
    for (final d in _finals) {
      if (excluded.contains(d.name)) continue;
      if (d.device.needsRepairing) {
        // Efe ruling: an unrepaired device is fail-closed by design; only a
        // re-paired device must converge. Counted, not violated.
        _stats.count('endgame.needsRepairing');
        continue;
      }
      final staleDevice = excluded.contains(d.name);
      if (!staleDevice) {
        for (final pub in strandedRevoked) {
          if (d.membership.isRevokedEd(pub)) {
            _violate(OracleViolationKind.membership, d.name, 'strandedRevokedEnforced',
                'converged device revoked a stranded-revoked identity without the record crossing');
          }
        }
      }
      final m = d.membership;
      if (m.groupId != _g1 || m.removed) {
        _violate(OracleViolationKind.membership, d.name, 'group', 'group ${m.groupId} removed=${m.removed}');
      }
      final view = {
        for (final e in m.activeMembers)
          if (!staleDevice || !strandedRevoked.any((pub) => _same(e.ed25519Pub, pub))) e.memberId,
      };
      final expectSet =
          staleDevice ? expected.difference({for (final p in strandedRevoked) _memberIdOfPub(p)}) : expected;
      if (view.length != expectSet.length || !view.containsAll(expectSet)) {
        _violate(OracleViolationKind.membership, d.name, 'view', '${_names(view)} != ${_names(expectSet)}');
      }
      if (m.members.containsKey(_outsider.device.memberId)) {
        _violate(OracleViolationKind.membership, d.name, 'members', 'knows the G2 outsider');
      }
      if (_removed && !m.isRevokedEd(_revokeePub)) {
        _violate(OracleViolationKind.membership, d.name, 'revocation', 'revokee not revoked');
      }
      if (m.flaggedAnchorsWithoutRecord.isNotEmpty) {
        _violate(OracleViolationKind.membership, d.name, 'anchorRecord', 'flagged anchor without a revocation record');
      }
    }
  }

  /// Efe ruling (stranded-revoked): pubs whose EVERY revocation record was
  /// authored by a device inside [excluded]. Stat per identity.
  Set<List<int>> _strandedRevokedPubs(Set<String> excluded) {
    if (excluded.isEmpty) return const {};
    final out = <List<int>>{};
    final records = <List<int>, Map<String, List<String>>>{};
    for (final d in _finals) {
      for (final pk in d.store.rowsOf(SecurityTables.revocation)) {
        final cell = d.store.storedCell(CellKey(SecurityTables.revocation, pk, CellKey.rowCol));
        final value = cell?.record.value;
        if (value is! Uint8List) continue;
        try {
          final r = decodeRevocationRecord(value);
          records.putIfAbsent(r.revokedPub, () => {})[d.name] = [
            ...(records[r.revokedPub]?[d.name] ?? const []),
            '${cell!.record.origin.substring(0, 6)}#${cell.record.originSeq}',
          ];
        } on Object {
          continue;
        }
      }
    }
    for (final e in records.entries) {
      final holders = e.value.keys.toSet();
      if (holders.isNotEmpty && excluded.containsAll(holders)) {
        out.add(e.key);
        _stats.count('endgame.revocationStrandedInStaleCluster');
        if (engineSimLog != null) {
          _log('strandedRevoked pub=${_short(e.key)} authors=${holders.join(',')} '
              'carriers=${e.value.values.expand((v) => v).join(',')}');
        }
      }
    }
    return out;
  }

  /// The member id of a device holding [pub]'s identity, or '' (used to
  /// relax the expected set inside the stale cluster).
  String _memberIdOfPub(List<int> pub) {
    for (final d in _devs) {
      if (_same(d.membership.identity.ed25519Pub, pub)) return d.device.memberId;
    }
    return '';
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  ObservedReplica _observe(_Dev d) {
    final cells = <String, ObservedCell>{};
    final rows = <String, bool>{};
    for (final record in d.store.cells) {
      final key = record.key;
      if (!_isUserTable(key.table)) continue;
      final cause = record.cause;
      cells[oracleCellKey(key.table, key.pk, key.col)] = ObservedCell(
        value: record.value,
        writeId: _idOf(record),
        author: _simOfMember[record.node] ?? 'member:${record.node}',
        cause: cause == null ? null : oracleRowKey(cause.table, cause.pk),
      );
      rows.putIfAbsent(oracleRowKey(key.table, key.pk), () => d.store.isRowAlive(key.table, key.pk));
    }
    return ObservedReplica(device: d.name, cells: cells, rowsAlive: rows);
  }

  void _traceFinalState() {
    for (final d in _finals) {
      for (final record in d.store.cells) {
        if (!_isUserTable(record.key.table)) continue;
        _trace.add('f|${d.name}|${record.key}|${record.value}|${record.clock}|${_simOfMember[record.node]}');
      }
    }
  }
}
