/// Per-device membership and security state (D7, D13), in memory.
///
/// Two parts, mirroring where the data lives in the app:
///
/// * **Key file** (`sync_keys.json`, secret): identity, `group_id`, epoch
///   keys ([GroupKeyring]), trust anchors with their sticky `revoked` flags,
///   the "removed from group" flag. Snapshotted separately by
///   [KeyFileSnapshot].
/// * **Derived from the DB**: the origin registry, members, revocations and
///   grants, rebuilt from the store's security cells and registrations by
///   [Membership.rebuild]. `MembershipView` = members (cells ∪ anchors)
///   neither revoked in the DB nor flagged in an anchor ([Membership.isExcluded]).
///
/// Trust anchors only grow within a group (U11, G2): [Membership.rebuild]
/// adds every known member and flags an anchor `revoked` once the DB shows
/// its key revoked; the flag is never cleared. The signature directory holds
/// every anchor and member row, revoked ones included (revocation cutoffs
/// decide acceptance); session admission and key handover use
/// [Membership.isExcluded], so a DB restored to before a revocation still
/// refuses the revoked member.
///
/// The signed revocation records kept in the sync ledger (U11/Efe-1) are
/// merged on every [Membership.rebuild] exactly like the DB's revocation
/// cells (signatures verified, same revoked-author filter), so a data-folder
/// restore that rolls back the DB and the key file still knows every
/// revocation this device committed. The revoker key the ledger keeps next to
/// a record only verifies that record (U11/Efe-R1): the ledger is not
/// integrity-protected, so it never adds a member, an anchor or a key that
/// admits a session, receives keys or verifies manifests.
///
/// Security cells authored by a revoked member above that member's cutoff
/// are ignored (T11 note: revocation records of a revoked member count only
/// when their carrying change passed the cutoff); the filter is iterated to a
/// fixpoint because cutoffs depend on the records.
library;

import 'dart:typed_data';

import '../crypto/epoch.dart';
import '../crypto/manifest_signer.dart';
import '../crypto/origin_registry.dart';
import '../crypto/primitives.dart';
import '../crypto/revocation.dart';
import '../model/ids.dart';
import '../protocol/messages.dart';
import '../store/replica_store.dart';
import '../store/sync_ledger.dart';
import '../store/sync_store.dart';
import 'identity.dart';
import 'security_records.dart';

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// Rounds of the revoked-author filter fixpoint in [Membership.rebuild].
const _filterRounds = 8;

/// The `(origin, seq)` of the change that carried a security record.
typedef _Carrier = ({String origin, int seq});

_Carrier _carrierOf(StoredCell cell) => (origin: cell.record.origin, seq: cell.record.originSeq);

String _carrierId(_Carrier carrier) => '${carrier.origin}#${carrier.seq}';

List<LedgerRevocation> _noRetainedRevocations() => const [];

/// A ledger revocation record with the revoker key kept next to it, if any.
typedef _RetainedRevocation = ({_Carrier carrier, RevocationRecord record, Uint8List? revokerPub});

/// The member directory plus one revoker key, used only to verify that
/// revoker's own retained record (U11/Efe-R1).
final class _DirectoryWithRevoker implements MemberDirectory {
  _DirectoryWithRevoker(this._members, Uint8List revokerPub) : _revokerHex = _hex(revokerPub);

  final MemberDirectory _members;
  final String _revokerHex;

  @override
  bool isMember(List<int> ed25519Pub) =>
      _members.isMember(ed25519Pub) || (!isWeakEd25519PublicKey(ed25519Pub) && _hex(ed25519Pub) == _revokerHex);
}

/// The current member directory, swapped on every [Membership.rebuild]; the
/// registry reads it live.
final class _LiveDirectory implements MemberDirectory {
  MemberDirectory current = MemberKeySet(const []);

  @override
  bool isMember(List<int> ed25519Pub) => current.isMember(ed25519Pub);
}

/// A copy of the key file for whole-directory snapshots (secret material; it
/// never prints key bytes).
final class KeyFileSnapshot {
  KeyFileSnapshot._({
    required this.memberId,
    required this.name,
    required Uint8List x25519Private,
    required Uint8List ed25519Seed,
    required this.groupId,
    required Map<EpochId, Uint8List> epochKeys,
    required this.anchors,
    required this.revokedAnchors,
    required this.removed,
  })  : _x25519Private = x25519Private,
        _ed25519Seed = ed25519Seed,
        _epochKeys = epochKeys;

  final String memberId;
  final String name;
  final Uint8List _x25519Private;
  final Uint8List _ed25519Seed;
  final GroupId? groupId;
  final Map<EpochId, Uint8List> _epochKeys;
  final List<MemberEntry> anchors;

  /// Member ids of the anchors flagged revoked.
  final Set<String> revokedAnchors;
  final bool removed;

  @override
  String toString() => 'KeyFileSnapshot($memberId, ${_epochKeys.length} epochs)';
}

/// Membership and security state of one device.
final class Membership {
  /// [retainedRevocations] reads the ledger's revocation records (U11/Efe-1).
  Membership(this._identity, {List<LedgerRevocation> Function() retainedRevocations = _noRetainedRevocations})
      : _retainedRevocations = retainedRevocations;

  final List<LedgerRevocation> Function() _retainedRevocations;
  DeviceIdentity _identity;
  GroupId? _groupId;
  GroupKeyring _keyring = GroupKeyring();
  final Map<String, MemberEntry> _anchors = {};
  final Set<String> _revokedAnchors = {};
  bool _removed = false;

  OriginRegistrySet? _registry;
  RevocationSet? _revocations;
  RevocationSet? _directoryRevocations;
  Map<String, MemberEntry> _members = {};
  Map<String, MemberEntry> _byX25519 = {};
  Set<String> _revokedEd = {};
  Set<String> _directoryRevokedEd = {};
  List<EpochGrant> _grants = const [];
  final _LiveDirectory _live = _LiveDirectory();
  ManifestVerifier? _verifier;
  final Map<String, RevocationRecord> _recordCache = {};
  String _fingerprint = '';

  // --- Key file -----------------------------------------------------------------

  DeviceIdentity get identity => _identity;
  String get memberId => _identity.memberId;
  GroupId? get groupId => _groupId;
  GroupKeyring get keyring => _keyring;
  bool get hasGroup => _groupId != null;

  /// This device learned that its own key was revoked: group keys were
  /// discarded; it shows "removed from group" and syncs with nobody.
  bool get removed => _removed;

  /// Trust anchors (key file, D13): the member keys handed over at pairing,
  /// grown by every member [rebuild] learns of; never pruned within a group.
  List<MemberEntry> get anchors => List.unmodifiable(_anchors.values);

  /// Member ids of the anchors flagged revoked (sticky, never cleared).
  Set<String> get revokedAnchorIds => Set.unmodifiable(_revokedAnchors);

  /// Starts a new group (first pairing, D7). The caller creates its first
  /// epoch `(1, me)` and persists the counter before storing the key.
  void createGroup(GroupId groupId) {
    if (_groupId != null) throw StateError('already in a group');
    _groupId = groupId;
    _removed = false;
    _registry = OriginRegistrySet(groupId, members: _live);
    _anchors[memberId] = _identity.entry(addedBy: memberId);
  }

  /// Joins [groupId] with the handed-over epoch keys and the inviter's trust
  /// anchors, flags included ([revokedAnchors], pairing, D7). Any previous
  /// group state must have been dropped by [leaveGroup].
  void joinGroup(
    GroupId groupId, {
    required Map<EpochId, Uint8List> epochKeys,
    required Iterable<MemberEntry> anchors,
    required Set<String> revokedAnchors,
  }) {
    if (_groupId != null && _groupId != groupId) throw StateError('leave the current group first');
    if (_groupId != groupId) _registry = OriginRegistrySet(groupId, members: _live);
    _groupId = groupId;
    _removed = false;
    for (final e in epochKeys.entries) {
      _keyring.add(e.key, e.value);
    }
    for (final a in anchors) {
      _anchors[a.memberId] = a;
    }
    _revokedAnchors.addAll(revokedAnchors);
    _anchors[memberId] = _identity.entry(addedBy: memberId);
  }

  /// Drops group keys, anchors and derived state (group switch, key loss).
  void leaveGroup() {
    _keyring.destroy();
    _keyring = GroupKeyring();
    _groupId = null;
    _anchors.clear();
    _revokedAnchors.clear();
    _removed = false;
    _registry = null;
    _clearDerived();
  }

  /// Replaces the identity (`key_lost`: the old key file is gone).
  void replaceIdentity(DeviceIdentity identity) {
    leaveGroup();
    _identity = identity;
  }

  /// A copy of the key file.
  KeyFileSnapshot snapshotKeyFile() => KeyFileSnapshot._(
        memberId: memberId,
        name: _identity.name,
        x25519Private: _identity.x25519.exportPrivateKey(),
        ed25519Seed: _identity.ed25519.exportSeed(),
        groupId: _groupId,
        epochKeys: _removed ? const {} : {for (final e in _keyring.epochs) e: Uint8List.fromList(_keyring.keyFor(e)!)},
        anchors: anchors,
        revokedAnchors: Set.of(_revokedAnchors),
        removed: _removed,
      );

  /// Replaces the key file with [snapshot] (whole-directory restore).
  Future<void> restoreKeyFile(KeyFileSnapshot snapshot) async {
    final identity = await DeviceIdentity.fromKeys(
      memberId: snapshot.memberId,
      name: snapshot.name,
      x25519Private: snapshot._x25519Private,
      ed25519Seed: snapshot._ed25519Seed,
    );
    leaveGroup();
    _identity = identity;
    _groupId = snapshot.groupId;
    if (_groupId != null) _registry = OriginRegistrySet(_groupId!, members: _live);
    for (final e in snapshot._epochKeys.entries) {
      _keyring.add(e.key, e.value);
    }
    for (final a in snapshot.anchors) {
      _anchors[a.memberId] = a;
    }
    _revokedAnchors.addAll(snapshot.revokedAnchors);
    _removed = snapshot.removed;
  }

  // --- Derived view -----------------------------------------------------------------

  /// Every known member (cells ∪ anchors), including revoked ones.
  Map<String, MemberEntry> get members => Map.unmodifiable(_members);

  /// The `MembershipView`: members not [isExcluded], including this device.
  /// It honours the anchor flag like admission does, so "paired" and "has
  /// other members" agree with who the device would actually talk to, also
  /// after a DB restore to before a revocation or for a joiner handed a
  /// flagged anchor whose revocation row has not reached it yet.
  List<MemberEntry> get activeMembers => [
        for (final m in _members.values)
          if (!isExcluded(m.ed25519Pub)) m
      ];

  /// Whether this device is paired in the U6 sense: holds group keys, is not
  /// removed, and its view has a non-revoked member other than itself.
  bool get isPaired =>
      hasGroup && !_removed && _keyring.epochs.isNotEmpty && activeMembers.any((m) => m.memberId != memberId);

  /// Synced grants.
  List<EpochGrant> get grants => List.unmodifiable(_grants);

  OriginRegistrySet? get registry => _registry;
  RevocationSet? get revocations => _revocations;

  /// The [revocations] verified against the real member directory alone, with
  /// no ledger-only record. Only these may turn into an own signed revocation
  /// or an epoch rotation (U11/Efe-R2).
  RevocationSet? get directoryRevocations => _directoryRevocations;

  /// Verifier over the current registry, revocations and member directory
  /// (the directory includes revoked members; cutoffs decide).
  ManifestVerifier get verifier => _verifier ?? (throw StateError('not in a group'));

  /// Whether the DB shows [ed25519Pub] revoked.
  bool isRevokedEd(List<int> ed25519Pub) => _revokedEd.contains(_hex(ed25519Pub));

  /// Whether session admission and key handover must refuse [ed25519Pub]:
  /// revoked in the DB or flagged revoked in a trust anchor (G2b). The one
  /// owner of that rule.
  bool isExcluded(List<int> ed25519Pub) => _isExcludedFrom(_revokedEd, ed25519Pub);

  /// [isExcluded] without ledger-only revocations: the rule that may trigger a
  /// rotation, since a forged ledger pair must not cut a member out (U11/Efe-R2).
  bool _isDirectoryExcluded(List<int> ed25519Pub) => _isExcludedFrom(_directoryRevokedEd, ed25519Pub);

  bool _isExcludedFrom(Set<String> revokedEd, List<int> ed25519Pub) {
    final hex = _hex(ed25519Pub);
    if (revokedEd.contains(hex)) return true;
    return _anchors.values.any((a) => _revokedAnchors.contains(a.memberId) && _hex(a.ed25519Pub) == hex);
  }

  /// The member owning Noise static key [x25519Pub] that is not
  /// [isExcluded], or `null`.
  MemberEntry? activeMemberByX25519(List<int> x25519Pub) {
    final m = _byX25519[_hex(x25519Pub)];
    if (m == null || isExcluded(m.ed25519Pub)) return null;
    return m;
  }

  MemberEntry? memberById(String memberId) => _members[memberId];

  /// The known member (revoked ones included) with signing key [ed25519Pub],
  /// or `null`.
  MemberEntry? memberByEd25519(List<int> ed25519Pub) {
    final hex = _hex(ed25519Pub);
    for (final m in _members.values) {
      if (_hex(m.ed25519Pub) == hex) return m;
    }
    return null;
  }

  /// Member ids of anchors flagged revoked for which no revocation record is
  /// known, so their changes would be verified with no cutoff (U11/Efe-2).
  /// Pairing hands the joiner the records and the ledger keeps them across a
  /// restore, so this stays empty unless the ledger itself was lost.
  Set<String> get flaggedAnchorsWithoutRecord => {
        for (final a in _anchors.values)
          if (_isFlaggedWithoutRecord(a)) a.memberId,
      };

  /// Whether [ed25519Pub] belongs to one of the [flaggedAnchorsWithoutRecord]:
  /// its changes have no known cutoff and stay held until the record arrives
  /// (U11/Efe-R1).
  bool isFlaggedWithoutRecord(List<int> ed25519Pub) {
    final hex = _hex(ed25519Pub);
    return _anchors.values.any((a) => _hex(a.ed25519Pub) == hex && _isFlaggedWithoutRecord(a));
  }

  bool _isFlaggedWithoutRecord(MemberEntry anchor) =>
      _revokedAnchors.contains(anchor.memberId) && !(_revocations?.isRevoked(anchor.ed25519Pub) ?? false);

  /// Noise `acceptRemoteStatic` (D7): the key belongs to a non-revoked member
  /// other than this device, and this device is in a group and not removed.
  /// Used only to reject; decisions with side effects wait for the completed
  /// handshake.
  bool acceptsStatic(Uint8List x25519Pub) {
    if (!hasGroup || _removed) return false;
    final m = activeMemberByX25519(x25519Pub);
    return m != null && m.memberId != memberId;
  }

  /// Merges verified registration rows into the registry and the store.
  /// Returns the number of rows newly added.
  Future<int> mergeRegistrations(Iterable<OriginRegistration> rows, SyncStore store) async {
    final registry = _registry;
    if (registry == null) return 0;
    var added = 0;
    for (final row in rows) {
      final result = await registry.merge([row]);
      if (result.added == 1) {
        store.addRegistration(row);
        added++;
      }
    }
    return added;
  }

  /// Signs and stores the registration of [origin] under the current group.
  Future<OriginRegistration> registerOrigin(OriginId origin, SyncStore store) async {
    final g = _groupId ?? (throw StateError('not in a group'));
    final row =
        await signOriginRegistration(groupId: g, origin: origin, member: _identity.ed25519, createdHlc: store.hlc);
    await mergeRegistrations([row], store);
    return row;
  }

  /// Drops the in-memory registry and rebuilds everything from [store]
  /// (after a DB restore, whose registry may be smaller).
  Future<bool> reload(SyncStore store) {
    final g = _groupId;
    _registry = g == null ? null : OriginRegistrySet(g, members: _live);
    _fingerprint = '';
    return rebuild(store);
  }

  /// Rebuilds the derived view from [store] (security cells, registrations).
  /// Returns `true` when members, revocations or grants changed. Sets
  /// [removed] (and discards group keys) when this device's key is revoked.
  Future<bool> rebuild(SyncStore store) async {
    final g = _groupId;
    if (g == null) {
      _clearDerived();
      final changed = _fingerprint.isNotEmpty;
      _fingerprint = '';
      return changed;
    }
    final registry = _registry ??= OriginRegistrySet(g, members: _live);
    await registry.merge(store.registrations);

    final memberCells = <(_Carrier, MemberEntry)>[];
    for (final pk in store.rowsOf(SecurityTables.member).toList()) {
      final cell = store.storedCell(memberCellKey(pk));
      final value = cell?.record.value;
      if (cell == null || value is! Uint8List) continue;
      try {
        final entry = MemberEntry.decode(value);
        if (entry.memberId == pk) memberCells.add((_carrierOf(cell), entry));
      } on Object {
        continue;
      }
    }
    final revocationCells = <(_Carrier, RevocationRecord)>[];
    for (final pk in store.rowsOf(SecurityTables.revocation).toList()) {
      final cell = store.storedCell(CellKey(SecurityTables.revocation, pk, CellKey.rowCol));
      final value = cell?.record.value;
      if (cell == null || value is! Uint8List) continue;
      final record = _decodeRevocation(value);
      if (record != null) revocationCells.add((_carrierOf(cell), record));
    }
    final retainedRevocations = _decodeRetainedRevocations();
    final grantCells = <(_Carrier, EpochGrant)>[];
    for (final pk in store.rowsOf(SecurityTables.epochGrant).toList()) {
      final cell = store.storedCell(CellKey(SecurityTables.epochGrant, pk, CellKey.rowCol));
      final value = cell?.record.value;
      if (cell == null || value is! Uint8List) continue;
      try {
        grantCells.add((_carrierOf(cell), decodeEpochGrant(value)));
      } on Object {
        continue;
      }
    }

    var excluded = <String>{};
    late Map<String, MemberEntry> members;
    late RevocationSet revocations;
    late RevocationSet directoryRevocations;
    late MemberKeySet directory;
    for (var round = 0; round < _filterRounds; round++) {
      members = {..._anchors};
      for (final (carrier, entry) in memberCells) {
        if (!excluded.contains(_carrierId(carrier))) members.putIfAbsent(entry.memberId, () => entry);
      }
      directory = MemberKeySet([for (final m in members.values) m.ed25519Pub]);
      _live.current = directory;
      directoryRevocations = RevocationSet(g);
      await directoryRevocations.merge([
        for (final (carrier, record) in revocationCells)
          if (!excluded.contains(_carrierId(carrier))) record,
      ], directory);
      final ledgerOnly =
          await _mergeRetainedRevocations(directoryRevocations, retainedRevocations, excluded, directory);
      revocations = RevocationSet(g);
      await revocations.merge(directoryRevocations.records, directory);
      await _mergeLedgerOnlyRevocations(revocations, ledgerOnly, directory);
      final next = <String>{};
      for (final carrier in [
        for (final (c, _) in memberCells) c,
        for (final (c, _) in revocationCells) c,
        for (final retained in retainedRevocations) retained.carrier,
        for (final (c, _) in grantCells) c,
      ]) {
        final origin = OriginId.fromHex(carrier.origin);
        if (!revocations.accepts(origin, carrier.seq, registry) && registry.ownerOf(origin) is OriginRegisteredTo) {
          next.add(_carrierId(carrier));
        }
      }
      if (next.length == excluded.length && next.containsAll(excluded)) break;
      excluded = next;
    }

    _members = members;
    _byX25519 = {for (final m in members.values) _hex(m.x25519Pub): m};
    _revocations = revocations;
    _directoryRevocations = directoryRevocations;
    _revokedEd = {for (final k in revocations.revokedMembers) _hex(k)};
    _directoryRevokedEd = {for (final k in directoryRevocations.revokedMembers) _hex(k)};
    _grants = [
      for (final (carrier, grant) in grantCells)
        if (!excluded.contains(_carrierId(carrier))) grant,
    ];
    _live.current = directory;
    _verifier = ManifestVerifier(groupId: g, registry: registry, revocations: revocations, members: _live);
    // A ledger-only record must not remove this device and destroy its keys
    // (U11/Efe-R3); a genuine restore still removes it.
    if (!_removed && _directoryRevokedEd.contains(_hex(_identity.ed25519Pub))) {
      _removed = true;
      _keyring.destroy();
      _keyring = GroupKeyring();
    }
    if (!_removed) _growAnchors(members);
    final fingerprint = [
      ...(members.keys.toList()..sort()),
      '|',
      ...(_revokedEd.toList()..sort()),
      '|',
      '${_grants.length}',
      '|',
      '${revocations.records.length}',
      '|',
      '${registry.entries.length}',
    ].join(',');
    final changed = fingerprint != _fingerprint;
    _fingerprint = fingerprint;
    return changed;
  }

  /// The ledger's revocation records with their revokers' keys (U11/Efe-1).
  /// Undecodable records are skipped like undecodable DB cells; an
  /// undecodable revoker entry leaves the record to the member directory.
  List<_RetainedRevocation> _decodeRetainedRevocations() => [
        for (final retained in _retainedRevocations())
          if (_decodeRevocation(retained.recordBytes) case final record?)
            (
              carrier: (origin: retained.carrierOrigin.hex, seq: retained.carrierSeq),
              record: record,
              revokerPub: _decodeMember(retained.revokerEntryBytes)?.ed25519Pub,
            ),
      ];

  /// Merges the [retained] records not [excluded] whose revoker is in
  /// [directory] into [revocations] (restore case). Returns the others, which
  /// only [_mergeLedgerOnlyRevocations] may accept (U11/Efe-R2).
  static Future<List<_RetainedRevocation>> _mergeRetainedRevocations(
    RevocationSet revocations,
    List<_RetainedRevocation> retained,
    Set<String> excluded,
    MemberDirectory directory,
  ) async {
    final ledgerOnly = <_RetainedRevocation>[];
    for (final revocation in retained) {
      if (excluded.contains(_carrierId(revocation.carrier))) continue;
      final revokerPub = revocation.revokerPub;
      if (revokerPub == null || !directory.isMember(revokerPub)) {
        ledgerOnly.add(revocation);
        continue;
      }
      await revocations.merge([revocation.record], directory);
    }
    return ledgerOnly;
  }

  /// Merges [ledgerOnly] records into [revocations], each verified against
  /// [directory] plus its own revoker key only (U11/Efe-R1), so a forged
  /// ledger pair cannot certify anything else. They set local cutoffs only.
  static Future<void> _mergeLedgerOnlyRevocations(
    RevocationSet revocations,
    List<_RetainedRevocation> ledgerOnly,
    MemberDirectory directory,
  ) async {
    for (final revocation in ledgerOnly) {
      final revokerPub = revocation.revokerPub;
      final verifyingDirectory = revokerPub == null ? directory : _DirectoryWithRevoker(directory, revokerPub);
      await revocations.merge([revocation.record], verifyingDirectory);
    }
  }

  /// Decodes a revocation cell value (memoized), or `null` when malformed.
  RevocationRecord? _decodeRevocation(Uint8List value) {
    final cacheKey = _hex(value);
    try {
      return _recordCache[cacheKey] ??= decodeRevocationRecord(value);
    } on Object {
      return null;
    }
  }

  static MemberEntry? _decodeMember(Uint8List? value) {
    if (value == null) return null;
    try {
      return MemberEntry.decode(value);
    } on Object {
      return null;
    }
  }

  /// Trust anchors only grow (G2): every known member becomes an anchor, so
  /// a DB restored from before a member joined still accepts it and a revoked
  /// signer stays verifiable (D13, D14); an anchor whose key the DB shows
  /// revoked is flagged once, for good (G2b). A ledger-only revocation never
  /// flags (U11/Efe-R2): the flag is permanent and drives rotation.
  void _growAnchors(Map<String, MemberEntry> members) {
    _anchors.addAll(members);
    for (final a in _anchors.values) {
      if (_directoryRevokedEd.contains(_hex(a.ed25519Pub))) _revokedAnchors.add(a.memberId);
    }
  }

  /// Epochs known from the keyring and from grants.
  Set<EpochId> get knownEpochs => {..._keyring.epochs, for (final g in _grants) g.epoch};

  /// The re-rotation rule (D7).
  bool get mustRotate =>
      !_removed &&
      hasGroup &&
      EpochRules.mustRotate(
        knownEpochs: knownEpochs,
        heldEpochs: _keyring.epochs,
        grants: _grants,
        isRevoked: _isDirectoryExcluded,
        conflictedEpochs: _keyring.conflictedEpochs,
      );

  void _clearDerived() {
    _revocations = null;
    _directoryRevocations = null;
    _members = {..._anchors};
    _byX25519 = {for (final m in _members.values) _hex(m.x25519Pub): m};
    _revokedEd = {};
    _directoryRevokedEd = {};
    _grants = const [];
    _live.current = MemberKeySet([for (final m in _members.values) m.ed25519Pub]);
    _verifier = null;
  }

  @override
  String toString() => 'Membership($memberId, group ${_groupId ?? '-'}, ${_members.length} members'
      '${_removed ? ', removed' : ''})';
}
