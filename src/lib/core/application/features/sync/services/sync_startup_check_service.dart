import 'dart:math' as math;

import 'package:whph/core/application/features/sync/services/abstraction/i_sync_change_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';
import 'package:whph/core/application/features/sync/services/sync_ledger_mark_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// What the D14 startup check found and did.
enum SyncStartupAction {
  /// No identity existed (or leftovers of an interrupted reset were removed):
  /// a new identity, unpaired.
  freshIdentity,

  /// Rule 5: nothing to do.
  normal,

  /// Rule 4: the DB is behind; `switch_origin(restore)`, identity kept.
  restore,

  /// Rule 2: the key file is gone or belongs to another DB; new identity,
  /// `switch_origin(key_lost)`, "needs re-pairing".
  keyLost,
}

/// The D14 startup identity/restore check and the D15 peer-cursor restore
/// check, over the key file, the ledger and the DB.
class SyncStartupCheckService {
  final SyncMembershipService _membershipService;
  final ISyncKeyStore _keyStore;
  final ISyncChangeStore _changeStore;
  final SyncLedgerMarkService _marks;

  SyncStartupCheckService({
    required SyncMembershipService membershipService,
    required ISyncKeyStore keyStore,
    required ISyncChangeStore changeStore,
    required SyncLedgerMarkService marks,
  })  : _membershipService = membershipService,
        _keyStore = keyStore,
        _changeStore = changeStore,
        _marks = marks;

  /// Runs rules 1-5, first match wins. [databaseCreatedThisLaunch] is true
  /// when the DB file did not exist before this launch. [deviceName] names a
  /// new identity.
  Future<SyncStartupAction> run({
    required String deviceName,
    required bool databaseCreatedThisLaunch,
  }) async {
    final keyFileLoaded = await _membershipService.loadKeyFile();
    if (keyFileLoaded && databaseCreatedThisLaunch) {
      await _keyStore.deleteAll();
      await _membershipService.createFreshIdentity(name: deviceName);
      return SyncStartupAction.freshIdentity;
    }
    final state = await _changeStore.readLocalState();
    if (!keyFileLoaded && state.memberId == null) {
      await _membershipService.createFreshIdentity(name: deviceName);
      return SyncStartupAction.freshIdentity;
    }
    if (!keyFileLoaded ||
        state.memberId != _membershipService.membership.memberId) {
      await _membershipService.recoverFromLostKeyFile(name: deviceName);
      return SyncStartupAction.keyLost;
    }
    await _recoverPendingSwitches();
    return _checkLedgerAgainstDatabase();
  }

  /// D15: the peer's cursor for this device's current origin is above
  /// `next_seq - 1`, so the local DB is behind. Switches origin with the
  /// cursor as the `max_sent_seq` lower bound and returns the report; the
  /// caller aborts before sending anything and retries the session. Returns
  /// `null` when the peer cursor does not exceed what the DB holds.
  Future<SyncOriginSwitchReport?> switchIfPeerCursorAhead(
      Map<String, int> peerVector) async {
    final state = await _changeStore.readLocalState();
    final peerCursor = peerVector[state.localOrigin] ?? 0;
    if (peerCursor <= state.nextSeq - 1) return null;
    final mark = _markOf(state.localOrigin) ?? 0;
    return _membershipService.switchOrigin(OriginSwitchReason.restore,
        sentMark: math.max(mark, peerCursor));
  }

  /// Rule 3: a `pending` ledger entry is committed when the DB adopted its
  /// origin, dropped otherwise.
  Future<void> _recoverPendingSwitches() async {
    while (_keyStore.latest?.state == OriginEntryState.pending) {
      final pending = _keyStore.latest!;
      final localOrigin = await _changeStore.localOrigin();
      if (pending.origin.hex == localOrigin) {
        await _keyStore.commit(pending.origin);
        await _membershipService.registerOwnOriginIfMissing();
      } else {
        await _keyStore.drop(pending.origin);
      }
    }
  }

  Future<SyncStartupAction> _checkLedgerAgainstDatabase() async {
    await _marks.flushWrittenWatermark();
    final state = await _changeStore.readLocalState();
    final mark = _markOf(state.localOrigin);
    final writtenHigh = _writtenHighOf(state.localOrigin);
    final committed = _keyStore.latestCommitted;
    final databaseIsBehind = !_keyStore.isReadable ||
        committed == null ||
        committed.origin.hex != state.localOrigin ||
        state.nextSeq - 1 < (mark ?? 0) ||
        state.nextSeq < writtenHigh;
    if (!databaseIsBehind) return SyncStartupAction.normal;
    await _membershipService.bindIdentityToDatabase();
    await _membershipService.switchOrigin(OriginSwitchReason.restore,
        sentMark: mark);
    await _membershipService.refresh();
    return SyncStartupAction.restore;
  }

  int? _markOf(String origin) => _keyStore.isReadable
      ? _keyStore.entryOf(OriginId.fromHex(origin))?.maxSentSeq
      : null;

  int _writtenHighOf(String origin) => _keyStore.isReadable
      ? _keyStore.entryOf(OriginId.fromHex(origin))?.nextSeqHigh ?? 0
      : 0;
}
