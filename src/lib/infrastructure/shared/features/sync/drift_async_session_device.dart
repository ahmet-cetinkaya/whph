import 'package:whph/core/application/features/sync/services/abstraction/i_sync_change_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';
import 'package:whph/core/application/features/sync/services/sync_ledger_mark_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_change_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// The device the async session engine runs against in the app: identity and
/// membership from [SyncMembershipService], the ledger and key file from
/// [ISyncKeyStore], and the cells from the Drift store (T22e).
class DriftAsyncSessionDevice implements AsyncSessionDevice {
  @override
  final SyncEngineConfig config;
  @override
  final DriftAsyncSyncStore store;
  @override
  final Map<String, AsyncSyncSession> activeSessions = {};
  @override
  int? lastSuccessfulSyncLocal;
  @override
  int watermarkFlushFailures = 0;

  final SyncMembershipService _membershipService;
  final ISyncKeyStore _keyStore;
  final ISyncChangeStore _changeStore;
  final SyncLedgerMarkService _marks;
  final SyncStartupCheckService _startupCheck;
  final int Function() _nowMs;
  final Map<String, PeerState> _peers = {};

  DriftAsyncSessionDevice({
    required SyncMembershipService membershipService,
    required ISyncKeyStore keyStore,
    required ISyncChangeStore changeStore,
    required this.store,
    required SyncLedgerMarkService marks,
    required SyncStartupCheckService startupCheck,
    this.config = const SyncEngineConfig(),
    int Function()? nowMs,
  })  : _membershipService = membershipService,
        _keyStore = keyStore,
        _changeStore = changeStore,
        _marks = marks,
        _startupCheck = startupCheck,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  @override
  String get name => membership.identity.name;

  @override
  String get memberId => membership.memberId;

  @override
  Membership get membership => _membershipService.membership;

  @override
  SyncLedger get ledger => _keyStore;

  @override
  int now() => _nowMs();

  @override
  PeerState peerState(String memberId) =>
      _peers.putIfAbsent(memberId, () => PeerState(memberId));

  @override
  Future<bool> flushWrittenWatermark() async {
    final wasBehind = await _watermarkBehind();
    final wrote = await _marks.flushWrittenWatermark();
    if (wasBehind && !wrote) watermarkFlushFailures++;
    return wrote;
  }

  Future<bool> _watermarkBehind() async {
    final state = await _changeStore.readLocalState();
    final entry = _keyStore.entryOf(OriginId.fromHex(state.localOrigin));
    return _keyStore.isReadable &&
        entry != null &&
        state.nextSeq > entry.nextSeqHigh;
  }

  @override
  Future<void> recordGrant(EpochGrant grant) async {
    await _changeStore.writeSecurityCell(
        epochGrantCellKey(grant), encodeEpochGrant(grant));
  }

  @override
  Future<void> retainReceivedRevocations(Iterable<Change> changes) async {
    final retained = [
      for (final change in changes)
        if (_receivedRevocation(change) case final revocation?) revocation,
    ];
    if (retained.isNotEmpty) await _keyStore.persistRevocations(retained);
  }

  /// The ledger form of [change] when it carries a revocation record. A
  /// malformed record is not kept: `Membership.rebuild` ignores it as well.
  LedgerRevocation? _receivedRevocation(Change change) {
    final value = change.value;
    if (change.tbl != SecurityTables.revocation || value is! BytesValue) {
      return null;
    }
    final RevocationRecord record;
    try {
      record = decodeRevocationRecord(value.value);
    } on Object {
      return null;
    }
    return LedgerRevocation(
      recordBytes: value.value,
      revokerEntryBytes:
          membership.memberByEd25519(record.revokerPub)?.encode(),
      carrierOrigin: change.origin,
      carrierSeq: change.originSeq,
    );
  }

  @override
  Future<bool> maintainMembership() async {
    // Keys a session accepted live only in memory until the key file is
    // written; the session ends here.
    await _membershipService.persistKeyFile();
    return _membershipService.maintainMembership();
  }

  @override
  Future<void> switchOriginAfterPeerCursor(int peerCursor) async {
    final localOrigin = await _changeStore.localOrigin();
    await _startupCheck.switchIfPeerCursorAhead({localOrigin: peerCursor});
  }
}
