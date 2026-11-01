/// Engine-independent (SESSION_ENGINE=async or default) counterpart of the
/// seed-100006 stale-cluster rulings. Real devices end up in two clusters that
/// reject each other (a stale pair restored to an old DB, a converged group
/// that moved on); the sim's decision cores then rule on the evidence.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../simulation/engine_simulation.dart';
import 'session_test_support.dart';

const _finalRounds = 3;

String _pairKey(String x, String y) => ([x, y]..sort()).join('|');

bool _authOnly(SessionResult r) =>
    r is SessionFailed && (r.category == SessionFailure.notAuthorized || r.category == SessionFailure.refusedByPeer);

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Revoked identity (hex) -> names of the devices holding its revocation record.
Map<String, Set<String>> _revocationHolders(List<SyncDevice> devices) {
  final holders = <String, Set<String>>{};
  for (final device in devices) {
    for (final pk in device.store.rowsOf(SecurityTables.revocation)) {
      final value = device.store.storedCell(CellKey(SecurityTables.revocation, pk, CellKey.rowCol))?.record.value;
      if (value is! Uint8List) continue;
      holders.putIfAbsent(_hex(decodeRevocationRecord(value).revokedPub), () => {}).add(device.name);
    }
  }
  return holders;
}

void main() {
  test('stale pair excluded; its revocations stranded; its winner write relaxed', () async {
    final [a, b, c, d, f] = [for (var i = 0; i < 5; i++) await newDevice('D$i', seed: 900 + i)];
    final stale = [a, b];
    final converged = [c, d, f];
    await pairAll([a, b, c, d]);
    await syncUntilQuiet([a, b, c, d]);
    final snapshotA = await a.snapshotDb();
    final snapshotB = await b.snapshotDb();

    // The converged side moves on without a and b: revokes them, admits f.
    await c.removeMember(a.memberId);
    await c.removeMember(b.memberId);
    await SyncDevice.pair(inviter: c, joiner: f);
    for (var round = 0; round < 3; round++) {
      await runSessionPair(c, d);
      await runSessionPair(c, f);
      await runSessionPair(d, f);
    }

    await a.restoreDb(snapshotA);
    await b.restoreDb(snapshotB);
    for (final device in stale) {
      expect(device.membership.memberById(f.memberId), isNull, reason: '${device.name} restored behind f');
    }
    // The stale pair keeps working: it revokes the converged members and
    // writes a row nobody on the converged side ever receives.
    await a.removeMember(c.memberId);
    await a.removeMember(d.memberId);
    createRow(a, 'staleOnly', 'written by the stale pair');

    final all = [a, b, c, d, f];
    final authFailRounds = {for (final x in all) x.name: 0};
    final otherFailRounds = {for (final x in all) x.name: 0};
    final lastPairAuthFail = <String, bool>{};
    for (var round = 0; round < _finalRounds; round++) {
      final roundAuthFail = {for (final x in all) x.name: 0};
      final roundOtherFail = {for (final x in all) x.name: 0};
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          final x = all[i], y = all[j];
          final pair = await runSessionPair(x, y);
          final authOnly = _authOnly(pair.initiator) || _authOnly(pair.responder);
          lastPairAuthFail[_pairKey(x.name, y.name)] = authOnly;
          final failed = !(pair.initiator is SessionComplete && pair.responder is SessionComplete);
          for (final device in [x, y]) {
            if (authOnly) {
              roundAuthFail[device.name] = roundAuthFail[device.name]! + 1;
            } else if (failed) {
              roundOtherFail[device.name] = roundOtherFail[device.name]! + 1;
            }
          }
        }
      }
      for (final x in all) {
        authFailRounds[x.name] = roundAuthFail[x.name]! > 0 ? authFailRounds[x.name]! + 1 : 0;
        otherFailRounds[x.name] = roundOtherFail[x.name]!;
      }
    }

    // Ruling: the stale cluster is excluded, a never-stale device would block.
    final excludedClusters = <Set<String>>[];
    final excluded = decideStaleExclusion(
      names: [for (final x in all) x.name],
      stale: {for (final x in all) x.name: stale.contains(x)},
      pairAuthFail: lastPairAuthFail,
      authFailRounds: authFailRounds,
      otherFailRounds: otherFailRounds,
      onExcluded: excludedClusters.add,
    );
    expect(excluded, {a.name, b.name}, reason: 'endgame.staleExcluded');
    expect(excludedClusters, hasLength(1));

    // Ruling: revocations whose every holder is the stale pair are stranded.
    final stranded = strandedRevokedPubs(
      excluded: excluded,
      recordsByRevokedHex: _revocationHolders(all),
    );
    expect(stranded, {_hex(c.membership.identity.ed25519Pub), _hex(d.membership.identity.ed25519Pub)},
        reason: 'endgame.revocationStrandedInStaleCluster');

    // Ruling: a winning write authored by the stale pair that no converged
    // device holds is not expected on the converged side.
    final writeIds = {1: a.name, 2: c.name};
    final heldOnConverged = <int>{
      for (final device in converged)
        if (device.store.storedCell(cellKey('staleOnly', 'title')) != null) 1,
      2,
    };
    final relaxed = unreachableClusterWinners(
      excluded: excluded,
      authorOfWrite: writeIds,
      convergedHeldWriteIds: heldOnConverged,
    );
    expect(relaxed, {1}, reason: 'endgame.staleClusterWinnerRelaxed');
  });
}
