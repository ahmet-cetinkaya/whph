// T20 acceptance 1 (Linux 0600 from the first byte, symlink, crash), 9
// (rename durability, deleteAll, pending survives a crash, torn ledger write
// leaves the key file byte-identical).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_key_store.dart';
import 'package:whph/infrastructure/shared/features/sync/file_sync_key_store.dart';
import 'package:whph/infrastructure/shared/utils/owner_only_file_utils.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

const _ownerFileMode = 0x180; // 0600
const _simulatedCrash = 'simulated crash';

void main() {
  late Directory root;
  late SyncKeyFileContent content;
  late SyncKeyFileContent otherContent;

  setUpAll(() async {
    final ids = SyncIdSource();
    final first = await DeviceIdentity.generate(ids, name: 'first');
    final second = await DeviceIdentity.generate(ids, name: 'second');
    content = SyncKeyFileContent(
        snapshot: Membership(first).snapshotKeyFile(), needsRepairing: false);
    otherContent = SyncKeyFileContent(
        snapshot: Membership(second).snapshotKeyFile(), needsRepairing: true);
  });

  setUp(() async => root = await Directory.systemTemp.createTemp('t20-store-'));
  tearDown(() => root.delete(recursive: true));

  FileSyncKeyStore storeWith(OwnerOnlyAtomicWriter? writer) => FileSyncKeyStore(
        keyDirectory: Directory(p.join(root.path, 'data')),
        ledgerDirectory: Directory(p.join(root.path, 'state')),
        writer: writer,
      );

  OriginEntry pendingOrigin(int fill) => OriginEntry(
        origin:
            OriginId.fromHex(List.filled(32, fill.toRadixString(16)).join()),
        state: OriginEntryState.pending,
        reason: OriginSwitchReason.initial,
      );

  Future<int> modeOf(String path) async =>
      (await FileStat.stat(path)).mode & 0x1ff;

  group('owner-only writes (acc 1)', () {
    test(
        'the temp file is 0600 and still empty before the first byte; final files are 0600',
        () async {
      final observed = <(int, int)>[];
      final store =
          storeWith(OwnerOnlyAtomicWriter(onTemporaryReady: (path) async {
        observed.add((await modeOf(path), await File(path).length()));
      }));

      await store.writeKeyFile(content);
      await store.append(pendingOrigin(1));

      expect(observed, hasLength(2));
      for (final (mode, length) in observed) {
        expect(mode, _ownerFileMode);
        expect(length, 0);
      }
      expect(await modeOf(store.keyFile.path), _ownerFileMode);
      expect(await modeOf(store.ledgerFile.path), _ownerFileMode);
    }, skip: !Platform.isLinux);

    test(
        'a symbolic link at the key file path is rejected and its target untouched',
        () async {
      final store = storeWith(null);
      await store.keyDirectory.create(recursive: true);
      final victim = File(p.join(root.path, 'victim'))
        ..writeAsStringSync('keep');
      await Link(store.keyFile.path).create(victim.path);

      await expectLater(
          store.writeKeyFile(content), throwsA(isA<SyncKeyStoreException>()));
      await expectLater(
          store.readKeyFile(), throwsA(isA<SyncKeyStoreException>()));

      expect(victim.readAsStringSync(), 'keep');
    });

    test(
        'a crash before the rename leaves the original byte-identical and no temp file',
        () async {
      final healthy = storeWith(null);
      await healthy.writeKeyFile(content);
      final original = await healthy.keyFile.readAsBytes();

      final crashing = storeWith(OwnerOnlyAtomicWriter(
          beforeRename: (_) async => throw StateError(_simulatedCrash)));
      await expectLater(crashing.writeKeyFile(otherContent),
          throwsA(isA<SyncKeyStoreException>()));

      expect(await healthy.keyFile.readAsBytes(), original);
      final leftovers = healthy.keyDirectory
          .listSync()
          .map((e) => p.basename(e.path))
          .toList();
      expect(leftovers, [keyFileName]);
    });

    test(
        'a key file with loose permissions is a read error, not a missing file',
        () async {
      final store = storeWith(null);
      await store.writeKeyFile(content);
      expect((await Process.run('chmod', ['644', store.keyFile.path])).exitCode,
          0);

      await expectLater(
          store.readKeyFile(), throwsA(isA<SyncKeyStoreException>()));
    }, skip: !Platform.isLinux);

    test('the key file round-trips', () async {
      final store = storeWith(null);
      await store.writeKeyFile(content);

      final read = (await store.readKeyFile())!;

      expect(read.snapshot.memberId, content.snapshot.memberId);
      expect(read.snapshot.x25519Private, content.snapshot.x25519Private);
      expect(read.needsRepairing, isFalse);
    });
  });

  group('rename durability and deletion (acc 9)', () {
    test('the directory is synced after the rename', () async {
      final events = <String>[];
      final store =
          storeWith(OwnerOnlyAtomicWriter(syncDirectory: (directory) async {
        events
            .add('sync:${await File(p.join(directory, keyFileName)).exists()}');
      }));

      await store.writeKeyFile(content);

      expect(events, ['sync:true'],
          reason: 'the new name exists when the directory is synced');
    });

    test(
        'the libc directory fsync runs on this platform and reports a missing directory',
        () async {
      await syncDirectoryWithPosix(root.path);

      await expectLater(
        syncDirectoryWithPosix(p.join(root.path, 'missing')),
        throwsA(isA<OwnerOnlyFileException>()),
      );
    }, skip: Platform.isWindows);

    test('deleteAll removes the key file, the ledger and any temp file',
        () async {
      final store = storeWith(null);
      await store.writeKeyFile(content);
      await store.append(pendingOrigin(2));
      File('${store.keyFile.path}.1.2.tmp').writeAsStringSync('partial');
      File('${store.ledgerFile.path}.3.4.tmp').writeAsStringSync('partial');

      await store.deleteAll();

      expect(store.keyDirectory.listSync(), isEmpty);
      expect(store.ledgerDirectory.listSync(), isEmpty);
      expect(store.isReadable, isFalse);
    });

    test('a pending origin survives a crash before the commit rename',
        () async {
      final origin = pendingOrigin(3);
      final healthy = storeWith(null);
      await healthy.append(origin);

      final crashing = storeWith(OwnerOnlyAtomicWriter(
          beforeRename: (_) async => throw StateError(_simulatedCrash)));
      await crashing.load();
      await expectLater(crashing.commit(origin.origin),
          throwsA(isA<SyncLedgerWriteException>()));

      final restarted = storeWith(null);
      await restarted.load();
      expect(restarted.entries.single.origin, origin.origin);
      expect(restarted.entries.single.state, OriginEntryState.pending);
    });

    test('a torn ledger write leaves the key file byte-identical', () async {
      final healthy = storeWith(null);
      await healthy.writeKeyFile(content);
      await healthy.append(pendingOrigin(4));
      final keyBytes = await healthy.keyFile.readAsBytes();
      final ledgerBytes = await healthy.ledgerFile.readAsBytes();

      final tearing =
          storeWith(OwnerOnlyAtomicWriter(beforeRename: (temp) async {
        if (temp.contains(ledgerFileName)) throw StateError(_simulatedCrash);
      }));
      await tearing.load();
      await expectLater(tearing.persistEpochCounterHigh(9),
          throwsA(isA<SyncLedgerWriteException>()));

      expect(await healthy.keyFile.readAsBytes(), keyBytes);
      expect(await healthy.ledgerFile.readAsBytes(), ledgerBytes);
      expect(tearing.epochCounterHigh, 0,
          reason: 'a failed write changes nothing in memory');
    });
  });
}
