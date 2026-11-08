/// Independent reference oracle for the convergence simulator.
///
/// It sees only what the harness reports: every local cell write (device,
/// local wall time, cell, value and, for the real engine, the recorded edit
/// time `hlc` and author `node` the engine stamped), every version a device
/// newly stores, and the points where a device's causal knowledge is reset
/// (restore, key loss: a new *incarnation*). From that it keeps its own causal
/// history (a vector clock per write, one entry per incarnation) and derives
/// the order of versions:
///
/// * FR-003: a write made after its device knew another write to the same
///   cell wins over it (causal order);
/// * FR-004: otherwise the later recorded time wins, exact ties by the smaller
///   node;
/// * FR-006 / D5b: a row is alive unless its `~` winner is a tombstone that is
///   not beaten by the winner of any other cell of the row; a tombstone with a
///   cause P is in force only while P is effectively deleted (an absent P and
///   a cause cycle count as deleted).
///
/// With engine-stamped times it also checks the stamps themselves: a write
/// that causally follows another write of the same cell must carry a larger
/// `(hlc, node)` ([OracleViolationKind.causality]) and every local tick obeys
/// `hlc >> 16 >= wall` ([OracleViolationKind.hlcTick]).
///
/// It must not import the package under test (see oracle_isolation_test.dart);
/// it imports nothing but its own files.
library;

import 'oracle_hlc.dart';

const oracleExistenceCol = '~';
const oracleRowCol = '*';

String oracleCellKey(String table, String pk, String col) => '$table|$pk|$col';

String oracleRowKey(String table, String pk) => '$table|$pk';

/// The row key of a cell key.
String oracleRowOfCell(String cellKey) => cellKey.substring(0, cellKey.lastIndexOf('|'));

/// The version key of a write: `(table, pk, col, node, hlc)` (FR-004 version
/// identity, stable under origin switches and adoption).
String oracleVersionKey(String table, String pk, String col, String node, int hlc) => '$table|$pk|$col|$node|$hlc';

/// Time-bucket row metadata (D12): the only device allowed to write the row
/// and the `(owner item, hour)` group whose total the row contributes to.
final class OracleBucketInfo {
  const OracleBucketInfo({required this.ownerDevice, required this.group});

  final String ownerDevice;
  final String group;
}

/// A saved causal knowledge (vector clock) of a device, e.g. taken together
/// with a DB snapshot and reinstated by [ReferenceOracle.startIncarnation].
final class OracleKnowledge {
  OracleKnowledge._(List<int> vector) : _vector = List<int>.unmodifiable(vector);

  final List<int> _vector;
}

/// One cell write as recorded by the oracle.
final class OracleWrite {
  OracleWrite._({
    required this.id,
    required this.device,
    required this.deviceIndex,
    required this.actor,
    required this.seqOnActor,
    required this.table,
    required this.pk,
    required this.col,
    required this.value,
    required this.hlc,
    required this.node,
    required this.cause,
    required this.wallMs,
    required this.history,
  });

  final int id;
  final String device;
  final int deviceIndex;

  /// The incarnation (vector-clock entry) that made the write.
  final int actor;

  /// 1-based index of this write among its incarnation's writes.
  final int seqOnActor;
  final String table;
  final String pk;
  final String col;
  final Object? value;

  /// Recorded edit time: the engine's stamp, or the oracle's own HLC when the
  /// replica under test reports none.
  final int hlc;

  /// Tie-break node: the author's member id, or the device name.
  final String node;

  /// Cascade cause (a row key) of a child tombstone, else `null`.
  final String? cause;

  /// The device's simulated wall time at the write.
  final int wallMs;

  /// Vector clock: per incarnation, how many of its writes this write's
  /// device knew (or made) when it made this write, including this write.
  /// Missing entries are 0.
  final List<int> history;

  String get cellKey => oracleCellKey(table, pk, col);
  String get rowKey => oracleRowKey(table, pk);
  bool get isTombstone => col == oracleExistenceCol && value != null;

  @override
  String toString() => 'w$id($device/a$actor#$seqOnActor $cellKey=$value hlc=$hlc node=$node'
      '${cause == null ? '' : ' cause=$cause'})';
}

enum OracleViolationKind {
  /// (a) replicas differ on synced content after the final sync.
  divergence,

  /// (b) a cell does not hold the oracle's winner (or a version beaten by a
  /// required one).
  lostEdit,

  /// (b) a row's effective existence differs from the oracle's (alive where
  /// the oracle expects deleted is reported as [resurrection]).
  existence,

  /// (c) a row is alive although the oracle expects it deleted, or an older
  /// alive version replaced a required tombstone.
  resurrection,

  /// (c) a replica replaced a version with one the oracle orders before it,
  /// or lost a cell during a session.
  regression,

  /// D12: a bucket row holds a version written by a device other than its owner.
  bucketOwnership,

  /// D12: an `(owner, hour)` total differs from the sum of bucket winners.
  bucketTotal,

  /// A replica holds a version the harness never recorded (or one that was
  /// neither required nor optional at the end of the run).
  unknownVersion,

  /// The final sync round did not reach quiescence.
  notQuiescent,

  /// An engine stamp contradicts causality: a write that causally follows
  /// another write of the same cell does not carry a larger `(hlc, node)`.
  causality,

  /// A local tick broke `hlc >> 16 >= wall`.
  hlcTick,

  /// Two distinct recorded writes share `(table, pk, col, node, hlc)`.
  ambiguousVersion,

  /// A session ended in an outcome the run cannot explain (an engine bug:
  /// `internal`, `protocolError`, unexplained partial or failure).
  sessionOutcome,

  /// A completed exchange across a group boundary or with a device known to
  /// be revoked (NB-1, FR-026).
  groupLeak,

  /// A final device's membership view is not the expected member set.
  membership,
}

final class OracleViolation {
  const OracleViolation(this.kind, this.device, this.subject, this.detail);

  final OracleViolationKind kind;
  final String device;
  final String subject;
  final String detail;

  @override
  String toString() => '${kind.name} on $device at $subject: $detail';
}

int _at(List<int> vector, int i) => i < vector.length ? vector[i] : 0;

final class ReferenceOracle {
  ReferenceOracle(List<String> devices) : devices = List.unmodifiable(devices) {
    for (var i = 0; i < devices.length; i++) {
      if (_indexOf.containsKey(devices[i])) throw ArgumentError('duplicate device ${devices[i]}');
      _indexOf[devices[i]] = i;
      _clocks.add(OracleHlc());
      _actorOf.add(i);
      _knowledge.add(List<int>.filled(devices.length, 0, growable: true));
    }
    _actors = devices.length;
  }

  final List<String> devices;
  final Map<String, int> _indexOf = {};
  final List<OracleHlc> _clocks = [];

  /// Per device, its current incarnation (vector-clock entry).
  final List<int> _actorOf = [];
  int _actors = 0;
  final List<List<int>> _knowledge = [];
  final List<OracleWrite> _writes = [];

  /// cellKey -> every write of the cell, in record order.
  final Map<String, List<int>> _cellWrites = {};

  /// cellKey -> per device index, the id of that device's latest write (-1).
  final Map<String, List<int>> _latestPerDevice = {};

  /// rowKey -> cellKeys of the row.
  final Map<String, Set<String>> _rowCells = {};
  final Map<String, OracleBucketInfo> _buckets = {};
  final Map<String, int> _byVersion = {};

  /// Ids of writes a restore dropped from their device.
  final Set<int> _vanished = {};

  /// Winner memo; cleared by every recorded write.
  final Map<String, OracleWrite?> _winnerCache = {};

  /// Violations found while recording (D12 ownership, causality, ticks,
  /// ambiguous versions).
  final List<OracleViolation> recordingViolations = [];

  List<OracleWrite> get writes => List.unmodifiable(_writes);

  OracleWrite write(int id) => _writes[id];

  Iterable<String> get cellKeys => _latestPerDevice.keys;

  Iterable<String> get rowKeys => _rowCells.keys;

  /// Ids of every recorded write of [cellKey], in record order.
  List<int> writesOfCell(String cellKey) => List.unmodifiable(_cellWrites[cellKey] ?? const <int>[]);

  /// Cell keys of [rowKey] ever written.
  Iterable<String> cellsOfRow(String rowKey) => _rowCells[rowKey] ?? const {};

  OracleBucketInfo? bucketOf(String rowKey) => _buckets[rowKey];

  /// Every bucket row with its metadata.
  Map<String, OracleBucketInfo> get buckets => Map.unmodifiable(_buckets);

  /// Number of incarnations so far (one per device plus one per restart).
  int get incarnations => _actors;

  /// Records a local cell write by [device] at its local wall time [wallMs].
  ///
  /// When [hlc] and [node] are given they are the engine's stamp of the write
  /// and are checked (tick rule, causality); otherwise the oracle stamps the
  /// write with its own HLC and the device name.
  OracleWrite recordWrite({
    required String device,
    required int wallMs,
    required String table,
    required String pk,
    required String col,
    required Object? value,
    int? hlc,
    String? node,
    String? cause,
    OracleBucketInfo? bucket,
  }) {
    if ((hlc == null) != (node == null)) throw ArgumentError('hlc and node go together');
    final d = _deviceIndex(device);
    final actor = _actorOf[d];
    final known = _knowledge[d];
    while (known.length <= actor) {
      known.add(0);
    }
    known[actor]++;
    final stamped = hlc != null;
    final w = OracleWrite._(
      id: _writes.length,
      device: device,
      deviceIndex: d,
      actor: actor,
      seqOnActor: known[actor],
      table: table,
      pk: pk,
      col: col,
      value: value,
      hlc: hlc ?? _clocks[d].tick(wallMs),
      node: node ?? device,
      cause: cause,
      wallMs: wallMs,
      history: List<int>.unmodifiable(known),
    );
    _writes.add(w);
    _winnerCache.clear();
    if (stamped && oracleHlcWall(w.hlc) < wallMs) {
      recordingViolations.add(
        OracleViolation(OracleViolationKind.hlcTick, device, w.cellKey, '$w below wall $wallMs'),
      );
    }
    final previous = _cellWrites.putIfAbsent(w.cellKey, () => []);
    for (final p in previous) {
      final earlier = _writes[p];
      if (happenedBefore(earlier, w) && oracleCompareVersions(w.hlc, w.node, earlier.hlc, earlier.node) <= 0) {
        recordingViolations.add(
          OracleViolation(OracleViolationKind.causality, device, w.cellKey, '$w causally follows $earlier'),
        );
      }
    }
    previous.add(w.id);
    final versionKey = oracleVersionKey(table, pk, col, w.node, w.hlc);
    final existing = _byVersion[versionKey];
    if (existing != null && _isReusable(existing)) {
      _byVersion[versionKey] = w.id;
    } else if (existing != null) {
      recordingViolations.add(
        OracleViolation(OracleViolationKind.ambiguousVersion, device, w.cellKey, '$w and ${_writes[existing]}'),
      );
    } else {
      _byVersion[versionKey] = w.id;
    }
    (_latestPerDevice[w.cellKey] ??= List<int>.filled(devices.length, -1))[d] = w.id;
    (_rowCells[w.rowKey] ??= <String>{}).add(w.cellKey);
    if (bucket != null) {
      final existingBucket = _buckets.putIfAbsent(w.rowKey, () => bucket);
      if (existingBucket.ownerDevice != bucket.ownerDevice || existingBucket.group != bucket.group) {
        throw StateError('inconsistent bucket metadata for ${w.rowKey}');
      }
      if (bucket.ownerDevice != device) {
        recordingViolations.add(
          OracleViolation(OracleViolationKind.bucketOwnership, device, w.cellKey, 'written by non-owner'),
        );
      }
    }
    return w;
  }

  /// The recorded write with version `(table, pk, col, node, hlc)`, or `null`.
  int? writeIdOfVersion(String table, String pk, String col, String node, int hlc) =>
      _byVersion[oracleVersionKey(table, pk, col, node, hlc)];

  /// The write a copy carries, matched by version and by [value]: a copy of
  /// an old write under a version that was since reused is `null` (unrecorded).
  int? writeIdOfCopy(String table, String pk, String col, String node, int hlc, Object? value) {
    final id = writeIdOfVersion(table, pk, col, node, hlc);
    return id == null || _writes[id].value != value ? null : id;
  }

  /// Records that [device] newly stores write [writeId]: its causal history
  /// joins the device's knowledge.
  void observeStored(String device, int writeId) {
    final known = _knowledge[_deviceIndex(device)];
    final history = _writes[writeId].history;
    while (known.length < history.length) {
      known.add(0);
    }
    for (var i = 0; i < history.length; i++) {
      if (history[i] > known[i]) known[i] = history[i];
    }
  }

  /// Records that [device] received write [writeId] in a delivered message
  /// (the plaintext protocol of the naive replica): knowledge and HLC.
  void recordDelivery(String device, int writeId) {
    observeStored(device, writeId);
    _clocks[_deviceIndex(device)].receive(_writes[writeId].hlc);
  }

  /// A copy of [device]'s current knowledge.
  OracleKnowledge knowledgeOf(String device) => OracleKnowledge._(_knowledge[_deviceIndex(device)]);

  /// Starts a new incarnation of [device] (DB-only restore, whole-directory
  /// restore, key loss with an old DB) whose knowledge is [knowledge], the
  /// knowledge saved with the restored snapshot. Later writes use a fresh
  /// vector-clock entry, so sequence numbers are never reused.
  void startIncarnation(String device, OracleKnowledge knowledge) {
    final d = _deviceIndex(device);
    _markVanishedWrites(d, knowledge._vector);
    _actorOf[d] = _actors++;
    _knowledge[d] = List<int>.of(knowledge._vector, growable: true);
  }

  /// Marks [d]'s writes that the restore to [restored] drops. A later write
  /// may reuse their `(node, hlc)` when no other device stored them by then:
  /// the engine's HLC floor only covers versions that left the device (F3).
  void _markVanishedWrites(int d, List<int> restored) {
    for (final w in _writes) {
      if (w.deviceIndex == d && w.seqOnActor > _at(restored, w.actor)) _vanished.add(w.id);
    }
  }

  bool _isReusable(int writeId) {
    if (!_vanished.contains(writeId)) return false;
    final w = _writes[writeId];
    for (var j = 0; j < _knowledge.length; j++) {
      if (j != w.deviceIndex && _at(_knowledge[j], w.actor) >= w.seqOnActor) return false;
    }
    return true;
  }

  /// Whether [a] is in the causal history of [b].
  bool happenedBefore(OracleWrite a, OracleWrite b) => a.id != b.id && _at(b.history, a.actor) >= a.seqOnActor;

  /// Positive when [a] wins over [b]: causal order first (FR-003), then
  /// `(hlc, node)` (FR-004). A stamp contradicting causality is reported when
  /// recorded ([OracleViolationKind.causality]); the causal order is kept.
  int compare(OracleWrite a, OracleWrite b) {
    if (a.id == b.id) return 0;
    if (happenedBefore(b, a)) return 1;
    if (happenedBefore(a, b)) return -1;
    return oracleCompareVersions(a.hlc, a.node, b.hlc, b.node);
  }

  /// The maximum of [ids] by [compare], or `null` when empty.
  OracleWrite? maxOf(Iterable<int> ids) {
    OracleWrite? best;
    for (final id in ids) {
      final w = _writes[id];
      if (best == null || compare(w, best) > 0) best = w;
    }
    return best;
  }

  /// The expected winning write of a cell over every recorded write (naive
  /// harness: no restores or membership losses), or `null` if never written.
  OracleWrite? winner(String cellKey) => _winnerCache.putIfAbsent(cellKey, () => _computeWinner(cellKey));

  OracleWrite? _computeWinner(String cellKey) {
    final latest = _latestPerDevice[cellKey];
    if (latest == null) return null;
    final candidates = [
      for (final id in latest)
        if (id >= 0) _writes[id]
    ];
    // Causally maximal candidates (each device's latest write dominates its
    // earlier ones), then the (hlc, node) order among concurrent ones.
    final maximal = [
      for (final c in candidates)
        if (!candidates.any((o) => happenedBefore(c, o))) c,
    ];
    OracleWrite? best;
    for (final c in maximal) {
      if (best == null || oracleCompareVersions(c.hlc, c.node, best.hlc, best.node) > 0) best = c;
    }
    // Cross-check: the winner must also beat every dominated candidate.
    for (final c in candidates) {
      if (c.id != best!.id && compare(best, c) <= 0) throw StateError('oracle winner $best does not beat $c');
    }
    return best;
  }

  /// Expected effective existence of a row over [winner] (naive harness).
  bool expectedAlive(String rowKey) => effectiveAlive(rowKey, (cellKey) => winner(cellKey));

  /// Effective existence of [rowKey] (FR-006, D5b) over the winners given by
  /// [winnerOf] (`null` = cell not held): alive unless the `~` winner is a
  /// tombstone no other cell winner of the row beats; a tombstone with a
  /// cause P is in force only while P is effectively deleted (absent P and a
  /// cause cycle count as deleted).
  bool effectiveAlive(String rowKey, OracleWrite? Function(String cellKey) winnerOf) =>
      _alive(rowKey, winnerOf, <String>{}) == true;

  /// `true` alive, `false` deleted, `null` absent.
  bool? _alive(String rowKey, OracleWrite? Function(String cellKey) winnerOf, Set<String> visiting) {
    OracleWrite? tomb;
    final others = <OracleWrite>[];
    for (final cellKey in cellsOfRow(rowKey)) {
      final w = winnerOf(cellKey);
      if (w == null) continue;
      if (w.col == oracleExistenceCol) {
        tomb = w;
      } else {
        others.add(w);
      }
    }
    if (tomb == null && others.isEmpty) return null;
    if (tomb == null || tomb.value == null) return true;
    if (others.any((o) => compare(o, tomb!) > 0)) return true;
    final cause = tomb.cause;
    if (cause == null || !visiting.add(rowKey)) return false;
    final parent = _alive(cause, winnerOf, visiting);
    visiting.remove(rowKey);
    return parent == true;
  }

  /// Expected `(owner, hour)` totals: the sum of the `*` winners of every
  /// alive bucket row of the group (naive harness).
  Map<String, int> expectedBucketTotals() => bucketTotals((cellKey) => winner(cellKey));

  /// `(owner, hour)` totals over the winners given by [winnerOf].
  Map<String, int> bucketTotals(OracleWrite? Function(String cellKey) winnerOf) {
    final totals = <String, int>{};
    for (final entry in _buckets.entries) {
      final group = entry.value.group;
      totals.putIfAbsent(group, () => 0);
      if (!effectiveAlive(entry.key, winnerOf)) continue;
      final value = winnerOf('${entry.key}|$oracleRowCol')?.value;
      if (value is int) totals[group] = totals[group]! + value;
    }
    return totals;
  }

  int _deviceIndex(String device) {
    final d = _indexOf[device];
    if (d == null) throw ArgumentError('unknown device $device');
    return d;
  }
}
