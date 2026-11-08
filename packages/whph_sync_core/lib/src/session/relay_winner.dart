import '../store/sync_store.dart';

/// The version the sender must put into the batch that omits a superseded seq
/// (F5, FR-014), or `null` when nothing has to travel with it.
///
/// [committed] is the cell now stored for the superseded version's key; a
/// held (failed-to-apply) newer version is never a candidate, because the
/// receiver cannot commit it. The receiver needs nothing when its cursor
/// [peerCursorOfWinnerOrigin] already reaches the winner.
StoredCell? selectRelayWinner(StoredCell? committed, int peerCursorOfWinnerOrigin) {
  if (committed == null) return null;
  return committed.record.originSeq <= peerCursorOfWinnerOrigin ? null : committed;
}
