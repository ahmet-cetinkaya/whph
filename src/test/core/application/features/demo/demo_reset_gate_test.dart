// T21 acceptance 9: the demo gate (U6). Demo reset, clear and initialization
// refuse on a paired device and run as `local_reset` when unpaired.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/demo/models/demo_reset_blocked_exception.dart';
import 'package:whph/core/application/features/sync/queries/get_is_paired_query.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../../../infrastructure/persistence/sync/local_reset_test_support.dart';
import '../../../../infrastructure/persistence/sync/restore_test_support.dart';
import '../../../../infrastructure/shared/features/sync/sync_security_test_support.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory scratch;
  final opened = <SecurityDevice>[];

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('t21_demo_');
  });

  tearDown(() async {
    for (final device in opened) {
      await device.database.close();
    }
    opened.clear();
    await scratch.delete(recursive: true);
  });

  Future<SecurityDevice> openDevice(String name) async {
    final device = await SecurityDevice.open(name, scratch);
    opened.add(device);
    return device;
  }

  Future<int> tombstones(SecurityDevice device) => device.database.count(
      'SELECT (SELECT COUNT(*) FROM sync_clock WHERE tomb_value IS NOT NULL) '
      '+ (SELECT COUNT(*) FROM tag_table WHERE deleted_date IS NOT NULL) '
      '+ (SELECT COUNT(*) FROM note_table WHERE deleted_date IS NOT NULL)');

  Future<void> expectDemoOperationsBlocked(SecurityDevice device) async {
    await device.database.insertNote('mine', 'my own note');
    final before = await device.database.content();
    final clockBefore =
        await device.database.count('SELECT COUNT(*) FROM sync_clock');
    final demo = device.demoService();

    for (final operation in <Future<void> Function()>[
      demo.resetDemoData,
      demo.clearDemoData,
      demo.initializeDemoDataIfNeeded,
    ]) {
      await expectLater(operation(), throwsA(isA<DemoResetBlockedException>()));
    }

    expect(await device.database.content(), before);
    expect(await device.database.count('SELECT COUNT(*) FROM sync_clock'),
        clockBefore);
  }

  test('paired: all three operations throw and the DB is unchanged', () async {
    final a = await openDevice('a');
    final b = await openDevice('b');
    await pairDevices(a, b);
    expect(await a.service.isPaired(), isTrue);

    await expectDemoOperationsBlocked(a);
  });

  test('the isPaired query answers from the membership service', () async {
    final a = await openDevice('a');
    final b = await openDevice('b');
    final query = GetIsPairedQueryHandler(a.service);
    expect((await query(GetIsPairedQuery())).isPaired, isFalse);

    await pairDevices(a, b);

    expect((await query(GetIsPairedQuery())).isPaired, isTrue);
  });

  test('unpaired: reset proceeds under a new origin with 0 tombstones',
      () async {
    final a = await openDevice('a');
    await a.database.insertNote('mine', 'my own note');
    await a.database.sql(
        "INSERT INTO tag_table (id, created_date, name, type) VALUES ('t1', 1, 'old tag', 0)");
    final origin = await a.currentOrigin();
    expect(await a.service.isPaired(), isFalse);

    await a.demoService().resetDemoData();

    expect(await a.currentOrigin(), isNot(origin));
    expect(await a.hasNote('mine'), isFalse);
    expect(await a.database.count('SELECT COUNT(*) FROM tag_table'),
        greaterThan(0));
    expect(
        await a.database
            .count("SELECT COUNT(*) FROM tag_table WHERE id = 't1'"),
        0);
    expect(await tombstones(a), 0);
    expect(a.keyStore.latest!.reason, OriginSwitchReason.localReset);
    expect(a.keyStore.latest!.state, OriginEntryState.committed);
  });

  test('unpaired: clear proceeds and leaves the tables empty', () async {
    final a = await openDevice('a');
    await a.database.insertNote('mine', 'my own note');

    await a.demoService().clearDemoData();

    expect(await a.database.count('SELECT COUNT(*) FROM note_table'), 0);
    expect(await tombstones(a), 0);
  });

  test('removed from the group: not paired, reset proceeds', () async {
    final a = await openDevice('a');
    final b = await openDevice('b');
    final c = await openDevice('c');
    await pairDevices(a, b);
    await pairDevices(a, c);
    await b.service.removeMember(a.memberId);
    await exchange([b, c]);
    await pull(b, a);
    await a.service.refresh();
    expect(
        (await a.service.currentView()).state, SyncGroupState.removedFromGroup);
    expect(await a.service.isPaired(), isFalse);

    await a.demoService().resetDemoData();

    expect(await tombstones(a), 0);
  });

  test('key-lost: not paired, reset proceeds', () async {
    final a = await openDevice('a');
    final b = await openDevice('b');
    await pairDevices(a, b);
    await a.keyStore.keyFile.delete();
    await a.restart();
    expect(
        await a.startup.run(deviceName: 'a', databaseCreatedThisLaunch: false),
        SyncStartupAction.keyLost);
    expect(await SyncUpgradeJob(a.database.db).runChunks(), isTrue,
        reason: 'the re-author job of the key loss finished');
    expect(await a.service.isPaired(), isFalse);

    await a.demoService().resetDemoData();

    expect(await tombstones(a), 0);
  });
}
