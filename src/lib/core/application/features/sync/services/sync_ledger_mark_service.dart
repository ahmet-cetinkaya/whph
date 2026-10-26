import 'dart:math' as math;

import 'package:whph/core/application/features/sync/services/abstraction/i_sync_change_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// Persists the written watermark of the current origin (D14) that the app
/// flushes at lifecycle events. It only ever grows. The sent-seq mark is
/// written by the session itself (`AsyncSession`, D7).
class SyncLedgerMarkService {
  final ISyncKeyStore _keyStore;
  final ISyncChangeStore _changeStore;

  SyncLedgerMarkService({
    required ISyncKeyStore keyStore,
    required ISyncChangeStore changeStore,
  })  : _keyStore = keyStore,
        _changeStore = changeStore;

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
