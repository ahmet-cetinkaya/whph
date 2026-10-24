// T19 acceptance 2: restore counterexamples at store level (U10: no GC).
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../../../../infrastructure/persistence/sync/drift_sync_test_support.dart';

const String _faultTrigger = 'inject_apply_fault';
const String _faultyTitle = 'boom';

void main() {
  late Directory snapshotDirectory;
  late SyncTestDevice a;
  late SyncTestDevice p;
  late SyncTestDevice q;

  setUp(() async {
    snapshotDirectory = await Directory.systemTemp.createTemp('t19_');
    a = await SyncTestDevice.open('a');
    p = await SyncTestDevice.open('p');
    q = await SyncTestDevice.open('q');
    addTearDown(() async {
      await a.close();
      await p.close();
      await q.close();
      await snapshotDirectory.delete(recursive: true);
    });
  });

  Future<String> takeSnapshot(SyncTestDevice device, String name) async {
    final path = '${snapshotDirectory.path}/$name.sqlite';
    await device.sql("VACUUM INTO '$path'");
    return path;
  }

  /// Replaces [current] by the database file at [path], as a backup restore
  /// does, and switches to [newOrigin] (D14 `restore`).
  Future<SyncTestDevice> restoreFrom(
      SyncTestDevice current, String path, String newOrigin,
      {int? sentMark}) async {
    await current.close();
    final restored = SyncTestDevice(
        current.name, AppDatabase.withExecutor(NativeDatabase(File(path))),
        origin: newOrigin);
    await restored.store.switchOrigin(OriginSwitchReason.restore,
        newOrigin: newOrigin, sentMark: sentMark);
    expect(await SyncUpgradeJob(restored.db).runChunks(), isTrue);
    return restored;
  }

  test('2a: a cell lost on P survives a restore of A and reaches P and Q',
      () async {
    await p.sql(
        "CREATE TRIGGER $_faultTrigger BEFORE INSERT ON note_table WHEN NEW.title = '$_faultyTitle' "
        "BEGIN SELECT RAISE(ABORT, 'injected'); END");
    await a.insertNote('w', _faultyTitle);
    final snapshot = await takeSnapshot(a, 'holding_w');
    await pullChanges(a, p);

    final cursorOfP = (await p.store.readVector())[a.origin];
    expect(cursorOfP, (await a.store.readVector())[a.origin]);
    expect(await p.count("SELECT COUNT(*) FROM note_table WHERE id = 'w'"), 0);
    expect(await p.store.refetchKeys(), isNotEmpty);

    await a.insertNote('later', 'after the snapshot');
    a = await restoreFrom(a, snapshot, 'origin-a2');
    await p.sql('DROP TRIGGER $_faultTrigger');
    await syncAllDevices([a, p, q]);

    for (final device in [a, p, q]) {
      expect(
          await device.count("SELECT COUNT(*) FROM note_table WHERE id = 'w'"),
          1,
          reason: device.name);
    }
    expect(await p.store.refetchKeys(), isEmpty);
    expect(await p.content(), await a.content());
    expect(await q.content(), await a.content());
  });

  test('2b: a never-sent cell survives a replace-import and a backup restore',
      () async {
    await a.insertNote('base', 'sent before');
    await syncAllDevices([a, p, q]);
    final sentMark = (await a.store.readVector())[a.origin]!;
    await a.sql(
        'UPDATE sync_clock SET manifest_id = $manifestedMarker WHERE origin_seq <= $sentMark');

    await a.insertNote('u', 'created above the sent mark');
    final backup = await takeSnapshot(a, 'pre_import');

    await a.store.localReset(
        newOrigin: 'origin-a2',
        importRows: () => a.insertNote('imported', 'from the file'));
    expect(await a.count("SELECT COUNT(*) FROM note_table WHERE id = 'u'"), 0);
    await syncAllDevices([a, p, q]);
    expect(await p.count("SELECT COUNT(*) FROM note_table WHERE id = 'u'"), 0);

    a = await restoreFrom(a, backup, 'origin-a3', sentMark: sentMark);
    await syncAllDevices([a, p, q]);

    for (final device in [a, p, q]) {
      expect(
          await device.count("SELECT COUNT(*) FROM note_table WHERE id = 'u'"),
          1,
          reason: device.name);
    }
    expect(await p.content(), await a.content());
    expect(await q.content(), await a.content());
  });
}
