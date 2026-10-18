/// The sync ledger `sync_ledger.json` (D7, D6b, D14): the device's list of
/// change-sequence origins with their state, switch reason, sent-seq mark and
/// HLC high-water mark, plus the signed revocation records of the current
/// group (U11/Efe-1).
///
/// It lives outside the DB and outside the app data directory (U11), so a
/// restored or copied data folder can be recognised (D14 startup check
/// rule 4), never-sent cells can be told apart from cells some peer may hold
/// (`max_sent_seq`, D6b), a restore cannot move the HLC back (`hlc_high`) and
/// a restored device still knows every revocation it ever committed.
/// The file-backed implementation is T20; this package ships the in-memory
/// one used by the engine tests and the simulator.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/ids.dart';

/// Why a device switched to a new origin (D6b). [initial] marks the first
/// origin of a fresh device.
enum OriginSwitchReason { initial, restore, keyLost, localReset, groupSwitch }

/// Crash-safety state of a ledger entry (D6b steps 1 and 3).
enum OriginEntryState { pending, committed }

/// One ledger entry.
final class OriginEntry {
  OriginEntry({
    required this.origin,
    required this.state,
    required this.reason,
    this.maxSentSeq = 0,
    this.hlcHigh = 0,
    this.nextSeqHigh = 0,
    this.hlcHighWritten = 0,
  }) {
    if (maxSentSeq < 0) throw ArgumentError.value(maxSentSeq, 'maxSentSeq', 'must be non-negative');
    if (hlcHigh < 0) throw ArgumentError.value(hlcHigh, 'hlcHigh', 'must be non-negative');
    if (nextSeqHigh < 0) throw ArgumentError.value(nextSeqHigh, 'nextSeqHigh', 'must be non-negative');
    if (hlcHighWritten < 0) throw ArgumentError.value(hlcHighWritten, 'hlcHighWritten', 'must be non-negative');
  }

  final OriginId origin;
  final OriginEntryState state;
  final OriginSwitchReason reason;

  /// Highest own seq of [origin] that was ever handed to the transport.
  final int maxSentSeq;

  /// The device's HLC when the mark was last written (F3): a restore raises
  /// the HLC to at least this, so a lost write is never re-issued below it.
  final int hlcHigh;

  /// Grow-only watermark of seqs this device ever AUTHORED under [origin],
  /// sent or not (card A): a data-dir restore below unsent writes cannot
  /// re-author those seqs, because the ledger remembers them. `nextSeq - 1`
  /// is the high-water value; 0 = none recorded.
  final int nextSeqHigh;

  /// The device's HLC at the last [nextSeqHigh] update: a restore raises the
  /// HLC floor to at least this, so an unsent write's `(node, hlc)` is never
  /// re-issued for different content (card A).
  final int hlcHighWritten;

  OriginEntry copyWith({
    OriginEntryState? state,
    int? maxSentSeq,
    int? hlcHigh,
    int? nextSeqHigh,
    int? hlcHighWritten,
  }) =>
      OriginEntry(
        origin: origin,
        state: state ?? this.state,
        reason: reason,
        maxSentSeq: maxSentSeq ?? this.maxSentSeq,
        hlcHigh: hlcHigh ?? this.hlcHigh,
        nextSeqHigh: math.max(nextSeqHigh ?? 0, this.nextSeqHigh),
        hlcHighWritten: math.max(hlcHighWritten ?? 0, this.hlcHighWritten),
      );

  @override
  String toString() =>
      'OriginEntry($origin, ${state.name}, ${reason.name}, sent<=$maxSentSeq, hlc<=$hlcHigh, writtenSeq<$nextSeqHigh, writtenHlc<$hlcHighWritten)';
}

/// A signed `sync_revocation` record as the ledger keeps it (U11/Efe-1): the
/// cell value and the `(origin, seq)` of the change that carried it, so the
/// re-ingested record passes the same revoked-author filter as its DB cell
/// (D13), plus the revoker's member entry, so the record still verifies when
/// a restored DB and key file predate the revoker.
final class LedgerRevocation {
  LedgerRevocation({
    required List<int> recordBytes,
    required List<int>? revokerEntryBytes,
    required this.carrierOrigin,
    required this.carrierSeq,
  })  : recordBytes = Uint8List.fromList(recordBytes).asUnmodifiableView(),
        revokerEntryBytes =
            revokerEntryBytes == null ? null : Uint8List.fromList(revokerEntryBytes).asUnmodifiableView() {
    if (carrierSeq < 1) throw ArgumentError.value(carrierSeq, 'carrierSeq', 'must be positive');
  }

  /// The encoded revocation record (`encodeRevocationRecord`).
  final Uint8List recordBytes;

  /// The encoded `sync_member` entry of the revoker (`MemberEntry.encode`),
  /// or `null` when the revoker was not a known member at commit time.
  final Uint8List? revokerEntryBytes;
  final OriginId carrierOrigin;
  final int carrierSeq;

  /// `origin#seq` of the carrying change, the id the membership filter uses.
  String get carrierId => '${carrierOrigin.hex}#$carrierSeq';

  @override
  String toString() => 'LedgerRevocation($carrierId)';
}

/// A failed or torn sync-ledger write (D7 "Sent-seq mark": the batch is not
/// sent; the engine retries and finally ends the session with the category
/// storage error).
final class SyncLedgerWriteException implements Exception {
  const SyncLedgerWriteException(this.message);

  final String message;

  @override
  String toString() => 'SyncLedgerWriteException: $message';
}

/// Storage port of the sync ledger.
abstract interface class SyncLedger {
  /// Whether the file exists and parses. A missing or unreadable file makes
  /// the D14 startup check treat the DB as restored.
  bool get isReadable;

  /// Every entry, oldest first. Empty when [isReadable] is `false`.
  List<OriginEntry> get entries;

  /// Appends [entry] (D6b step 1, `pending`).
  Future<void> append(OriginEntry entry);

  /// Marks the entry of [origin] `committed` (D6b step 3).
  Future<void> commit(OriginId origin);

  /// Drops the entry of [origin] (D14 crash recovery of a pending switch
  /// the DB never adopted).
  Future<void> drop(OriginId origin);

  /// Persists `max_sent_seq = seq` and `hlc_high = hlc` for [origin] in one
  /// write before a batch above the current mark is sent. Throws
  /// [SyncLedgerWriteException] on failure.
  Future<void> persistSentMark(OriginId origin, int seq, int hlc);

  /// Persists the grow-only written watermark (card A): everything up to
  /// [nextSeq] was authored under [origin], sent or not, at device HLC
  /// [hlc]. Called at snapshot time so a later restore below unsent writes
  /// is detectable. Throws [SyncLedgerWriteException] on failure.
  Future<void> persistWrittenWatermark(OriginId origin, int nextSeq, int hlc);

  /// The highest epoch counter this device ever created (device-global, U11
  /// G1); 0 when none. Rotation counts above it, so a rolled-back key file
  /// cannot re-create an epoch id.
  int get epochCounterHigh;

  /// Persists `epoch_counter_high = counter` when it exceeds the stored value.
  /// Awaited before the new epoch key is stored. Throws
  /// [SyncLedgerWriteException] on failure.
  Future<void> persistEpochCounterHigh(int counter);

  /// Resets `epoch_counter_high` to 0 when the device exits the group (group
  /// switch, key loss), together with the key file's epoch keys.
  Future<void> resetEpochCounterHigh();

  /// The signed revocation records this device committed in the current
  /// group, oldest first (U11/Efe-1). Empty when [isReadable] is `false`.
  List<LedgerRevocation> get revocations;

  /// Adds [revocations] (grow-only; duplicates are ignored). Awaited before
  /// the carrying cells are committed to the DB, like `epoch_counter_high`,
  /// so a restored DB and key file cannot forget a revocation. Throws
  /// [SyncLedgerWriteException] on failure.
  Future<void> persistRevocations(Iterable<LedgerRevocation> revocations);

  /// Drops every revocation record when the device exits the group (group
  /// switch, key loss).
  Future<void> clearRevocations();

  /// Deletes the file (U5 reset, D14 rule 1); also how tests lose it.
  Future<void> deleteAll();
}

/// Convenience queries over a [SyncLedger].
extension SyncLedgerQueries on SyncLedger {
  /// The entry of [origin], or `null`.
  OriginEntry? entryOf(OriginId origin) {
    for (final e in entries.reversed) {
      if (e.origin == origin) return e;
    }
    return null;
  }

  /// The latest entry, or `null`.
  OriginEntry? get latest => entries.isEmpty ? null : entries.last;

  /// The latest committed entry, or `null`.
  OriginEntry? get latestCommitted {
    for (final e in entries.reversed) {
      if (e.state == OriginEntryState.committed) return e;
    }
    return null;
  }

  /// The highest `hlc_high` over all entries (F3), or 0.
  int get hlcFloor => entries.fold(0, (floor, e) => math.max(floor, math.max(e.hlcHigh, e.hlcHighWritten)));
}

/// In-memory [SyncLedger] with fault injection for tests and the simulator.
final class InMemorySyncLedger implements SyncLedger {
  InMemorySyncLedger();

  List<OriginEntry> _entries = [];
  int _epochCounterHigh = 0;
  Map<String, LedgerRevocation> _revocations = {};
  bool _readable = true;

  /// Number of upcoming [persistSentMark] calls that fail (then succeed).
  int failNextSentMarkWrites = 0;

  /// Every [persistSentMark] call fails while `true`.
  bool failAllSentMarkWrites = false;

  /// Number of successful sent-mark writes (at most one per batch, D7).
  int sentMarkWrites = 0;

  /// Every [persistRevocations] call fails while `true`.
  bool failAllRevocationWrites = false;

  @override
  bool get isReadable => _readable;

  @override
  List<OriginEntry> get entries => _readable ? List.unmodifiable(_entries) : const [];

  @override
  Future<void> append(OriginEntry entry) async {
    if (!_readable) {
      _entries = [];
      _readable = true;
    }
    _entries.add(entry);
  }

  @override
  Future<void> commit(OriginId origin) async => _replace(origin, (e) => e.copyWith(state: OriginEntryState.committed));

  @override
  Future<void> drop(OriginId origin) async => _entries.removeWhere((e) => e.origin == origin);

  @override
  Future<void> persistWrittenWatermark(OriginId origin, int nextSeq, int hlc) async {
    if (failAllSentMarkWrites) throw const SyncLedgerWriteException('injected sent-mark write failure');
    if (failNextSentMarkWrites > 0) {
      failNextSentMarkWrites--;
      throw const SyncLedgerWriteException('injected sent-mark write failure');
    }
    if (!_readable) throw const SyncLedgerWriteException('sync ledger missing');
    _replace(
      origin,
      (e) => e.copyWith(nextSeqHigh: math.max(nextSeq, e.nextSeqHigh), hlcHighWritten: math.max(hlc, e.hlcHighWritten)),
    );
  }

  @override
  Future<void> persistSentMark(OriginId origin, int seq, int hlc) async {
    if (failAllSentMarkWrites) throw const SyncLedgerWriteException('injected sent-mark write failure');
    if (failNextSentMarkWrites > 0) {
      failNextSentMarkWrites--;
      throw const SyncLedgerWriteException('injected sent-mark write failure');
    }
    if (!_readable) throw const SyncLedgerWriteException('sync ledger missing');
    _replace(
      origin,
      (e) => e.copyWith(maxSentSeq: math.max(seq, e.maxSentSeq), hlcHigh: math.max(hlc, e.hlcHigh)),
    );
    sentMarkWrites++;
  }

  @override
  int get epochCounterHigh => _epochCounterHigh;

  @override
  Future<void> persistEpochCounterHigh(int counter) async {
    if (!_readable) throw const SyncLedgerWriteException('sync ledger missing');
    _epochCounterHigh = math.max(_epochCounterHigh, counter);
  }

  @override
  Future<void> resetEpochCounterHigh() async => _epochCounterHigh = 0;

  @override
  List<LedgerRevocation> get revocations => _readable ? List.unmodifiable(_revocations.values) : const [];

  @override
  Future<void> persistRevocations(Iterable<LedgerRevocation> revocations) async {
    if (failAllRevocationWrites) throw const SyncLedgerWriteException('injected revocation write failure');
    if (!_readable) throw const SyncLedgerWriteException('sync ledger missing');
    for (final r in revocations) {
      _revocations.putIfAbsent(_revocationKey(r), () => r);
    }
  }

  @override
  Future<void> clearRevocations() async => _revocations = {};

  @override
  Future<void> deleteAll() async {
    _entries = [];
    _epochCounterHigh = 0;
    _revocations = {};
    _readable = false;
  }

  /// A copy of the current content (for whole-directory snapshots).
  InMemorySyncLedger snapshot() => InMemorySyncLedger()
    .._entries = List.of(_entries)
    .._epochCounterHigh = _epochCounterHigh
    .._revocations = Map.of(_revocations)
    .._readable = _readable;

  /// Replaces the content with [snapshot]'s.
  void restoreFrom(InMemorySyncLedger snapshot) {
    _entries = List.of(snapshot._entries);
    _epochCounterHigh = snapshot._epochCounterHigh;
    _revocations = Map.of(snapshot._revocations);
    _readable = snapshot._readable;
  }

  static String _revocationKey(LedgerRevocation r) =>
      '${r.carrierId}:${r.recordBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

  void _replace(OriginId origin, OriginEntry Function(OriginEntry) update) {
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i].origin == origin) {
        _entries[i] = update(_entries[i]);
        return;
      }
    }
    throw SyncLedgerWriteException('no entry for origin $origin');
  }

  @override
  String toString() => 'InMemorySyncLedger(${_entries.length} entries${_readable ? '' : ', unreadable'})';
}
