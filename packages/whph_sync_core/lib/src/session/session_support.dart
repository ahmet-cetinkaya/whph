/// Pure decision and batching helpers shared by [SyncSession] and
/// `AsyncSyncSession`: send plans, batch drafts, size estimates and the
/// apply / hold / reject decision for one received envelope (FR-021, FR-023,
/// D7). Nothing here touches a store.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../crypto/envelope.dart';
import '../crypto/manifest_signer.dart';
import '../membership/membership.dart';
import '../model/change.dart';
import '../model/envelope.dart';
import '../model/ids.dart';
import '../model/manifest.dart';
import '../protocol/messages.dart';
import '../store/replica_store.dart';
import '../store/sync_store.dart';
import 'session_result.dart';
import 'sync_device.dart';

/// Aborts a session with a failure category.
final class SessionAbort implements Exception {
  const SessionAbort(this.category, {this.peerCursor});

  final SessionFailure category;
  final int? peerCursor;

  @override
  String toString() => 'SessionAbort(${category.name})';
}

sealed class SessionDecision {
  const SessionDecision();
}

final class ApplyDecision extends SessionDecision {
  const ApplyDecision(this.change, this.manifest);

  final Change change;
  final OriginManifest manifest;
}

final class HoldDecision extends SessionDecision {
  const HoldDecision(this.reason, this.manifest, {this.rejectedAs});

  final HeldReason reason;
  final OriginManifest manifest;

  /// Also counted as a rejection (revoked above cutoff).
  final String? rejectedAs;
}

final class RejectDecision extends SessionDecision {
  const RejectDecision(this.reason);

  final String reason;
}

/// Per-origin send plan: stream `(declared, bound]`.
final class OriginPlan {
  OriginPlan(this.origin, this.declared, this.bound) : scanned = declared;

  final String origin;
  int declared;
  int scanned;
  int bound;
  bool done = false;

  /// Given up for this session: a superseded seq whose winner cannot be sent.
  bool stopped = false;
}

/// Why a winner could not or could be put into a batch (F5).
enum WinnerRelay { included, changed, noRoom, unusable }

/// The batch [SyncSession._stream] is filling.
final class BatchDraft {
  BatchDraft(this._config, {required this.own});

  final SyncEngineConfig _config;

  /// Hex of the current own origin.
  final String own;

  final Map<OriginId, List<SeqRange>> ranges = {};
  final Set<OriginManifest> manifests = {};
  final List<ChangeEnvelope> envelopes = [];
  final Set<String> versions = {};

  /// Superseded seqs passed together with their winner (debug oracle only).
  final Set<String> passed = {};
  int _bytes = 64;

  /// Highest own seq the batch declares or carries (the ledger's max_sent_seq).
  int ownTo = 0;

  /// No further item fits; the batch is sent as it is.
  bool full = false;

  bool get isEmpty => ranges.isEmpty && envelopes.isEmpty;

  bool overflows(int size, OriginManifest? manifest) {
    final extra = manifest == null || manifests.contains(manifest) ? 0 : manifestSize(manifest);
    return envelopes.isNotEmpty &&
        (envelopes.length >= _config.maxBatchChanges || _bytes + size + extra > _config.maxBatchBytes);
  }

  /// Adds the [envelope] of version `origin#seq`.
  void add(OriginManifest manifest, ChangeEnvelope envelope, int size, {required String origin, required int seq}) {
    _bytes += size + (manifests.contains(manifest) ? 0 : manifestSize(manifest));
    manifests.add(manifest);
    envelopes.add(envelope);
    versions.add('$origin#$seq');
    if (origin == own) ownTo = math.max(ownTo, seq);
  }

  bool covers(String origin, int seq) => ranges[OriginId.fromHex(origin)]?.any((range) => range.contains(seq)) ?? false;

  /// Declares [range] of [origin]. A narrow range of a winner that the new
  /// range contains is dropped: ranges of one origin must not overlap.
  void declare(String origin, SeqRange range) {
    final declared = ranges.putIfAbsent(OriginId.fromHex(origin), () => []);
    declared.removeWhere((narrow) => range.contains(narrow.to));
    declared.add(range);
    if (origin == own) ownTo = math.max(ownTo, range.to);
  }
}

String versionOf(CellRecord record) => '${record.origin}#${record.originSeq}';

bool isNeverSentSecurityCell(StoredCell cell, String ownOrigin) =>
    cell.manifest == null && cell.record.origin != ownOrigin && SecurityTables.contains(cell.record.key.table);

int estimateCell(CellRecord r) =>
    160 + r.key.table.length + r.key.pk.length * 2 + r.key.col.length + r.node.length + _valueSize(r.value);

int _valueSize(Object? value) => switch (value) {
      null => 0,
      int() => 8,
      String() => value.length * 3,
      Uint8List() => value.length,
      _ => ChangeValue.of(value).payload.length,
    };

int heldSize(HeldEnvelope h) =>
    160 + h.envelope.tbl.length + h.envelope.pk.length * 2 + h.envelope.col.length + h.envelope.ciphertext.length;

int manifestSize(OriginManifest m) => 104 + m.hashes.length * changeHashLength;

SessionDecision decideEnvelope(
    Membership m, ChangeEnvelope envelope, List<OriginManifest> manifests, List<ManifestVerdict> verdicts) {
  final candidates = <int>[
    for (var i = 0; i < manifests.length; i++)
      if (manifests[i].origin == envelope.origin && manifests[i].coversSeq(envelope.originSeq)) i,
  ];
  if (candidates.isEmpty) return const RejectDecision('noManifest');
  return decideWith(m, envelope, [for (final i in candidates) (manifests[i], verdicts[i])]);
}

/// Decides one envelope against candidate manifests (FR-021, FR-023,
/// D7): apply, hold (missing key; signer not yet known; revoked above the
/// current cutoff) or reject (tampered, not listed, wrong group...).
SessionDecision decideWith(Membership m, ChangeEnvelope envelope, List<(OriginManifest, ManifestVerdict)> candidates) {
  OriginManifest? holdable;
  String? rejection;
  for (final (manifest, verdict) in candidates) {
    if (verdict is ManifestRejected) {
      if (verdict.reason == ManifestRejection.signerNotMember ||
          verdict.reason == ManifestRejection.unregisteredOrigin) {
        holdable ??= manifest;
      } else {
        rejection ??= verdict.reason.name;
      }
    } else {
      holdable ??= manifest;
    }
  }
  final cipher = EnvelopeCipher(groupId: m.groupId!, keyring: m.keyring);
  switch (cipher.open(envelope)) {
    case MissingEpochKey():
      if (holdable != null) return HoldDecision(HeldReason.missingKey, holdable);
      return RejectDecision(rejection ?? 'manifest');
    case EnvelopeRejected():
      return const RejectDecision('envelope');
    case EnvelopeOpened(:final change):
      OriginManifest? unverified;
      String? revoked;
      for (final (manifest, verdict) in candidates) {
        if (verdict is! VerifiedManifest) continue;
        // A flagged signer with no known cutoff waits for its revocation
        // record instead of being verified without one (U11/Efe-R1).
        if (m.isFlaggedWithoutRecord(verdict.signerPub)) {
          unverified ??= manifest;
          continue;
        }
        final check = m.verifier.checkChange(change, verdict);
        if (check.isAccepted) return ApplyDecision(change, manifest);
        switch (check.rejection!) {
          case ManifestRejection.revokedAboveCutoff:
            unverified ??= manifest;
            revoked = 'revokedAboveCutoff';
          case ManifestRejection.signerNotMember || ManifestRejection.unregisteredOrigin:
            unverified ??= manifest;
          default:
            rejection ??= check.rejection!.name;
        }
      }
      if (unverified != null) return HoldDecision(HeldReason.unverified, unverified, rejectedAs: revoked);
      if (holdable != null && rejection == null) return HoldDecision(HeldReason.unverified, holdable);
      return RejectDecision(rejection ?? 'manifest');
  }
}

/// Whether [a] and [b] are the same stored version of a cell. A database store
/// returns a fresh record per read, so identity cannot tell.
bool sameVersion(CellRecord a, CellRecord b) =>
    a.origin == b.origin && a.originSeq == b.originSeq && a.clock == b.clock && a.node == b.node;
