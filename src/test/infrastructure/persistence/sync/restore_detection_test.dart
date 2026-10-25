// T21 acceptance 2, 3, 8 (startup rules), 10: the D14 startup identity and
// restore check and the sent-seq mark, over a real Drift DB, the file key
// store and the real membership service.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/sync_ledger_mark_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph/infrastructure/shared/features/sync/file_sync_key_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../shared/features/sync/sync_security_test_support.dart';
import 'restore_test_support.dart';

const String _unrelatedOriginHex = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const int _retryCount = 3;
const List<Duration> _expectedRetryDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];

/// A key store whose sent-mark writes fail on demand and are recorded.
class _FlakyKeyStore extends FileSyncKeyStore {
  _FlakyKeyStore(Directory keyDirectory, Directory ledgerDirectory)
      : super(keyDirectory: keyDirectory, ledgerDirectory: ledgerDirectory);

  int failures = 0;
  int watermarkFailures = 0;
  final List<int> attempts = [];
  final List<int> persisted = [];

  @override
  Future<void> persistWrittenWatermark(OriginId origin, int nextSeq, int hlc) {
    if (watermarkFailures > 0) {
      watermarkFailures--;
      throw const SyncLedgerWriteException('injected');
    }
    return super.persistWrittenWatermark(origin, nextSeq, hlc);
  }

  @override
  Future<void> persistSentMark(OriginId origin, int seq, int hlc) async {
    attempts.add(seq);
    if (failures > 0) {
      failures--;
      throw const SyncLedgerWriteException('injected');
    }
    await super.persistSentMark(origin, seq, hlc);
    persisted.add(seq);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory scratch;
  final opened = <SecurityDevice>[];

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('t21_restore_');
  });

  tearDown(() async {
    for (final device in opened) {
      await device.database.close();
    }
    opened.clear();
    await scratch.delete(recursive: true);
  });

  Future<SecurityDevice> openDevice(String name,
      {bool createIdentity = false}) async {
    final device = await SecurityDevice.open(name, scratch,
        createIdentity: createIdentity);
    opened.add(device);
    return device;
  }

  /// The startup check, then the re-author job the app runs after it.
  Future<SyncStartupAction> start(SecurityDevice device,
      {bool databaseCreatedThisLaunch = false}) async {
    final action = await device.startup.run(
        deviceName: device.name,
        databaseCreatedThisLaunch: databaseCreatedThisLaunch);
    await SyncUpgradeJob(device.database.db).runChunks();
    return action;
  }

  Future<int> topSeq(SecurityDevice device) async =>
      (await device.database.store.readVector())[await device.currentOrigin()]!;

  Future<void> author(SecurityDevice device, String id) =>
      device.database.insertNote(id, 'title $id');

  Future<Map<String, Object?>> syncState(SecurityDevice device) async =>
      (await device.database.rows('SELECT * FROM sync_state')).single;

  Future<List<Map<String, Object?>>> clockOf(
          SecurityDevice device, String noteId) =>
      device.database.rows(
          'SELECT i.value AS origin, c.origin_seq AS seq, c.manifest_id AS manifest '
          'FROM sync_clock c JOIN sync_row r ON r.id = c.key / 256 '
          'JOIN sync_intern i ON i.id = c.origin_id '
          "WHERE r.pk = '$noteId' ORDER BY c.origin_seq");

  Future<void> markSent(SecurityDevice device) async {
    expect(
        await device.marks.persistSentMarkBefore(await topSeq(device)), isTrue);
  }

  group('startup check rules (D14)', () {
    test('a device without identity gets a fresh one, unpaired', () async {
      final device = await openDevice('a');
      expect(await start(device), SyncStartupAction.freshIdentity);

      final ledger = device.keyStore.latestCommitted!;
      expect(ledger.origin.hex, await device.currentOrigin());
      expect((await syncState(device))['member_id'], device.memberId);
      expect(await device.service.isPaired(), isFalse);

      await device.restart();
      expect(await start(device), SyncStartupAction.normal);
    });

    test('rule 1: key file present but the DB is new deletes both files',
        () async {
      final device = await openDevice('a', createIdentity: true);
      final staleMember = device.memberId;
      await device.restart();

      expect(await start(device, databaseCreatedThisLaunch: true),
          SyncStartupAction.freshIdentity);

      expect(device.memberId, isNot(staleMember));
      expect((await syncState(device))['member_id'], device.memberId);
      expect(device.keyStore.entries, hasLength(1));
      expect(await device.service.isPaired(), isFalse);
    });

    test('rule 2: a missing key file with a DB identity is key loss', () async {
      final device = await openDevice('a', createIdentity: true);
      await author(device, 'n1');
      final oldMember = device.memberId;
      final oldOrigin = await device.currentOrigin();
      await device.keyStore.keyFile.delete();
      await device.restart();

      expect(await start(device), SyncStartupAction.keyLost);

      expect(device.memberId, isNot(oldMember));
      expect(await device.currentOrigin(), isNot(oldOrigin));
      expect((await device.service.currentView()).state,
          SyncGroupState.needsRepairing);
      expect(await device.hasNote('n1'), isTrue);
      expect(await device.service.isPaired(), isFalse);
    });

    test('rule 2: a DB member id that differs from the key file is key loss',
        () async {
      final device = await openDevice('a', createIdentity: true);
      final beforeLoss = await device.snapshotDatabase('before_loss');
      await device.keyStore.keyFile.delete();
      await device.restart();
      expect(await start(device), SyncStartupAction.keyLost);
      final newMember = device.memberId;

      await device.replaceDatabase(beforeLoss);

      expect(await start(device), SyncStartupAction.keyLost);
      expect(device.memberId, isNot(newMember));
    });

    test('rule 3: a pending entry the DB never adopted is dropped', () async {
      final device = await openDevice('a', createIdentity: true);
      await device.keyStore.append(OriginEntry(
          origin: OriginId.fromHex(_unrelatedOriginHex),
          state: OriginEntryState.pending,
          reason: OriginSwitchReason.restore));
      await device.restart();

      expect(await start(device), SyncStartupAction.normal);

      expect(device.keyStore.entries.map((e) => e.origin.hex),
          [await device.currentOrigin()]);
    });

    test('rule 3: a pending entry the DB adopted is committed, no restore',
        () async {
      final device = await openDevice('a', createIdentity: true);
      await author(device, 'n1');
      await markSent(device);
      await device.keyStore.append(OriginEntry(
          origin: OriginId.fromHex(_unrelatedOriginHex),
          state: OriginEntryState.pending,
          reason: OriginSwitchReason.restore));
      await device.database.store.switchOrigin(OriginSwitchReason.restore,
          newOrigin: _unrelatedOriginHex, sentMark: await topSeq(device));
      await SyncUpgradeJob(device.database.db).runChunks();
      await device.restart();

      expect(await start(device), SyncStartupAction.normal);

      expect(device.keyStore.latestCommitted!.origin.hex, _unrelatedOriginHex);
      expect(device.keyStore.entries, hasLength(2));
    });

    test('rule 4: a missing ledger is treated as a restore, identity kept',
        () async {
      final device = await openDevice('a', createIdentity: true);
      final member = device.memberId;
      final origin = await device.currentOrigin();
      await device.keyStore.ledgerFile.delete();
      await device.restart();

      expect(await start(device), SyncStartupAction.restore);

      expect(device.memberId, member);
      expect(await device.currentOrigin(), isNot(origin));
      expect(device.keyStore.latestCommitted!.origin.hex,
          await device.currentOrigin());
    });

    test('rule 4: a DB that is not the latest committed origin is restored',
        () async {
      final device = await openDevice('a', createIdentity: true);
      final snapshot = await device.snapshotDatabase('older');
      await device.service.switchOrigin(OriginSwitchReason.restore);
      await device.replaceDatabase(snapshot);

      expect(await start(device), SyncStartupAction.restore);
    });

    test('rule 4: an older DB below the sent mark is restored', () async {
      final device = await openDevice('a', createIdentity: true);
      await author(device, 'n1');
      final snapshot = await device.snapshotDatabase('older');
      final heldTop = await topSeq(device);
      await author(device, 'n2');
      await markSent(device);
      final oldOrigin = await device.currentOrigin();
      await device.replaceDatabase(snapshot);

      expect(await start(device), SyncStartupAction.restore);

      final newOrigin = await device.currentOrigin();
      expect(newOrigin, isNot(oldOrigin));
      await author(device, 'n3');
      for (final row in await clockOf(device, 'n3')) {
        expect(row['origin'], newOrigin);
      }
      final vector = await device.database.store.readVector();
      expect(vector[oldOrigin] ?? 0, lessThanOrEqualTo(heldTop),
          reason: 'the old origin gets no new seq');
    });

    test('rule 4: an older DB below the written watermark is restored',
        () async {
      final device = await openDevice('a', createIdentity: true);
      final snapshot = await device.snapshotDatabase('older');
      await author(device, 'unsent');
      expect(await device.marks.flushWrittenWatermark(), isTrue);
      expect(device.keyStore.latestCommitted!.maxSentSeq, 0);
      await device.replaceDatabase(snapshot);

      expect(await start(device), SyncStartupAction.restore);
    });

    test('rule 5: after a normal session and restart nothing is detected',
        () async {
      final device = await openDevice('a', createIdentity: true);
      await author(device, 'n1');
      await markSent(device);
      await author(device, 'n2');
      await device.restart();

      expect(await start(device), SyncStartupAction.normal);
      expect(device.keyStore.entries, hasLength(1));
    });
  });

  group('acceptance 2: Android backup/restore simulation', () {
    test('rows keep origin, seq and manifest; only unsigned cells are adopted',
        () async {
      final a = await openDevice('a', createIdentity: true);
      final b = await openDevice('b', createIdentity: true);
      await pairDevices(a, b);
      for (final id in ['n1', 'n2', 'n3']) {
        await author(a, id);
      }
      await a.signManifests();
      await author(a, 'n4');
      final backup = await a.snapshotDatabase('backup');
      await author(a, 'n5');
      await a.signManifests();
      await markSent(a);
      final oldOrigin = await a.currentOrigin();

      await a.replaceDatabase(backup);
      expect(await start(a), SyncStartupAction.restore);
      await SyncUpgradeJob(a.database.db).runChunks();

      final newOrigin = await a.currentOrigin();
      expect(newOrigin, isNot(oldOrigin));
      for (final id in ['n1', 'n2', 'n3']) {
        for (final row in await clockOf(a, id)) {
          expect(row['origin'], oldOrigin, reason: id);
          expect(row['manifest'], isNotNull, reason: id);
        }
      }
      for (final row in await clockOf(a, 'n4')) {
        expect(row['origin'], newOrigin, reason: 'unsigned cell adopted');
        expect(row['manifest'], isNull);
      }
      expect(await a.service.isPaired(), isTrue);
    });
  });

  group('acceptance 3: backup before pairing, restored after pairing', () {
    test('keeps its identity, trusts peers by anchors, merges all group data',
        () async {
      final a = await openDevice('a', createIdentity: true);
      final b = await openDevice('b', createIdentity: true);
      await author(a, 'old');
      final beforePairing = await a.snapshotDatabase('before_pairing');
      await pairDevices(a, b);
      await author(a, 'after_pairing');
      await author(b, 'from_b');
      await exchange([a, b]);
      await markSent(a);
      final member = a.memberId;
      final group = a.membership.groupId;

      await a.replaceDatabase(beforePairing);
      expect(await start(a), SyncStartupAction.restore);

      expect(a.memberId, member);
      expect(a.membership.groupId, group);
      expect((await syncState(a))['group_id'], group!.hex);
      expect(await handshakeRefused(a, b), isFalse);
      expect(await handshakeRefused(b, a), isFalse);

      await exchange([a, b]);
      for (final id in ['old', 'after_pairing', 'from_b']) {
        expect(await a.hasNote(id), isTrue, reason: id);
        expect(await b.hasNote(id), isTrue, reason: id);
      }
      expect(await a.database.content(), await b.database.content());
    });
  });

  group('acceptance 10: sent-seq mark', () {
    late SecurityDevice device;
    late _FlakyKeyStore flaky;
    late List<Duration> waits;
    late SyncLedgerMarkService marks;

    setUp(() async {
      device = await openDevice('a', createIdentity: true);
      flaky = _FlakyKeyStore(device.keyDirectory, device.ledgerDirectory);
      await flaky.load();
      waits = [];
      marks = SyncLedgerMarkService(
          keyStore: flaky,
          changeStore: device.database.store,
          delay: (d) async => waits.add(d));
      await author(device, 'n1');
      await author(device, 'n2');
    });

    test('is written before a batch above it and never lowered', () async {
      final top = await topSeq(device);

      expect(await marks.persistSentMarkBefore(top - 1), isTrue);
      expect(await marks.persistSentMarkBefore(top), isTrue);
      expect(await marks.persistSentMarkBefore(top - 1), isTrue);

      expect(flaky.persisted, [top - 1, top]);
      expect(flaky.latestCommitted!.maxSentSeq, top);
    });

    test('a failing write is retried 3 times, then reported', () async {
      final top = await topSeq(device);
      flaky.failures = 100;

      expect(await marks.persistSentMarkBefore(top), isFalse);

      expect(flaky.attempts, hasLength(_retryCount + 1));
      expect(waits, _expectedRetryDelays);
      expect(flaky.latestCommitted!.maxSentSeq, 0);

      flaky.failures = 0;
      expect(await marks.persistSentMarkBefore(top), isTrue);
      expect(flaky.latestCommitted!.maxSentSeq, top);
    });

    test('a write that succeeds on the last retry lets the send continue',
        () async {
      final top = await topSeq(device);
      flaky.failures = _retryCount;

      expect(await marks.persistSentMarkBefore(top), isTrue);
      expect(waits, _expectedRetryDelays);
    });

    test('a failed watermark flush is reported and retried on the next flush',
        () async {
      flaky.watermarkFailures = 1;
      expect(await marks.flushWrittenWatermark(), isFalse);
      expect(await marks.flushWrittenWatermark(), isTrue);
      expect(await marks.flushWrittenWatermark(), isFalse,
          reason: 'nothing new to write');
    });
  });
}
