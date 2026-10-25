// T21 acceptance 8: "Reset database" on a paired device (U5) through the real
// ResetLocalDataService, the file key store, a file-backed Drift DB and the
// startup check; interrupted resets and a restored pre-reset backup.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/reset_local_data_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/database_backup_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import '../../../../infrastructure/persistence/sync/local_reset_test_support.dart';
import '../../../../infrastructure/persistence/sync/restore_test_support.dart';
import '../../../../infrastructure/shared/features/sync/sync_security_test_support.dart';

const String _databaseFileName = 'debug_whph.db';
const String _peerAddress = '192.168.1.20';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory scratch;
  late Directory applicationDirectory;
  late SecurityDevice a;
  late SecurityDevice b;

  File databaseFile() =>
      File('${applicationDirectory.path}/$_databaseFileName');

  ResetLocalDataService resetService() => ResetLocalDataService(
        keyStore: a.keyStore,
        createPreResetBackup: () => a.appDatabase.createPreResetBackup(),
        resetDatabase: (backup) =>
            a.appDatabase.resetDatabase(preResetBackup: backup),
      );

  Future<SyncStartupAction> start({required bool databaseCreatedThisLaunch}) =>
      a.startup.run(
          deviceName: 'a',
          databaseCreatedThisLaunch: databaseCreatedThisLaunch);

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('t21_reset_');
    applicationDirectory = await Directory('${scratch.path}/app').create();
    AppDatabase.backupServiceForTesting = DatabaseBackupService(
      getApplicationDirectory: () async => applicationDirectory,
      databaseName: 'whph.db',
      isTestMode: true,
    );
    a = await SecurityDevice.open('a', scratch);
    b = await SecurityDevice.open('b', scratch);
    await pairDevices(a, b);
    await a.database.insertNote('n1', 'kept in the pre-reset backup');
    await exchange([a, b]);
    // From here the device runs on a DB file in the application directory.
    final snapshot = await a.snapshotDatabase('seed');
    await a.replaceDatabase(snapshot, workingPath: databaseFile().path);
    await a.service.loadKeyFile();
  });

  tearDown(() async {
    AppDatabase.backupServiceForTesting = null;
    AppDatabase.resetInstance();
    await a.database.close();
    await b.database.close();
    await scratch.delete(recursive: true);
  });

  test('reset removes key file, ledger, DB and sidecars and leaves the group',
      () async {
    final formerMember = a.memberId;
    final formerPublicKey = a.membership.identity.x25519Pub;
    expect(await a.service.isPaired(), isTrue);
    expect(await a.keyStore.keyFileExists(), isTrue);

    await resetService().reset();

    expect(a.keyStore.keyFile.existsSync(), isFalse);
    expect(a.keyStore.ledgerFile.existsSync(), isFalse);
    expect(databaseFile().existsSync(), isFalse);
    expect(File('${databaseFile().path}-wal').existsSync(), isFalse);
    expect(File('${databaseFile().path}-shm').existsSync(), isFalse);
    expect(
        Directory('${applicationDirectory.path}/backups/pre_reset')
            .listSync()
            .whereType<File>(),
        isNotEmpty,
        reason: 'the pre-reset backup is written first');

    await a.openDatabaseFile(databaseFile().path);
    expect(await start(databaseCreatedThisLaunch: true),
        SyncStartupAction.freshIdentity);

    expect(a.memberId, isNot(formerMember));
    expect(a.membership.groupId, isNull);
    expect(await a.database.count('SELECT COUNT(*) FROM sync_member_table'), 0);
    expect((await a.service.currentView()).state, SyncGroupState.ungrouped);
    expect(await a.service.isPaired(), isFalse);
    expect(await handshakeRefused(a, b), isTrue,
        reason: 'the former peer refuses the new static key');

    final verdict = await b.service.checkOutboundStaticKey(
        expectedMemberId: formerMember,
        address: _peerAddress,
        observedX25519: a.membership.identity.x25519Pub);
    expect(verdict, OutboundKeyVerdict.needsRepairing);
    expect((await b.service.currentView()).peersNeedingRepairing,
        contains(formerMember));
    expect(a.membership.identity.x25519Pub, isNot(formerPublicKey));
  });

  test('interrupted reset: key file gone, DB kept -> new identity, data kept',
      () async {
    final formerMember = a.memberId;
    await a.keyStore.deleteAll();
    await a.restart();

    expect(await start(databaseCreatedThisLaunch: false),
        SyncStartupAction.keyLost);

    expect(a.memberId, isNot(formerMember));
    expect(
        (await a.service.currentView()).state, SyncGroupState.needsRepairing);
    expect(await a.hasNote('n1'), isTrue);
  });

  test('interrupted reset: DB gone, key file kept -> fresh unpaired identity',
      () async {
    final formerMember = a.memberId;
    await a.database.close();
    await databaseFile().delete();
    await a.openDatabaseFile(databaseFile().path);

    expect(await start(databaseCreatedThisLaunch: true),
        SyncStartupAction.freshIdentity);

    expect(a.memberId, isNot(formerMember));
    expect(await a.service.isPaired(), isFalse);
    expect(a.membership.groupId, isNull);
  });

  test('a pre-reset backup restored later takes startup rule 2', () async {
    final backup = Directory('${applicationDirectory.path}/backups/pre_reset');
    await resetService().reset();
    final backupFile = backup.listSync().whereType<File>().single;
    await a.openDatabaseFile(databaseFile().path);
    await start(databaseCreatedThisLaunch: true);
    final newMember = a.memberId;

    await a.replaceDatabase(backupFile.path, workingPath: databaseFile().path);

    expect(await start(databaseCreatedThisLaunch: false),
        SyncStartupAction.keyLost);
    expect(a.memberId, isNot(newMember));
    expect(await a.hasNote('n1'), isTrue);
  });
}
