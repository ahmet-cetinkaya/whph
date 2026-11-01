/// Oracle checks over replica snapshots. The harness converts each replica into
/// an [ObservedReplica]; nothing here depends on the package under test.
library;

import 'reference_oracle.dart';

/// One cell as observed on a replica.
final class ObservedCell {
  const ObservedCell({required this.value, required this.writeId, required this.author, this.cause});

  final Object? value;

  /// The oracle write id of the held version, or `null` if the harness could
  /// not map it to a recorded write.
  final int? writeId;

  /// The authoring device the replica reports for the held version (the
  /// harness maps member ids to device names).
  final String author;

  /// The cascade cause (row key) the replica holds with the version.
  final String? cause;
}

/// Synced content of one replica, keyed by [oracleCellKey] / [oracleRowKey].
final class ObservedReplica {
  const ObservedReplica({required this.device, required this.cells, required this.rowsAlive});

  final String device;
  final Map<String, ObservedCell> cells;
  final Map<String, bool> rowsAlive;
}

/// (c) FR-007: a replica may only move a cell to a version the oracle orders
/// after the one it held.
OracleViolation? checkNoRegression(
  ReferenceOracle oracle, {
  required String device,
  required String cellKey,
  required int? before,
  required int? after,
}) {
  if (before == null || after == null || before == after) return null;
  final previous = oracle.write(before);
  final current = oracle.write(after);
  if (oracle.compare(current, previous) > 0) return null;
  final kind = previous.col == oracleExistenceCol && previous.value != null && current.value == null
      ? OracleViolationKind.resurrection
      : OracleViolationKind.regression;
  return OracleViolation(kind, device, cellKey, 'replaced $previous with older $current');
}

/// Final-state oracles (a) convergence, (b) no lost edits and FR-006
/// existence, (c) no resurrection, plus the D12 bucket rules.
List<OracleViolation> checkFinalState(ReferenceOracle oracle, List<ObservedReplica> replicas) {
  final violations = <OracleViolation>[...oracle.recordingViolations];
  if (replicas.isEmpty) return violations;

  // (a) All replicas hold identical synced content.
  final reference = replicas.first;
  for (final replica in replicas.skip(1)) {
    final keys = {...reference.cells.keys, ...replica.cells.keys};
    for (final key in keys) {
      final a = reference.cells[key];
      final b = replica.cells[key];
      if (a == null || b == null || a.value != b.value) {
        violations.add(
          OracleViolation(
            OracleViolationKind.divergence,
            replica.device,
            key,
            '${reference.device}=${a?.value} vs ${replica.device}=${b?.value}',
          ),
        );
      }
    }
    final rows = {...reference.rowsAlive.keys, ...replica.rowsAlive.keys};
    for (final row in rows) {
      if (reference.rowsAlive[row] != replica.rowsAlive[row]) {
        violations.add(
          OracleViolation(
            OracleViolationKind.divergence,
            replica.device,
            row,
            'alive ${reference.device}=${reference.rowsAlive[row]} vs ${replica.device}=${replica.rowsAlive[row]}',
          ),
        );
      }
    }
  }

  final winners = {for (final key in oracle.cellKeys) key: oracle.winner(key)!};
  final alive = {for (final row in oracle.rowKeys) row: oracle.expectedAlive(row)};
  final expectedTotals = oracle.expectedBucketTotals();

  for (final replica in replicas) {
    // (b) Every cell holds the oracle's winner.
    for (final entry in winners.entries) {
      final observed = replica.cells[entry.key];
      final expected = entry.value;
      if (observed == null || observed.writeId != expected.id) {
        final actual = observed?.writeId == null ? observed?.value : oracle.write(observed!.writeId!);
        violations.add(
          OracleViolation(OracleViolationKind.lostEdit, replica.device, entry.key, 'expected $expected, holds $actual'),
        );
      }
    }
    for (final entry in replica.cells.entries) {
      if (entry.value.writeId == null || !winners.containsKey(entry.key)) {
        violations.add(
          OracleViolation(OracleViolationKind.unknownVersion, replica.device, entry.key, 'value ${entry.value.value}'),
        );
      }
    }
    // (b)/(c) Effective existence (FR-006); alive-but-deleted is a resurrection.
    for (final entry in alive.entries) {
      final observed = replica.rowsAlive[entry.key] ?? false;
      if (observed == entry.value) continue;
      final kind = observed ? OracleViolationKind.resurrection : OracleViolationKind.existence;
      violations.add(OracleViolation(kind, replica.device, entry.key, 'expected alive=${entry.value}, is $observed'));
    }
    // D12: bucket rows hold only their owner's versions; totals add up.
    final observedTotals = <String, int>{};
    for (final entry in replica.cells.entries) {
      final rowKey = entry.key.substring(0, entry.key.lastIndexOf('|'));
      final bucket = oracle.bucketOf(rowKey);
      if (bucket == null) continue;
      if (entry.value.author != bucket.ownerDevice) {
        violations.add(
          OracleViolation(
            OracleViolationKind.bucketOwnership,
            replica.device,
            entry.key,
            'owner ${bucket.ownerDevice}, author ${entry.value.author}',
          ),
        );
      }
      observedTotals.putIfAbsent(bucket.group, () => 0);
      final value = entry.value.value;
      if (entry.key.endsWith('|$oracleRowCol') && (replica.rowsAlive[rowKey] ?? false) && value is int) {
        observedTotals[bucket.group] = observedTotals[bucket.group]! + value;
      }
    }
    for (final entry in expectedTotals.entries) {
      final observed = observedTotals[entry.key] ?? 0;
      if (observed != entry.value) {
        violations.add(
          OracleViolation(
            OracleViolationKind.bucketTotal,
            replica.device,
            entry.key,
            'expected total ${entry.value}, is $observed',
          ),
        );
      }
    }
  }
  return violations;
}

/// Result of [checkEngineFinalState].
final class EngineCheckResult {
  EngineCheckResult(this.violations, this.discards);

  final List<OracleViolation> violations;

  /// Recorded writes that were not required at the end of the run, by cause:
  /// `superseded` (beaten by the final winner), `lostOutsider` /
  /// `lostFinal` (would have beaten the final winner: lost with an outsider
  /// or revoked author, or with a restore, key loss or local reset).
  final Map<String, int> discards;
}

/// Final-state oracles for the real engine, where restores, key loss,
/// replace-import, revocation and group switches may legitimately lose
/// versions.
///
/// [required] are the versions held on any final device (cells, and held
/// envelopes not rejected as revoked) before the final sync; [optional] are
/// the held revoked-above-cutoff versions. After the final sync:
///
/// * (a) every replica holds the identical version of every cell and the
///   same effective existence of every row;
/// * (b) for every cell with required versions, the held version is required
///   or optional and wins over (or equals) each required version (else
///   [OracleViolationKind.lostEdit], or [OracleViolationKind.resurrection]
///   when an alive version replaced a required tombstone); a held version
///   outside both sets is [OracleViolationKind.unknownVersion];
/// * FR-006 / D5b effective existence, computed here over the held winners,
///   equals the replica's;
/// * D12: bucket rows hold only their owner's versions, and every group whose
///   cells all hold their required maximum totals the sum of those.
EngineCheckResult checkEngineFinalState(
  ReferenceOracle oracle,
  List<ObservedReplica> replicas, {
  required Set<int> required,
  required Set<int> optional,
  Set<String> outsiders = const {},
}) {
  final violations = <OracleViolation>[...oracle.recordingViolations];
  final discards = <String, int>{'superseded': 0, 'lostOutsider': 0, 'lostFinal': 0};
  if (replicas.isEmpty) return EngineCheckResult(violations, discards);

  // (a) Identical versions and existence everywhere.
  final reference = replicas.first;
  for (final replica in replicas.skip(1)) {
    for (final key in {...reference.cells.keys, ...replica.cells.keys}) {
      final a = reference.cells[key];
      final b = replica.cells[key];
      final same = a != null && b != null && (a.writeId != null ? a.writeId == b.writeId : a.value == b.value);
      if (!same) {
        violations.add(OracleViolation(
          OracleViolationKind.divergence,
          replica.device,
          key,
          '${reference.device}=${_describe(oracle, a)} vs ${replica.device}=${_describe(oracle, b)}',
        ));
      }
    }
    for (final row in {...reference.rowsAlive.keys, ...replica.rowsAlive.keys}) {
      if (reference.rowsAlive[row] != replica.rowsAlive[row]) {
        violations.add(OracleViolation(
          OracleViolationKind.divergence,
          replica.device,
          row,
          'alive ${reference.device}=${reference.rowsAlive[row]} vs ${replica.device}=${replica.rowsAlive[row]}',
        ));
      }
    }
  }

  final requiredByCell = <String, List<int>>{};
  for (final id in required) {
    requiredByCell.putIfAbsent(oracle.write(id).cellKey, () => []).add(id);
  }
  final requiredMax = {for (final e in requiredByCell.entries) e.key: oracle.maxOf(e.value)!};

  for (final replica in replicas) {
    final winners = <String, OracleWrite>{};
    // (b) Held versions are known, required or optional, with their cause.
    for (final entry in replica.cells.entries) {
      final id = entry.value.writeId;
      if (id == null) {
        violations.add(OracleViolation(
            OracleViolationKind.unknownVersion, replica.device, entry.key, 'unrecorded value ${entry.value.value}'));
        continue;
      }
      final w = oracle.write(id);
      winners[entry.key] = w;
      if (!required.contains(id) && !optional.contains(id)) {
        violations
            .add(OracleViolation(OracleViolationKind.unknownVersion, replica.device, entry.key, '$w neither required'));
      }
      if (w.cause != entry.value.cause) {
        violations.add(OracleViolation(
            OracleViolationKind.unknownVersion, replica.device, entry.key, '$w held with cause ${entry.value.cause}'));
      }
    }
    // (b) The held version wins over every required one.
    for (final entry in requiredByCell.entries) {
      final held = winners[entry.key];
      if (held == null) {
        if (!replica.cells.containsKey(entry.key)) {
          violations.add(OracleViolation(
              OracleViolationKind.lostEdit, replica.device, entry.key, 'missing; required ${requiredMax[entry.key]}'));
        }
        continue;
      }
      for (final id in entry.value) {
        final r = oracle.write(id);
        if (oracle.compare(held, r) >= 0) continue;
        final kind = r.isTombstone && held.col == oracleExistenceCol && held.value == null
            ? OracleViolationKind.resurrection
            : OracleViolationKind.lostEdit;
        violations.add(OracleViolation(kind, replica.device, entry.key, 'holds $held, required $r wins'));
        break;
      }
    }
    // FR-006 / D5b existence over the held winners.
    for (final entry in replica.rowsAlive.entries) {
      final expected = oracle.effectiveAlive(entry.key, (cellKey) => winners[cellKey]);
      if (expected == entry.value) continue;
      final kind = entry.value ? OracleViolationKind.resurrection : OracleViolationKind.existence;
      violations.add(OracleViolation(kind, replica.device, entry.key, 'expected alive=$expected, is ${entry.value}'));
    }
    // D12 ownership and totals.
    final eligible = <String, bool>{};
    final observedTotals = <String, int>{};
    for (final entry in replica.cells.entries) {
      final bucket = oracle.bucketOf(oracleRowOfCell(entry.key));
      if (bucket == null) continue;
      if (entry.value.author != bucket.ownerDevice) {
        violations.add(OracleViolation(OracleViolationKind.bucketOwnership, replica.device, entry.key,
            'owner ${bucket.ownerDevice}, author ${entry.value.author}'));
      }
    }
    for (final entry in oracle.buckets.entries) {
      final group = entry.value.group;
      var matches = eligible[group] ?? true;
      for (final cellKey in oracle.cellsOfRow(entry.key)) {
        if (winners[cellKey]?.id != requiredMax[cellKey]?.id) matches = false;
      }
      eligible[group] = matches;
      observedTotals.putIfAbsent(group, () => 0);
      final value = replica.cells['${entry.key}|$oracleRowCol']?.value;
      if ((replica.rowsAlive[entry.key] ?? false) && value is int) {
        observedTotals[group] = observedTotals[group]! + value;
      }
    }
    final expectedTotals = oracle.bucketTotals((cellKey) => requiredMax[cellKey]);
    for (final entry in expectedTotals.entries) {
      if (eligible[entry.key] != true) continue;
      final observed = observedTotals[entry.key] ?? 0;
      if (observed != entry.value) {
        violations.add(OracleViolation(
            OracleViolationKind.bucketTotal, replica.device, entry.key, 'expected total ${entry.value}, is $observed'));
      }
    }
  }

  // Allowed discards: recorded writes that were not required at the end.
  for (final cellKey in oracle.cellKeys) {
    final finalId = reference.cells[cellKey]?.writeId;
    final held = finalId == null ? null : oracle.write(finalId);
    for (final id in oracle.writesOfCell(cellKey)) {
      if (required.contains(id) || optional.contains(id)) continue;
      final w = oracle.write(id);
      if (held == null || oracle.compare(w, held) > 0) {
        final key = outsiders.contains(w.device) ? 'lostOutsider' : 'lostFinal';
        discards[key] = discards[key]! + 1;
      } else {
        discards['superseded'] = discards['superseded']! + 1;
      }
    }
  }
  return EngineCheckResult(violations, discards);
}

String _describe(ReferenceOracle oracle, ObservedCell? cell) {
  if (cell == null) return 'absent';
  final id = cell.writeId;
  return id == null ? 'unrecorded(${cell.value})' : '${oracle.write(id)}';
}
