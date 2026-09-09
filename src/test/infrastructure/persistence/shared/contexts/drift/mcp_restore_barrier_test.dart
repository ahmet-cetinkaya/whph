import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';
import 'package:whph/core/application/shared/services/mcp_restore_barrier.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/database_backup_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

void main() {
  late Directory temporaryDirectory;
  late McpRestoreBarrier barrier;
  late AppDatabase database;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('whph_restore_barrier_');
    barrier = McpRestoreBarrier();
    database = AppDatabase.withExecutor(
      NativeDatabase(File(p.join(temporaryDirectory.path, 'source.sqlite'))),
      restoreBarrier: barrier,
    );
    await database.customStatement('CREATE TABLE IF NOT EXISTS barrier_probe (value INTEGER NOT NULL)');
  });

  tearDown(() async {
    await database.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('exclusive restore rejects unrelated direct and repository queries', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final exclusive = barrier.runExclusive(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;

    await expectLater(
      () => database.customSelect('SELECT 1').get(),
      throwsA(isA<RestoreBusyException>()),
    );
    await expectLater(
      () => DriftNoteRepository.withDatabase(database).getAll(),
      throwsA(isA<RestoreBusyException>()),
    );

    release.complete();
    await exclusive;
  });

  test('admitted paused transaction drains and can finish after closure', () async {
    final transactionPaused = Completer<void>();
    final finishTransaction = Completer<void>();
    final restoreEntered = Completer<void>();
    final transaction = database.transaction(() async {
      await database.customStatement('INSERT INTO barrier_probe VALUES (1)');
      transactionPaused.complete();
      await finishTransaction.future;
      await database.customStatement('INSERT INTO barrier_probe VALUES (2)');
    });
    await transactionPaused.future;

    final exclusive = barrier.runExclusive(() async {
      restoreEntered.complete();
      await database.customStatement('INSERT INTO barrier_probe VALUES (3)');
    });
    expect(barrier.isRestoreActive, isTrue);
    await expectLater(
      () => database.customSelect('SELECT 1').get(),
      throwsA(isA<RestoreBusyException>()),
    );
    expect(restoreEntered.isCompleted, isFalse);

    finishTransaction.complete();
    await transaction;
    await exclusive;
    final count = await database.customSelect('SELECT COUNT(*) AS count FROM barrier_probe').getSingle();
    expect(count.read<int>('count'), 3);
  });

  test('nested transaction and batch lifetimes drain without leaking admission', () async {
    await database.transaction(() async {
      await database.transaction(() async {
        await database.batch((batch) {
          batch.customStatement('INSERT INTO barrier_probe VALUES (4)');
          batch.customStatement('INSERT INTO barrier_probe VALUES (5)');
        });
      });
    });

    await barrier.runExclusive(() async {
      await database.customSelect('SELECT COUNT(*) FROM barrier_probe').get();
    });
    expect(await database.customSelect('SELECT 1').get(), isNotEmpty);
  });

  test('double exclusive and expired owner fail without sticking barrier', () async {
    final ownerEntered = Completer<void>();
    final ownerRelease = Completer<void>();
    final first = barrier.runExclusive(() async {
      ownerEntered.complete();
      await ownerRelease.future;
    });
    await ownerEntered.future;

    await expectLater(
      barrier.runExclusive(() async {}),
      throwsA(isA<RestoreBusyException>()),
    );
    ownerRelease.complete();
    await first;

    await expectLater(
      barrier.runExclusive(
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await database.customSelect('SELECT 1').get();
        },
        ownerLifetime: const Duration(milliseconds: 10),
      ),
      throwsA(isA<RestoreBusyException>()),
    );
    expect(barrier.isRestoreActive, isFalse);
    expect(await database.customSelect('SELECT 1').get(), isNotEmpty);
  });

  test('expired owner does not reopen admission before restore settles', () async {
    final releaseOwner = Completer<void>();
    final exclusive = barrier.runExclusive(
      () => releaseOwner.future,
      ownerLifetime: const Duration(milliseconds: 10),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(barrier.isRestoreActive, isTrue);
    await expectLater(
      () => database.customSelect('SELECT 1').get(),
      throwsA(isA<RestoreBusyException>()),
    );
    releaseOwner.complete();
    await exclusive;
  });

  test('detached owner zone cannot bypass a later restore', () async {
    final runDetached = Completer<void>();
    late Future<void> detachedQuery;
    await barrier.runExclusive(() async {
      detachedQuery = Future<void>(() async {
        await runDetached.future;
        await database.customSelect('SELECT 1').get();
      });
    });

    final secondEntered = Completer<void>();
    final releaseSecond = Completer<void>();
    final second = barrier.runExclusive(() async {
      secondEntered.complete();
      await releaseSecond.future;
    });
    await secondEntered.future;
    runDetached.complete();
    await expectLater(detachedQuery, throwsA(isA<RestoreBusyException>()));
    releaseSecond.complete();
    await second;
  });

  test('transaction rollback failure path does not leak admission', () async {
    await expectLater(
      database.transaction<void>(() async {
        await database.customStatement('INSERT INTO barrier_probe VALUES (7)');
        throw StateError('force rollback');
      }),
      throwsStateError,
    );

    await barrier.runExclusive(() async {
      expect(barrier.isRestoreOwner, isTrue);
      await database.customSelect('SELECT 1').get();
    });
  });

  test('deferred commit failure releases transaction admission', () async {
    await database.customStatement('PRAGMA foreign_keys = ON');
    await database.customStatement(
      'CREATE TABLE barrier_parent (id INTEGER PRIMARY KEY)',
    );
    await database.customStatement('''
      CREATE TABLE barrier_child (
        parent_id INTEGER,
        FOREIGN KEY(parent_id) REFERENCES barrier_parent(id)
          DEFERRABLE INITIALLY DEFERRED
      )
    ''');

    await expectLater(
      database.transaction<void>(() async {
        await database.customStatement(
          'INSERT INTO barrier_child(parent_id) VALUES (404)',
        );
      }),
      throwsA(anything),
    );
    await barrier.runExclusive(() async {
      await database.customSelect('SELECT 1').get();
    });
    expect(await database.customSelect('SELECT 1').get(), isNotEmpty);
  });

  test('shared operation cannot promote itself to exclusive', () async {
    await expectLater(
      barrier.runShared(
        () => barrier.runExclusive(() async {}),
      ),
      throwsA(isA<RestoreBusyException>()),
    );
    expect(barrier.isRestoreActive, isFalse);
  });

  test('invalid owner lifetime fails before closing admission', () async {
    await expectLater(
      barrier.runExclusive(
        () async {},
        ownerLifetime: Duration.zero,
      ),
      throwsArgumentError,
    );
    expect(barrier.isRestoreActive, isFalse);
    expect(await database.customSelect('SELECT 1').get(), isNotEmpty);
  });

  test('failed operation releases lease and consistent WAL snapshot reads back', () async {
    await expectLater(
      barrier.runShared<void>(() async => throw StateError('probe failure')),
      throwsStateError,
    );
    await database.customStatement('PRAGMA journal_mode=WAL');
    await database.customStatement('INSERT INTO barrier_probe VALUES (9)');
    final backupService = DatabaseBackupService(
      getApplicationDirectory: () async => temporaryDirectory,
      databaseName: 'source.sqlite',
      isTestMode: true,
    );

    final snapshot = await barrier.runExclusive(
      () => backupService.createConsistentSnapshot(
        writeSnapshot: (destinationPath) => database.customStatement(
          "VACUUM INTO '${destinationPath.replaceAll("'", "''")}'",
        ),
      ),
    );
    final snapshotDatabase = AppDatabase.withExecutor(
      NativeDatabase(snapshot),
      restoreBarrier: McpRestoreBarrier(),
    );
    addTearDown(snapshotDatabase.close);

    final row = await snapshotDatabase.customSelect('SELECT value FROM barrier_probe').getSingle();
    expect(row.read<int>('value'), 9);
    expect(await snapshot.length(), greaterThan(0));
  });

  test('failed snapshot is removed and error propagates', () async {
    final backupService = DatabaseBackupService(
      getApplicationDirectory: () async => temporaryDirectory,
      databaseName: 'source.sqlite',
      isTestMode: true,
    );

    await expectLater(
      backupService.createConsistentSnapshot(
        writeSnapshot: (destinationPath) async {
          await File(destinationPath).writeAsString('not sqlite');
          throw StateError('snapshot failure');
        },
      ),
      throwsStateError,
    );
    final restoreDirectory = Directory(p.join(temporaryDirectory.path, 'backups', 'restore'));
    expect(await restoreDirectory.list().isEmpty, isTrue);
  });

  test('ensureOpen failure does not leave a shared lease', () async {
    final failingBarrier = McpRestoreBarrier();
    final failingDatabase = AppDatabase.withExecutor(
      _FailingOpenExecutor(),
      restoreBarrier: failingBarrier,
    );
    addTearDown(failingDatabase.close);

    await expectLater(
      failingDatabase.customSelect('SELECT 1').get(),
      throwsStateError,
    );
    await failingBarrier.runExclusive(() async {});
    expect(failingBarrier.isRestoreActive, isFalse);
  });

  test('manual lease reentry admits callback work and expires with the lease', () async {
    final lease = barrier.acquireShared();
    final restoreEntered = Completer<void>();
    final releaseRestore = Completer<void>();
    final restore = barrier.runExclusive(() async {
      restoreEntered.complete();
      await releaseRestore.future;
    });

    expect(barrier.isRestoreActive, isTrue);
    expect(await lease.run(() => database.customSelect('SELECT 1').get()), isNotEmpty);
    expect(restoreEntered.isCompleted, isFalse);

    lease.release();
    await restoreEntered.future;
    await expectLater(
      lease.run(() => database.customSelect('SELECT 1').get()),
      throwsStateError,
    );
    releaseRestore.complete();
    await restore;
  });

  test('inherited lease reenters an admitted parent from a detached callback', () async {
    final parentEntered = Completer<void>();
    final runCallback = Completer<void>();
    final callbackFinished = Completer<void>();
    late RestoreBarrierLease inheritedLease;
    final parent = barrier.runShared(() async {
      inheritedLease = barrier.acquireShared();
      parentEntered.complete();
      await runCallback.future;
      await inheritedLease.run(() => database.customSelect('SELECT 1').get());
      callbackFinished.complete();
    });
    await parentEntered.future;

    final restoreEntered = Completer<void>();
    final restore = barrier.runExclusive(() async => restoreEntered.complete());
    runCallback.complete();
    await callbackFinished.future;
    expect(restoreEntered.isCompleted, isFalse);

    await parent;
    await restore;
    expect(inheritedLease.isActive, isFalse);
    await expectLater(
      inheritedLease.run(() => database.customSelect('SELECT 1').get()),
      throwsStateError,
    );
  });
}

class _FailingOpenExecutor extends QueryExecutor {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => Future<bool>.error(StateError('open failure'));

  @override
  QueryExecutor beginExclusive() => this;

  @override
  TransactionExecutor beginTransaction() => throw StateError('not opened');

  @override
  Future<void> runBatched(BatchedStatements statements) => Future<void>.error(StateError('not opened'));

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) => Future<void>.error(StateError('not opened'));

  @override
  Future<int> runDelete(String statement, List<Object?> args) => Future<int>.error(StateError('not opened'));

  @override
  Future<int> runInsert(String statement, List<Object?> args) => Future<int>.error(StateError('not opened'));

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) =>
      Future<List<Map<String, Object?>>>.error(StateError('not opened'));

  @override
  Future<int> runUpdate(String statement, List<Object?> args) => Future<int>.error(StateError('not opened'));
}
