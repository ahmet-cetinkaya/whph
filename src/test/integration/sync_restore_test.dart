// T21 acceptance 1, 4, 5a and 11: restore scenarios across paired devices
// through the app services (startup check, D15 peer-cursor hook, membership
// service) over real Drift stores. The exchanges are store-level pulls (the
// session engine over the Drift store is T22).
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';

import '../infrastructure/persistence/sync/restore_test_support.dart';
import '../infrastructure/shared/features/sync/sync_security_test_support.dart';

const String _faultTrigger = 'inject_apply_fault';
const String _faultyTitle = 'boom';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory scratch;
  final opened = <SecurityDevice>[];

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('t21_integration_');
  });

  tearDown(() async {
    for (final device in opened) {
      await device.database.close();
    }
    opened.clear();
    await scratch.delete(recursive: true);
  });

  Future<SecurityDevice> pairedDevice(
      String name, SecurityDevice? inviter) async {
    final device = await SecurityDevice.open(name, scratch);
    opened.add(device);
    if (inviter != null) await pairDevices(inviter, device);
    return device;
  }

  Future<SyncStartupAction> start(SecurityDevice device) async {
    final action = await device.startup
        .run(deviceName: device.name, databaseCreatedThisLaunch: false);
    await SyncUpgradeJob(device.database.db).runChunks();
    return action;
  }

  Future<void> markSent(SecurityDevice device) async {
    final top = (await device.database.store
        .readVector())[await device.currentOrigin()]!;
    expect(await device.marks.persistSentMarkBefore(top), isTrue);
  }

  Future<void> author(SecurityDevice device, String id,
          [String title = 'title']) =>
      device.database.insertNote(id, '$title $id');

  Future<void> deleteNote(SecurityDevice device, String id) => device.database
      .sql("UPDATE note_table SET deleted_date = 100 WHERE id = '$id'");

  test('1: edits after an older-copy restore reach the peer under a new origin',
      () async {
    final a = await pairedDevice('a', null);
    final p = await pairedDevice('p', a);
    await author(a, 'old1');
    await exchange([a, p]);
    final backup = await a.snapshotDatabase('older');
    final oldOrigin = await a.currentOrigin();
    await author(a, 'old2');
    await exchange([a, p]);
    await markSent(a);
    final seqsOfPeer = (await p.database.store.readVector())[oldOrigin]!;

    await a.replaceDatabase(backup);
    expect(await start(a), SyncStartupAction.restore);
    await author(a, 'fresh');
    await exchange([a, p]);

    final newOrigin = await a.currentOrigin();
    expect(newOrigin, isNot(oldOrigin));
    expect(await p.hasNote('fresh'), isTrue);
    expect(await a.hasNote('old2'), isTrue, reason: 'comes back from the peer');
    expect((await p.database.store.readVector())[oldOrigin], seqsOfPeer,
        reason: 'the old origin got no new seq');
    expect((await a.database.store.readVector())[oldOrigin], seqsOfPeer);
    expect(await a.database.content(), await p.database.content());
  });

  test(
      '4: a restored snapshot is healed by kept tombstones, nothing resurrects',
      () async {
    final a = await pairedDevice('a', null);
    final b = await pairedDevice('b', a);
    final c = await pairedDevice('c', a);
    await exchange([a, b, c]);
    await author(a, 'x');
    await author(a, 'y');
    await exchange([a, b, c]);
    await author(c, 'q');
    await pull(c, a);
    await author(a, 'z');
    final snapshot = await a.snapshotDatabase('snapshot');

    await author(a, 'late');
    await markSent(a);
    await pull(a, b);
    await pull(a, c);
    await deleteNote(b, 'x');
    await exchange([a, b, c]);
    for (final device in [a, b, c]) {
      expect(await device.isNoteDeleted('x'), isTrue, reason: device.name);
    }

    await a.replaceDatabase(snapshot);
    expect(await start(a), SyncStartupAction.restore);
    await exchange([a, b]);
    await exchange([a, c]);

    for (final device in [a, b, c]) {
      expect(await device.isNoteDeleted('x'), isTrue,
          reason: '${device.name}: x stays deleted');
      for (final id in ['y', 'z', 'q', 'late']) {
        expect(await device.hasNote(id), isTrue, reason: '${device.name}: $id');
        expect(await device.isNoteDeleted(id), isFalse);
      }
    }
    await exchange([a, b, c]);
    expect(await b.database.content(), await a.database.content());
    expect(await c.database.content(), await a.database.content());
  });

  test('5a: a cell lost on a peer survives a restore through the app services',
      () async {
    final a = await pairedDevice('a', null);
    final p = await pairedDevice('p', a);
    final q = await pairedDevice('q', a);
    await exchange([a, p, q]);
    await p.database.sql(
        "CREATE TRIGGER $_faultTrigger BEFORE INSERT ON note_table WHEN NEW.title = '$_faultyTitle' "
        "BEGIN SELECT RAISE(ABORT, 'injected'); END");
    await a.database.insertNote('w', _faultyTitle);
    final snapshot = await a.snapshotDatabase('holding_w');
    await pull(a, p);
    expect(await p.hasNote('w'), isFalse);
    expect(await p.database.store.refetchKeys(), isNotEmpty);
    await author(a, 'later');
    await markSent(a);

    await a.replaceDatabase(snapshot);
    expect(await start(a), SyncStartupAction.restore);
    await p.database.sql('DROP TRIGGER $_faultTrigger');
    await exchange([a, p, q]);

    for (final device in [a, p, q]) {
      expect(await device.hasNote('w'), isTrue, reason: device.name);
    }
    expect(await p.database.store.refetchKeys(), isEmpty);
    expect(await p.database.content(), await a.database.content());
    expect(await q.database.content(), await a.database.content());
  });

  test(
      '11: a whole-directory restore is caught by the peer cursor, no edit is lost',
      () async {
    final a = await pairedDevice('a', null);
    final p = await pairedDevice('p', a);
    await author(a, 'e1');
    await a.signManifests();
    await exchange([a, p]);
    await markSent(a);
    final directoryCopy = await a.snapshotEverything('home_snapshot');
    final oldOrigin = await a.currentOrigin();
    for (final id in ['e2', 'e3', 'e4', 'e5', 'e6', 'e7']) {
      await author(a, id);
    }
    await a.signManifests();
    await exchange([a, p]);
    await markSent(a);

    await a.restoreEverything(directoryCopy);
    expect(await start(a), SyncStartupAction.normal,
        reason: 'the three restored files agree with each other');
    await author(a, 'post1');
    await author(a, 'post2');

    final peerVector = await p.database.store.readVector();
    final aborted = await a.startup.switchIfPeerCursorAhead(peerVector);
    expect(aborted, isNotNull, reason: 'the session aborts before sending');
    await SyncUpgradeJob(a.database.db).runChunks();
    expect(await a.currentOrigin(), isNot(oldOrigin));
    expect(await a.startup.switchIfPeerCursorAhead(peerVector), isNull,
        reason: 'the retry no longer trips the check');
    await exchange([a, p]);

    for (final id in [
      'e1',
      'e2',
      'e3',
      'e4',
      'e5',
      'e6',
      'e7',
      'post1',
      'post2'
    ]) {
      expect(await p.hasNote(id), isTrue, reason: 'peer: $id');
      expect(await a.hasNote(id), isTrue, reason: 'restored: $id');
    }
    expect(await p.database.content(), await a.database.content());
  });
}
