import 'dart:math' as math;

import 'package:whph/core/application/features/sync/services/abstraction/i_sync_change_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// Waits between sent-mark write retries (D7: 1 s, 2 s, 4 s).
const List<Duration> defaultSentMarkRetryDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];

/// Persists the two ledger marks of the current origin (D7, D14): the
/// sent-seq mark the engine writes before it sends, and the written watermark
/// the app flushes at lifecycle events. Both only ever grow.
class SyncLedgerMarkService {
  final ISyncKeyStore _keyStore;
  final ISyncChangeStore _changeStore;
  final List<Duration> _retryDelays;
  final Future<void> Function(Duration) _delay;

  SyncLedgerMarkService({
    required ISyncKeyStore keyStore,
    required ISyncChangeStore changeStore,
    List<Duration> retryDelays = defaultSentMarkRetryDelays,
    Future<void> Function(Duration)? delay,
  })  : _keyStore = keyStore,
        _changeStore = changeStore,
        _retryDelays = retryDelays,
        _delay = delay ?? Future<void>.delayed;

  /// Engine hook: call before sending a batch whose highest own seq is
  /// [highestSeq]. Returns `true` when the mark covers it (already did, or it
  /// was written), `false` after the retries failed: the session must not send
  /// and ends `partial(storage error)` while it keeps applying incoming
  /// changes (D7).
  Future<bool> persistSentMarkBefore(int highestSeq) async {
    final state = await _changeStore.readLocalState();
    final origin = OriginId.fromHex(state.localOrigin);
    final current = _keyStore.entryOf(origin)?.maxSentSeq ?? 0;
    if (highestSeq <= current) return true;
    for (var attempt = 0;; attempt++) {
      try {
        await _keyStore.persistSentMark(origin, highestSeq, state.hlc);
        return true;
      } on SyncLedgerWriteException {
        if (attempt >= _retryDelays.length) return false;
        await _delay(_retryDelays[attempt]);
      }
    }
  }

  /// Persists the written watermark when the DB authored seqs above it
  /// (card A). A failed write returns `false` and is retried on the next
  /// flush; the watermark never moves down, so a restored DB cannot lower it.
  Future<bool> flushWrittenWatermark() async {
    final state = await _changeStore.readLocalState();
    final origin = OriginId.fromHex(state.localOrigin);
    final entry = _keyStore.entryOf(origin);
    if (!_keyStore.isReadable || entry == null) return false;
    if (state.nextSeq <= entry.nextSeqHigh) return false;
    try {
      await _keyStore.persistWrittenWatermark(
          origin, state.nextSeq, math.max(state.hlc, entry.hlcHighWritten));
      return true;
    } on SyncLedgerWriteException {
      return false;
    }
  }
}
