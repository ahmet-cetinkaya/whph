import 'dart:typed_data';

import 'package:whph/core/application/features/sync/services/abstraction/i_sync_change_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_state_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// A pairing, membership or identity step was refused (D7); nothing was
/// changed.
class SyncMembershipException implements Exception {
  final String message;
  const SyncMembershipException(this.message);

  @override
  String toString() => 'SyncMembershipException: $message';
}

/// What a joiner receives from the inviter at the end of a successful pairing
/// (D7 "Pairing hands the joiner the current epoch key(s)"). Holds secrets:
/// call [destroy] once the joiner has stored it.
class PairingHandover {
  final GroupId groupId;
  final Map<EpochId, Uint8List> epochKeys;
  final List<MemberEntry> anchors;
  final Set<String> revokedAnchorIds;
  final List<LedgerRevocation> revocations;

  PairingHandover({
    required this.groupId,
    required this.epochKeys,
    required this.anchors,
    required this.revokedAnchorIds,
    required this.revocations,
  });

  void destroy() {
    for (final key in epochKeys.values) {
      zeroize(key);
    }
  }
}

/// The device's standing in its group (D7, D14).
enum SyncGroupState { ungrouped, member, removedFromGroup, needsRepairing }

/// The `MembershipView` (D13): the members this device talks to, with the
/// key-file trust anchors behind them.
class MembershipView {
  final String memberId;
  final GroupId? groupId;
  final SyncGroupState state;

  /// Members neither revoked in the DB nor flagged in an anchor, this device
  /// included.
  final List<MemberEntry> activeMembers;

  /// Key-file trust anchors (grow-only within a group) and the ids of those
  /// flagged revoked (sticky).
  final List<MemberEntry> anchors;
  final Set<String> revokedAnchorIds;

  /// Members marked "needs re-pairing" after an outbound key check.
  final Set<String> peersNeedingRepairing;
  final EpochId? currentEpoch;

  /// U6: holds group keys, is neither removed nor key-lost, and has a
  /// non-revoked member besides itself.
  final bool isPaired;

  const MembershipView({
    required this.memberId,
    required this.groupId,
    required this.state,
    required this.activeMembers,
    required this.anchors,
    required this.revokedAnchorIds,
    required this.peersNeedingRepairing,
    required this.currentEpoch,
    required this.isPaired,
  });
}

/// The result of checking the static key an outbound connection answered with
/// (D7, U5).
enum OutboundKeyVerdict {
  /// The expected member answered.
  matches,

  /// No member owns the key: the expected member is marked "needs re-pairing"
  /// and no user data is exchanged.
  needsRepairing,

  /// Another active member answered: the expected member's state is
  /// unchanged and the address is moved to the answering member.
  addressBelongsToOtherMember,

  /// A revoked member answered: refused, nothing changes.
  revokedMember,
}

const _hlcCounterBits = 16;

/// Members, origin registry, revocations, grants, epochs, group creation and
/// switch, and the removed / needs-re-pairing states of this device (D7, D13),
/// over the security rows of [ISyncChangeStore] and the key file and ledger of
/// [ISyncKeyStore].
///
/// Persistence order: the ledger's `epoch_counter_high` and revocation records
/// are written before the key-file write and the DB cell they protect.
/// Public mutating methods run one at a time.
class SyncMembershipService {
  final ISyncKeyStore _keyStore;
  final ISyncChangeStore _changeStore;
  final ISyncPeerStateStore _peerStateStore;
  final SyncIdSource _ids;
  final int Function() _nowMs;

  Membership? _membership;
  bool _needsRepairing = false;
  Future<void> _queue = Future.value();

  SyncMembershipService({
    required ISyncKeyStore keyStore,
    required ISyncChangeStore changeStore,
    required ISyncPeerStateStore peerStateStore,
    SyncIdSource? ids,
    int Function()? nowMs,
  })  : _keyStore = keyStore,
        _changeStore = changeStore,
        _peerStateStore = peerStateStore,
        _ids = ids ?? SyncIdSource(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// The in-memory membership. Throws until [loadKeyFile] or
  /// [createFreshIdentity] ran.
  Membership get membership =>
      _membership ?? (throw StateError('identity not loaded'));

  bool get hasIdentity => _membership != null;

  // -- identity ----------------------------------------------------------------------

  /// Loads the ledger and the key file. Returns `false` when the key file is
  /// missing (the D14 startup check, T21, then decides between a fresh device
  /// and a key loss). Throws [SyncKeyStoreException] when the file is damaged.
  Future<bool> loadKeyFile() => _exclusive(() async {
        await _keyStore.load();
        final content = await _keyStore.readKeyFile();
        if (content == null) return false;
        final snapshot = content.snapshot;
        final identity = await DeviceIdentity.fromKeys(
          memberId: snapshot.memberId,
          name: snapshot.name,
          x25519Private: snapshot.x25519Private,
          ed25519Seed: snapshot.ed25519Seed,
        );
        final restored = _newMembership(identity);
        await restored.restoreKeyFile(snapshot);
        _membership = restored;
        _needsRepairing = content.needsRepairing;
        await _refresh();
        return true;
      });

  /// First run: a new identity, no group, the DB's current local origin as the
  /// first committed ledger origin. [name] is the device name members see.
  Future<void> createFreshIdentity({required String name}) =>
      _exclusive(() async {
        final identity = await DeviceIdentity.generate(_ids, name: name);
        final origin = OriginId.fromHex(await _changeStore.localOrigin());
        await _keyStore.append(
          OriginEntry(
              origin: origin,
              state: OriginEntryState.committed,
              reason: OriginSwitchReason.initial),
        );
        _membership = _newMembership(identity);
        _needsRepairing = false;
        await _changeStore.bindIdentity(memberId: identity.memberId);
        await _persistKeyFile();
      });

  /// D14 rule 2 / U7: the key file is gone but the DB exists. A new identity
  /// and a new origin; never-sent cells are adopted under the new origin (the
  /// old origin is sealed and never reused); the device shows "needs
  /// re-pairing" until it is paired again.
  Future<SyncOriginSwitchReport> recoverFromLostKeyFile(
          {required String name}) =>
      _exclusive(() async {
        final localOrigin = OriginId.fromHex(await _changeStore.localOrigin());
        final sentMark = _keyStore.isReadable
            ? _keyStore.entryOf(localOrigin)?.maxSentSeq
            : null;
        final identity = await DeviceIdentity.generate(_ids, name: name);
        final current = _membership;
        if (current == null) {
          _membership = _newMembership(identity);
        } else {
          current.replaceIdentity(identity);
        }
        await _clearLedgerGroupState();
        _needsRepairing = true;
        await _changeStore.bindIdentity(memberId: identity.memberId);
        final report =
            await _switchOrigin(OriginSwitchReason.keyLost, sentMark: sentMark);
        await _persistKeyFile();
        return report;
      });

  // -- origin switch ----------------------------------------------------------------------

  /// `switch_origin(reason)` (D6b steps 1-3). [sentMark] is the old origin's
  /// `max_sent_seq` (`null` = unknown).
  Future<SyncOriginSwitchReport> switchOrigin(OriginSwitchReason reason,
          {int? sentMark}) =>
      _exclusive(() => _switchOrigin(reason, sentMark: sentMark));

  Future<SyncOriginSwitchReport> _switchOrigin(OriginSwitchReason reason,
      {int? sentMark}) async {
    final newOrigin = _ids.origin();
    await _keyStore.append(OriginEntry(
        origin: newOrigin, state: OriginEntryState.pending, reason: reason));
    final report = await _changeStore.switchOrigin(
      reason,
      newOrigin: newOrigin.hex,
      sentMark: sentMark,
      hlcFloor: _keyStore.hlcFloor,
    );
    if (report.needsRepairing) _needsRepairing = true;
    if (membership.hasGroup && reason != OriginSwitchReason.groupSwitch)
      await _registerOrigin(newOrigin);
    await _keyStore.commit(newOrigin);
    return report;
  }

  // -- pairing -----------------------------------------------------------------------------

  /// Whether joining the group of [inviterGroup] (`null` when the inviter has
  /// none yet) makes this device leave a group with other members. The joiner
  /// asks the user before any bytes are exchanged (D7).
  bool requiresGroupSwitchConfirmation(GroupId? inviterGroup) {
    final m = membership;
    final ownGroup = m.groupId;
    if (ownGroup == null || ownGroup == inviterGroup) return false;
    return !m.removed &&
        m.activeMembers.any((member) => member.memberId != m.memberId);
  }

  /// Inviter side, at the moment pairing succeeded: creates the group on the
  /// first pairing, records [joiner] as a member with grants for every held
  /// epoch, and returns what the joiner needs.
  Future<PairingHandover> prepareHandover(MemberEntry joiner) =>
      _exclusive(() async {
        final m = membership;
        if (m.removed)
          throw const SyncMembershipException(
              'the inviter was removed from its group');
        if (m.isRevokedEd(joiner.ed25519Pub)) {
          throw const SyncMembershipException(
              'a removed device must pair again with a fresh identity');
        }
        if (!m.hasGroup) await _createGroup();
        await _writeSecurity(memberCellKey(joiner.memberId), joiner.encode());
        for (final epoch in m.keyring.epochs) {
          final grant = EpochGrant(epoch, joiner.ed25519Pub);
          await _writeSecurity(
              epochGrantCellKey(grant), encodeEpochGrant(grant));
        }
        await _refresh();
        return PairingHandover(
          groupId: m.groupId!,
          epochKeys: {
            for (final e in m.keyring.epochs)
              e: Uint8List.fromList(m.keyring.keyFor(e)!)
          },
          anchors: m.anchors,
          revokedAnchorIds: m.revokedAnchorIds,
          revocations: _keyStore.revocations,
        );
      });

  /// Inviter side: stores the origin registration the joiner returned after
  /// [acceptHandover]; the rest of the group learns it transitively.
  Future<void> completePairing(OriginRegistration joinerRegistration) =>
      _exclusive(() async {
        await _changeStore.mergeRegistrations([joinerRegistration]);
        await _refresh();
      });

  /// Joiner side: adopts the inviter's group. Joining while in another group
  /// with other members needs [confirmGroupSwitch] and runs
  /// `switch_origin(group_switch)` (NB-1). Returns this device's new origin
  /// registration for the inviter.
  Future<OriginRegistration> acceptHandover(PairingHandover handover,
          {bool confirmGroupSwitch = false}) =>
      _exclusive(() async {
        final m = membership;
        final ownGroup = m.groupId;
        if (ownGroup != null && ownGroup != handover.groupId) {
          if (requiresGroupSwitchConfirmation(handover.groupId) &&
              !confirmGroupSwitch) {
            throw const SyncMembershipException(
                'joining leaves the current group; confirmation required');
          }
          await _leaveForGroupSwitch();
        }
        await _keyStore.persistRevocations(handover.revocations);
        m.joinGroup(
          handover.groupId,
          epochKeys: handover.epochKeys,
          anchors: handover.anchors,
          revokedAnchors: handover.revokedAnchorIds,
        );
        _needsRepairing = false;
        await _changeStore.bindIdentity(
            memberId: m.memberId, groupId: handover.groupId.hex);
        await _persistKeyFile();
        final registration = await _registerOrigin(
            OriginId.fromHex(await _changeStore.localOrigin()));
        await _refresh();
        return registration;
      });

  Future<void> _leaveForGroupSwitch() async {
    await _switchOrigin(OriginSwitchReason.groupSwitch);
    membership.leaveGroup();
    await _clearLedgerGroupState();
    await _changeStore.bindIdentity(memberId: membership.memberId);
    await _persistKeyFile();
  }

  Future<void> _createGroup() async {
    final m = membership;
    final groupId = _ids.group();
    m.createGroup(groupId);
    final epoch = await _createEpoch();
    _needsRepairing = false;
    await _persistKeyFile();
    await _changeStore.bindIdentity(memberId: m.memberId, groupId: groupId.hex);
    await _writeSecurity(memberCellKey(m.memberId),
        m.identity.entry(addedBy: m.memberId).encode());
    final grant = EpochGrant(epoch, m.identity.ed25519Pub);
    await _writeSecurity(epochGrantCellKey(grant), encodeEpochGrant(grant));
    await _registerOrigin(OriginId.fromHex(await _changeStore.localOrigin()));
    await _refresh();
  }

  // -- removal, rotation -------------------------------------------------------------------

  /// Removes [memberId] (FR-026): a signed revocation with a cutoff for every
  /// origin registered to it, then an epoch rotation (D7).
  Future<void> removeMember(String memberId) => _exclusive(() async {
        final m = membership;
        final groupId = m.groupId ?? (throw StateError('not in a group'));
        if (memberId == m.memberId)
          throw ArgumentError('use leave/reset to remove this device');
        final entry = m.memberById(memberId) ??
            (throw ArgumentError.value(memberId, 'memberId', 'unknown member'));
        final vector = await _changeStore.readVector();
        final cutoffs = {
          for (final origin in m.registry!.originsOf(entry.ed25519Pub))
            origin: vector[origin.hex] ?? 0
        };
        final record = await RevocationRecord.sign(
          groupId: groupId,
          revokedPub: entry.ed25519Pub,
          revoker: m.identity.ed25519,
          cutoffs: cutoffs,
        );
        await _commitOwnRevocation(record);
        await _rotate();
        await _refresh();
      });

  /// Upkeep after a session (D7): extends revocation cutoffs to the seqs this
  /// device holds above them (self-extension) and applies the re-rotation
  /// rule. Returns whether anything was written.
  Future<bool> maintainMembership() => _exclusive(() async {
        final m = membership;
        final groupId = m.groupId;
        final revocations = m.directoryRevocations;
        final registry = m.registry;
        if (groupId == null ||
            m.removed ||
            revocations == null ||
            registry == null) return false;
        final vector = await _changeStore.readVector();
        var wrote = false;
        final extension = revocations.selfExtension(
            registry, (origin) => vector[origin.hex] ?? 0);
        for (final entry in extension.entries) {
          final record = await RevocationRecord.sign(
            groupId: groupId,
            revokedPub: entry.key,
            revoker: m.identity.ed25519,
            cutoffs: entry.value,
          );
          await _commitOwnRevocation(record);
          wrote = true;
        }
        if (wrote) await _refresh();
        if (m.mustRotate) {
          await _rotate();
          await _refresh();
          wrote = true;
        }
        return wrote;
      });

  /// Rotation: the ledger counter first, then the key file with the new key,
  /// then the own grant row.
  Future<void> _rotate() async {
    final m = membership;
    final epoch = await _createEpoch();
    await _persistKeyFile();
    final grant = EpochGrant(epoch, m.identity.ed25519Pub);
    await _writeSecurity(epochGrantCellKey(grant), encodeEpochGrant(grant));
  }

  /// Creates this device's next epoch. The new counter is persisted to the
  /// ledger before the key exists, so a rolled-back key file cannot re-create
  /// an epoch id (U11 G1).
  Future<EpochId> _createEpoch() async {
    final keyring = membership.keyring;
    final counterFloor = _keyStore.epochCounterHigh;
    final next =
        keyring.nextEpoch(membership.memberId, counterFloor: counterFloor);
    await _keyStore.persistEpochCounterHigh(next.counter);
    return keyring.rotate(membership.memberId, counterFloor: counterFloor);
  }

  /// The ledger first, then the DB cell (U11/Efe-1). A ledger write failure
  /// throws before anything is committed.
  Future<void> _commitOwnRevocation(RevocationRecord record) async {
    final recordBytes = encodeRevocationRecord(record);
    final carrierOrigin = OriginId.fromHex(await _changeStore.localOrigin());
    final carrierSeq =
        ((await _changeStore.readVector())[carrierOrigin.hex] ?? 0) + 1;
    await _keyStore.persistRevocations([
      LedgerRevocation(
        recordBytes: recordBytes,
        revokerEntryBytes:
            membership.memberByEd25519(record.revokerPub)?.encode(),
        carrierOrigin: carrierOrigin,
        carrierSeq: carrierSeq,
      ),
    ]);
    final written = await _changeStore.writeSecurityCell(
        revocationCellKey(record), recordBytes);
    if (written.origin != carrierOrigin.hex ||
        written.originSeq != carrierSeq) {
      throw StateError('a local write interleaved with a revocation commit');
    }
  }

  // -- outbound check (U5) -----------------------------------------------------------------

  /// Checks the static key [observedX25519] that the connection to [address]
  /// (listed for [expectedMemberId]) answered with, before any user data.
  Future<OutboundKeyVerdict> checkOutboundStaticKey({
    required String expectedMemberId,
    required String address,
    required List<int> observedX25519,
  }) =>
      _exclusive(() async {
        final owner = _memberByX25519(observedX25519);
        if (owner == null) {
          await _peerStateStore.markNeedsRepairing(expectedMemberId);
          return OutboundKeyVerdict.needsRepairing;
        }
        if (owner.memberId == expectedMemberId) {
          await _peerStateStore.clearNeedsRepairing(expectedMemberId);
          return OutboundKeyVerdict.matches;
        }
        if (membership.isExcluded(owner.ed25519Pub))
          return OutboundKeyVerdict.revokedMember;
        await _peerStateStore.moveAddress(address,
            fromMemberId: expectedMemberId, toMemberId: owner.memberId);
        return OutboundKeyVerdict.addressBelongsToOtherMember;
      });

  /// A session to [memberId] was refused after the address answered: the
  /// member no longer accepts this device, so it needs re-pairing (FR-016).
  Future<void> markPeerRefused(String memberId) =>
      _exclusive(() => _peerStateStore.markNeedsRepairing(memberId));

  MemberEntry? _memberByX25519(List<int> x25519Pub) {
    for (final member in membership.members.values) {
      if (_sameBytes(member.x25519Pub, x25519Pub)) return member;
    }
    return null;
  }

  // -- view ----------------------------------------------------------------------------------

  /// Rebuilds the derived view from the DB and returns it.
  Future<MembershipView> refresh() => _exclusive(_refresh);

  /// The view as of the last rebuild, with fresh peer states.
  Future<MembershipView> currentView() => _exclusive(_viewOf);

  Future<MembershipView> _refresh() async {
    final changed = await membership.rebuild(await _projectSecurityCells());
    if (changed) await _persistKeyFile();
    return _viewOf();
  }

  Future<MembershipView> _viewOf() async {
    final m = membership;
    return MembershipView(
      memberId: m.memberId,
      groupId: m.groupId,
      state: _stateOf(m),
      activeMembers: m.activeMembers,
      anchors: m.anchors,
      revokedAnchorIds: m.revokedAnchorIds,
      peersNeedingRepairing: await _peerStateStore.peersNeedingRepairing(),
      currentEpoch: m.keyring.highest,
      isPaired: m.isPaired && !_needsRepairing,
    );
  }

  SyncGroupState _stateOf(Membership m) {
    if (m.removed) return SyncGroupState.removedFromGroup;
    if (_needsRepairing) return SyncGroupState.needsRepairing;
    return m.hasGroup ? SyncGroupState.member : SyncGroupState.ungrouped;
  }

  // -- plumbing ------------------------------------------------------------------------------

  Membership _newMembership(DeviceIdentity identity) =>
      Membership(identity, retainedRevocations: () => _keyStore.revocations);

  /// The security rows of the DB as an in-memory store, the input of
  /// [Membership.rebuild]. The store is a read-only projection: its origin is
  /// a throwaway and nothing is written back.
  Future<SyncStore> _projectSecurityCells() async {
    final projection = SyncStore(
      memberId: membership.memberId,
      origin: _ids.origin(),
      initialHlc: _nowMs() << _hlcCounterBits,
    );
    projection.groupId = membership.groupId;
    final cells = await _changeStore.readSecurityCells();
    projection.applyBatch(ChangeBatch(
        origin: _ids.origin().hex, fromSeq: 0, toSeq: 0, cells: cells));
    for (final registration in await _changeStore.readRegistrations()) {
      projection.addRegistration(registration);
    }
    return projection;
  }

  Future<OriginRegistration> _registerOrigin(OriginId origin) async {
    final projection = await _projectSecurityCells();
    final registration = await membership.registerOrigin(origin, projection);
    await _changeStore.mergeRegistrations([registration]);
    return registration;
  }

  Future<void> _writeSecurity(CellKey key, Uint8List record) =>
      _changeStore.writeSecurityCell(key, record);

  Future<void> _persistKeyFile() => _keyStore.writeKeyFile(
        SyncKeyFileContent(
            snapshot: membership.snapshotKeyFile(),
            needsRepairing: _needsRepairing),
      );

  Future<void> _clearLedgerGroupState() async {
    await _keyStore.resetEpochCounterHigh();
    await _keyStore.clearRevocations();
  }

  Future<T> _exclusive<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}
