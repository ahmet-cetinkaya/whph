// Restore, import and reset helpers for the T21 tests: snapshots of the DB,
// the key directory and the ledger directory, restarts over the same files,
// and the app services built over a device.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:whph/core/application/features/sync/services/sync_ledger_mark_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_state_store.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/shared/features/sync/file_sync_key_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../shared/features/sync/sync_security_test_support.dart';
import 'drift_sync_test_support.dart';

const int _pullBatchSize = 7;

Future<void> noDelay(Duration _) async {}

/// The two directories a data-folder restore replaces.
class DirectorySnapshot {
  final String databasePath;
  final Directory keyDirectory;
  final Directory ledgerDirectory;

  const DirectorySnapshot(
      this.databasePath, this.keyDirectory, this.ledgerDirectory);
}

extension RestorableSecurityDevice on SecurityDevice {
  Directory get keyDirectory => Directory('${root.path}/data');
  Directory get ledgerDirectory => Directory('${root.path}/state');

  SyncLedgerMarkService get marks => SyncLedgerMarkService(
      keyStore: keyStore, changeStore: database.store, delay: noDelay);

  SyncStartupCheckService get startup => SyncStartupCheckService(
      membershipService: service,
      keyStore: keyStore,
      changeStore: database.store,
      marks: marks);

  /// A consistent copy of the DB (what a backup contains).
  Future<String> snapshotDatabase(String label) async {
    final path = '${root.path}/$label.sqlite';
    await database.sql("VACUUM INTO '$path'");
    return path;
  }

  /// Copies the DB and both file directories (a home-folder snapshot).
  Future<DirectorySnapshot> snapshotEverything(String label) async {
    final databasePath = await snapshotDatabase(label);
    return DirectorySnapshot(
      databasePath,
      await _copyDirectory(keyDirectory, '${root.path}/$label-data'),
      await _copyDirectory(ledgerDirectory, '${root.path}/$label-state'),
    );
  }

  /// Replaces the DB file by [path] (an app restore) and restarts the services.
  Future<void> replaceDatabase(String path, {String? workingPath}) async {
    final working = workingPath ??
        '${root.path}/restored-${DateTime.now().microsecondsSinceEpoch}.sqlite';
    await File(path).copy(working);
    await openDatabaseFile(working);
  }

  /// Closes the current DB and opens the file at [path] (created by the
  /// schema's `onCreate` when it does not exist), then restarts the services.
  Future<void> openDatabaseFile(String path) async {
    await database.close();
    database = SyncTestDevice(
        name, AppDatabase.withExecutor(NativeDatabase(File(path))));
    await database.rows('SELECT 1');
    await restart();
  }

  /// Replaces the DB, the key file and the ledger by [snapshot].
  Future<void> restoreEverything(DirectorySnapshot snapshot) async {
    await _replaceDirectory(snapshot.keyDirectory, keyDirectory);
    await _replaceDirectory(snapshot.ledgerDirectory, ledgerDirectory);
    await replaceDatabase(snapshot.databasePath);
  }

  /// A process restart: new store objects over the same DB and files.
  Future<void> restart() async {
    keyStore = FileSyncKeyStore(
        keyDirectory: keyDirectory, ledgerDirectory: ledgerDirectory);
    peerStates = DriftSyncPeerStateStore(database.db);
    service = SyncMembershipService(
        keyStore: keyStore,
        changeStore: database.store,
        peerStateStore: peerStates);
  }

  Future<String> currentOrigin() => database.store.localOrigin();

  ManifestSigner manifestSigner(String originHex) => ManifestSigner(
      groupId: membership.groupId!,
      origin: OriginId.fromHex(originHex),
      signer: membership.identity.ed25519);

  Future<void> signManifests() async =>
      database.store.signOwnManifests(manifestSigner(await currentOrigin()));

  Future<Set<String>> noteIds() async => {
        for (final row in await database.rows('SELECT id FROM note_table'))
          row['id'] as String
      };

  Future<bool> hasNote(String id) async =>
      await database
          .count("SELECT COUNT(*) FROM note_table WHERE id = '$id'") ==
      1;

  Future<bool> isNoteDeleted(String id) async =>
      (await database
              .rows("SELECT deleted_date FROM note_table WHERE id = '$id'"))
          .single['deleted_date'] !=
      null;
}

/// One directional pull of every origin [from] holds above [into]'s cursor,
/// except [into]'s current origin, with the origin registrations first.
Future<void> pull(SecurityDevice from, SecurityDevice into) async {
  await into.database.store
      .mergeRegistrations(await from.database.store.readRegistrations());
  final own = await into.currentOrigin();
  final theirs = await from.database.store.readVector();
  final mine = await into.database.store.readVector();
  for (final entry in theirs.entries) {
    if (entry.key == own) continue;
    var after = mine[entry.key] ?? 0;
    while (after < entry.value) {
      final batch = await from.database.store.readChanges(entry.key,
          afterSeq: after, upToSeq: entry.value, limit: _pullBatchSize);
      await into.database.store.applyBatch(batch);
      after = batch.toSeq;
    }
  }
}

/// Both directions, twice, then the membership rebuild on each side.
Future<void> exchange(List<SecurityDevice> devices) async {
  for (var round = 0; round < 2; round++) {
    for (final from in devices) {
      for (final into in devices) {
        if (from != into) await pull(from, into);
      }
    }
  }
  for (final device in devices) {
    await device.service.refresh();
  }
}

Future<Directory> _copyDirectory(Directory source, String target) async {
  final copy = Directory(target);
  await copy.create(recursive: true);
  if (!await source.exists()) return copy;
  await for (final entity in source.list()) {
    if (entity is File) {
      await entity.copy('${copy.path}/${entity.uri.pathSegments.last}');
    }
  }
  return copy;
}

Future<void> _replaceDirectory(Directory source, Directory target) async {
  if (await target.exists()) await target.delete(recursive: true);
  await _copyDirectory(source, target.path);
}
