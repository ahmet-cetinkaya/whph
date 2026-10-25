import 'dart:io';

import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';

/// "Reset database" (U5): the device leaves its sync group and starts fresh.
///
/// Order matters: the pre-reset backup first, then the key file and ledger,
/// then the DB files. A crash after the second step leaves a DB without its
/// key file, which the startup check treats as key loss (D14 rule 2); the
/// reverse order cannot occur.
class ResetLocalDataService {
  final ISyncKeyStore _keyStore;
  final Future<File?> Function() _createPreResetBackup;
  final Future<void> Function(File? preResetBackup) _resetDatabase;

  ResetLocalDataService({
    required ISyncKeyStore keyStore,
    required Future<File?> Function() createPreResetBackup,
    required Future<void> Function(File? preResetBackup) resetDatabase,
  })  : _keyStore = keyStore,
        _createPreResetBackup = createPreResetBackup,
        _resetDatabase = resetDatabase;

  Future<void> reset() async {
    final backup = await _createPreResetBackup();
    await _keyStore.deleteAll();
    await _resetDatabase(backup);
  }
}
