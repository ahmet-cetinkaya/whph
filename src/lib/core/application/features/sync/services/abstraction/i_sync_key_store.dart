import 'package:whph_sync_core/whph_sync_core.dart';

/// The key file could not be read or written safely (D7). A damaged key file
/// is an error, never "missing": a missing file starts the key-loss flow with
/// a new identity (D14), so a read problem must not look like one.
class SyncKeyStoreException implements Exception {
  final String message;
  const SyncKeyStoreException(this.message);

  @override
  String toString() => 'SyncKeyStoreException: $message';
}

/// The key file as the membership service keeps it: the snapshot plus the
/// "needs re-pairing" flag set after a key loss (D14).
class SyncKeyFileContent {
  final KeyFileSnapshot snapshot;
  final bool needsRepairing;

  const SyncKeyFileContent({required this.snapshot, required this.needsRepairing});
}

/// The two local files outside the database (D7): the secret key file
/// `sync_keys.json` and the sync ledger `sync_ledger.json` (U11, F4). The
/// ledger half is the core [SyncLedger] port (origin list with
/// `pending`/`committed` states, `persistSentMark`, `epoch_counter_high`,
/// retained revocations, `deleteAll`).
///
/// Order rule: the caller persists `epoch_counter_high` through the ledger
/// before it calls [writeKeyFile] with the epoch key that counter names.
abstract interface class ISyncKeyStore implements SyncLedger {
  /// Reads the ledger into memory so the synchronous [SyncLedger] getters
  /// answer. A missing or unparsable ledger leaves [isReadable] `false`.
  Future<void> load();

  /// Whether the key file exists on disk.
  Future<bool> keyFileExists();

  /// The key file, or `null` when it does not exist. Throws
  /// [SyncKeyStoreException] when it exists but cannot be trusted (symbolic
  /// link, wrong mode, damaged content).
  Future<SyncKeyFileContent?> readKeyFile();

  /// Replaces the key file atomically and owner-only. A failed write leaves
  /// the previous file byte-identical.
  Future<void> writeKeyFile(SyncKeyFileContent content);
}
