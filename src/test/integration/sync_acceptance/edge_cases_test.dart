// T27 part 2, edge cases of the spec and plan T27, each on real Drift devices
// through the real session engine (two or three devices, in-memory links with
// fault injection). Every test name starts with its edge-case id (EC-nn).
//
// EC-07 "duplicate merge while editing" is run at runtime on identities that
// two devices create independently (deterministic ids, FR-030/FR-033); the
// upgrade-time merge with edits in between is covered by upgrade_job_test.dart
// (T17 acceptance 8).
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/core/application/features/sync/services/reset_local_data_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_startup_check_service.dart';
import 'package:whph/core/application/shared/utils/sync_identity.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/database_backup_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_cascade_service.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../infrastructure/persistence/sync/local_reset_test_support.dart';
import '../../infrastructure/persistence/sync/restore_test_support.dart';
import '../../infrastructure/shared/features/sync/sync_security_test_support.dart';
import 'support2/data_ops.dart';
import 'support2/lab.dart';
import 'support2/services.dart';

const Duration _pause = Duration(milliseconds: 5);
const int _backlogNotes = 1500;
const int _backlogBatch = 100;
const int _fullDatabaseNotes = 300;
const int _slackPages = 3;
const int _unlimitedPages = 1073741823;
const int _maxCutFrame = 60;
const int _minCutFrame = 6;
final DateTime _hour = DateTime.utc(2026, 3, 2, 10);

Future<void> _wait() => Future<void>.delayed(_pause);

SyncEngineConfig _smallBatches(int size) => SyncEngineConfig(delay: (_) async {}, maxBatchChanges: size);

Future<Lab> _threeDevices(List<String> names, {SyncEngineConfig? config}) async {
  final lab = await Lab.create();
  addTearDown(lab.close);
  final first = await lab.add(names[0], config: config);
  for (final name in names.skip(1)) {
    await lab.add(name, pairWith: first, config: config);
  }
  await lab.converge(rounds: 2);
  return lab;
}

Future<int> _live(LabDevice device, String table) => countRows(device, table, liveOnly: true);

Future<void> _markSent(LabDevice device) async {
  final top = (await device.db.store.readVector())[await device.origin()]!;
  await device.security.persistSentMark(top);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(initializeJsonMapper);

  test('EC-01 empty data: two empty devices sync successfully and change nothing', () async {
    final lab = await _threeDevices(['A', 'B']);
    final [a, b] = lab.devices;
    final before = await contentOf(a);

    for (final pair in [await lab.session(a, b), await lab.session(b, a)]) {
      expect(pair.bothComplete, isTrue, reason: '$pair');
    }

    expect(await contentOf(a), before);
    expect(await contentOf(b), before);
    expect(await _live(a, 'note_table') + await _live(a, 'task_table'), 0);
  });

  test('EC-02 first sync of a new member with existing data: both sides keep everything, one setting', () async {
    final lab = await _threeDevices(['A', 'B']);
    final [a, b] = lab.devices;
    final newcomer = await lab.add('Newcomer');
    final settingId = syncIdentityId(identityKindSetting, ['theme']);
    await insertRow(
        newcomer, 'setting_table', {'id': settingId, 'key': 'theme', 'value': 'from newcomer', 'value_type': 0});
    await addNote(newcomer, 'new-note', 'newcomer note');
    await addTask(newcomer, 'new-task', 'newcomer task');
    await _wait();
    await insertRow(a, 'setting_table', {'id': settingId, 'key': 'theme', 'value': 'from A, later', 'value_type': 0});
    await addNote(a, 'old-note', 'group note');
    await lab.converge(among: [a, b]);

    await pairDevices(a.security, newcomer.security);
    await lab.converge(rounds: 3);

    for (final device in lab.devices) {
      expect(await findRow(device, 'note_table', 'new-note'), isNotNull, reason: device.name);
      expect(await findRow(device, 'task_table', 'new-task'), isNotNull, reason: device.name);
      expect(await findRow(device, 'note_table', 'old-note'), isNotNull, reason: device.name);
      expect(await device.db.count("SELECT COUNT(*) FROM setting_table WHERE key = 'theme'"), 1, reason: device.name);
      expect(await cellOf(device, 'setting_table', settingId, 'value'), 'from A, later');
    }
    expect(await sameContent(lab.devices), isTrue);
  });

  test('EC-03 delete then re-create: one live item with the new data on all devices', () async {
    final lab = await _threeDevices(['A', 'B', 'C']);
    final [a, b, c] = lab.devices;
    final settingId = syncIdentityId(identityKindSetting, ['language']);
    final recordId = syncIdentityId(identityKindHabitRecord, ['h-1', '2026-03-02']);
    await insertRow(a, 'habit_table', {'id': 'h-1', 'name': 'habit', 'description': ''});
    await insertRow(a, 'setting_table', {'id': settingId, 'key': 'language', 'value': 'en', 'value_type': 0});
    await insertRow(
        a, 'habit_record_table', {'id': recordId, 'habit_id': 'h-1', 'occurred_at': 1772445600, 'status': 1});
    await lab.converge();

    await _wait();
    await softDeleteRow(a, 'setting_table', settingId);
    await softDeleteRow(a, 'habit_record_table', recordId);
    await lab.converge();
    for (final device in lab.devices) {
      expect(await _live(device, 'setting_table'), 0, reason: '${device.name}: deleted everywhere first');
    }
    await _wait();
    // The re-creation is the same identity: the row is revived with the new data (upsertRevive).
    await updateRow(b, 'setting_table', settingId, {'deleted_date': null, 'value': 'tr'});
    await updateRow(b, 'habit_record_table', recordId, {'deleted_date': null, 'status': 2});
    await lab.converge();

    for (final device in [a, b, c]) {
      expect(
          await device.db.count("SELECT COUNT(*) FROM setting_table WHERE key = 'language' AND deleted_date IS NULL"),
          1);
      expect(await cellOf(device, 'setting_table', settingId, 'value'), 'tr', reason: device.name);
      expect(await cellOf(device, 'habit_record_table', recordId, 'status'), 2, reason: device.name);
      expect(await cellOf(device, 'habit_record_table', recordId, 'deleted_date'), isNull, reason: device.name);
    }
    expect(await sameContent(lab.devices), isTrue);
  });

  test('EC-04 large backlog across sessions: $_backlogNotes items arrive once each after cut sessions', () async {
    final lab = await _threeDevices(['A', 'B'], config: _smallBatches(_backlogBatch));
    final [a, b] = lab.devices;
    await a.db.sql('''
WITH RECURSIVE counter(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM counter WHERE i < $_backlogNotes)
INSERT INTO note_table (id, created_date, title, content)
SELECT 'bulk-' || i, 1700000000, 'bulk ' || i, hex(randomblob(80)) FROM counter''');

    for (final cutAfter in [12, 30, 70]) {
      final cut = await lab.session(a, b, faults: TransportFaults(cutAfter: cutAfter));
      expect(cut.bothComplete, isFalse, reason: 'cut after $cutAfter frames');
      expect(await countRows(b, 'note_table'), lessThan(_backlogNotes));
    }
    expect((await lab.session(a, b)).bothComplete, isTrue);

    expect(await countRows(b, 'note_table'), _backlogNotes);
    expect(await b.db.count('SELECT COUNT(DISTINCT id) FROM note_table'), _backlogNotes);
    expect(await contentOf(b), await contentOf(a));
    final vector = await b.db.store.readVector();
    expect(vector[await a.origin()], (await a.db.store.readVector())[await a.origin()],
        reason: 'the cursor reached the top');
    await updateRow(b, 'note_table', 'bulk-1', {'title': 'edited on B'});
    expect((await lab.session(a, b)).bothComplete, isTrue);
    expect(await cellOf(a, 'note_table', 'bulk-1', 'title'), 'edited on B');
  });

  test('EC-05 simultaneous start: both devices begin a session at once and still converge', () async {
    final lab = await _threeDevices(['A', 'B']);
    final [a, b] = lab.devices;
    await addNote(a, 'from-a', 'A note');
    await addNote(b, 'from-b', 'B note');

    final both = await Future.wait([lab.session(a, b), lab.session(b, a)]).timeout(const Duration(seconds: 60));

    for (final pair in both) {
      for (final result in [pair.initiator, pair.responder]) {
        final acceptable = result.exchanged || (result is SessionFailed && result.category == SessionFailure.busy);
        expect(acceptable, isTrue, reason: 'only done or busy: $result');
      }
    }
    expect(both.any((pair) => pair.initiator.exchanged || pair.responder.exchanged), isTrue);
    expect((await lab.session(a, b)).bothComplete, isTrue);
    expect((await lab.session(b, a)).bothComplete, isTrue);
    expect(await contentOf(a), await contentOf(b));
    expect(await findRow(a, 'note_table', 'from-b'), isNotNull);
    expect(await findRow(b, 'note_table', 'from-a'), isNotNull);
  });

  test('EC-06 SQLITE_FULL injection: the apply fails, B stays intact, the retry brings all data', () async {
    final lab = await _threeDevices(['A', 'B']);
    final [a, b] = lab.devices;
    await addNote(b, 'b-own', 'B own data');
    await lab.converge(among: [a, b]);
    final bOwnBefore = await findRow(b, 'note_table', 'b-own');
    final pages = await b.db.count('PRAGMA page_count');
    await b.db.sql('PRAGMA max_page_count = ${pages + _slackPages}');
    await a.db.sql('''
WITH RECURSIVE counter(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM counter WHERE i < $_fullDatabaseNotes)
INSERT INTO note_table (id, created_date, title, content)
SELECT 'big-' || i, 1700000000, 'big ' || i, hex(randomblob(1500)) FROM counter''');

    final full = await lab.session(a, b);

    expect(full.bothComplete, isFalse, reason: 'the full disk is reported, not hidden: $full');
    expect(await b.db.rows('PRAGMA integrity_check'), [
      {'integrity_check': 'ok'}
    ]);
    expect(await b.db.count("SELECT apply_mode FROM sync_state WHERE id = 'singleton'"), 0,
        reason: 'capture is back on');
    expect(await findRow(b, 'note_table', 'b-own'), bOwnBefore, reason: 'existing data is intact');

    await b.db.sql('PRAGMA max_page_count = $_unlimitedPages');
    for (var retry = 0; retry < 3; retry++) {
      await lab.session(a, b);
    }
    expect((await lab.session(a, b)).bothComplete, isTrue);
    expect(await countRows(b, 'note_table'),
        _fullDatabaseNotes + 1 + await countRows(a, 'note_table') - _fullDatabaseNotes - 1);
    expect(await contentOf(b), await contentOf(a));
    expect(await b.db.count('SELECT COUNT(DISTINCT id) FROM note_table'), await countRows(b, 'note_table'));
  });

  test('EC-07 duplicate merge while editing: the same identity created twice, edited again mid-sync', () async {
    final lab = await _threeDevices(['A', 'B']);
    final [a, b] = lab.devices;
    final settingId = syncIdentityId(identityKindSetting, ['accent']);
    final recordId = syncIdentityId(identityKindHabitRecord, ['h-dup', '2026-03-02']);
    await insertRow(a, 'habit_table', {'id': 'h-dup', 'name': 'habit', 'description': ''});
    await lab.converge();
    await insertRow(a, 'setting_table', {'id': settingId, 'key': 'accent', 'value': 'A1', 'value_type': 0});
    await insertRow(
        a, 'habit_record_table', {'id': recordId, 'habit_id': 'h-dup', 'occurred_at': 1772445600, 'status': 1});
    await _wait();
    await insertRow(b, 'setting_table', {'id': settingId, 'key': 'accent', 'value': 'B1', 'value_type': 0});
    await insertRow(
        b, 'habit_record_table', {'id': recordId, 'habit_id': 'h-dup', 'occurred_at': 1772445600, 'status': 2});
    await addNote(b, 'busy-b', 'edit in flight');

    final interrupted = await lab.session(a, b, faults: const TransportFaults(cutAfter: 14));
    expect(interrupted.bothComplete, isFalse);
    await _wait();
    await updateRow(a, 'setting_table', settingId, {'value': 'A2 final'});
    await lab.converge();

    for (final device in [a, b]) {
      expect(await device.db.count("SELECT COUNT(*) FROM setting_table WHERE key = 'accent'"), 1, reason: device.name);
      expect(await device.db.count("SELECT COUNT(*) FROM habit_record_table WHERE habit_id = 'h-dup'"), 1);
      expect(await cellOf(device, 'setting_table', settingId, 'value'), 'A2 final', reason: device.name);
    }
    expect(await contentOf(a), await contentOf(b));
  });

  test('EC-08 import-replace with peers: union semantics, then a same-pk re-import converges', () async {
    final lab = await _threeDevices(['A', 'B']);
    final [a, b] = lab.devices;
    await addNote(a, 'n1', 'v1', order: 'n1');
    await addNote(a, 'n2', 'only on peers', order: 'n2');
    await addNote(b, 'n3', 'also on peers', order: 'n3');
    await lab.converge();
    final olderExport = exportOfNotes({'n1': 'v1'});
    await _wait();
    await updateRow(b, 'note_table', 'n1', {'title': 'v2 from B'});
    await lab.converge();

    await importExport(a, exportOfNotes({'n1': 'imported', 'n9': 'new from import'}), ImportStrategy.replace);
    a.rebuild();
    await lab.converge();

    for (final device in [a, b]) {
      expect(await noteTitle(device, 'n1'), 'imported', reason: '${device.name}: the import is a fresh local edit');
      expect(await noteTitle(device, 'n9'), 'new from import');
      expect(await findRow(device, 'note_table', 'n2'), isNotNull, reason: '${device.name}: not deleted group-wide');
      expect(await findRow(device, 'note_table', 'n3'), isNotNull);
    }
    await _wait();
    await importExport(a, olderExport, ImportStrategy.replace);
    a.rebuild();
    await lab.converge();

    expect(await noteTitle(a, 'n1'), 'v1');
    expect(await noteTitle(b, 'n1'), 'v1', reason: 'same pk re-import converges on both');
    expect(await contentOf(a), await contentOf(b));
    expect(await findRow(a, 'note_table', 'n3'), isNotNull);
  });

  test('EC-09 restore of an old snapshot with kept tombstones (3 devices, U10): nothing resurrects', () async {
    final lab = await _threeDevices(['A', 'B', 'C']);
    final [a, b, c] = lab.devices;
    await addNote(a, 'x', 'x note');
    await addNote(a, 'y', 'y note');
    await lab.converge();
    await addNote(c, 'q', 'q note');
    await lab.session(c, a);
    await addNote(a, 'z', 'z note');
    final snapshot = await a.security.snapshotDatabase('snapshot');
    await addNote(a, 'late', 'late note');
    await _markSent(a);
    await lab.session(a, b);
    await lab.session(a, c);
    await softDeleteRow(b, 'note_table', 'x');
    await lab.converge();
    for (final device in lab.devices) {
      expect(await cellOf(device, 'note_table', 'x', 'deleted_date'), isNotNull, reason: device.name);
    }

    await a.security.replaceDatabase(snapshot);
    a.rebuild();
    final action = await a.security.startup.run(deviceName: a.name, databaseCreatedThisLaunch: false);
    await SyncUpgradeJob(a.appDatabase).runChunks();
    expect(action, SyncStartupAction.restore);
    await lab.converge(rounds: 4);

    for (final device in lab.devices) {
      expect(await cellOf(device, 'note_table', 'x', 'deleted_date'), isNotNull,
          reason: '${device.name}: x stays deleted');
      for (final id in ['y', 'z', 'q', 'late']) {
        final row = await findRow(device, 'note_table', id);
        expect(row, isNotNull, reason: '${device.name}: $id');
        expect(row!['deleted_date'], isNull);
      }
    }
    expect(await sameContent(lab.devices), isTrue);
  });

  test('EC-10 relay order that stages a row: an edit arrives before the creation it depends on', () async {
    // Origins are sent in ascending order; 'Bee' sorts before 'Zed', so Bee's edit reaches Cee first.
    final config = _smallBatches(1);
    final lab = await Lab.create();
    addTearDown(lab.close);
    final zed = await lab.add('Zed', config: config);
    final bee = await lab.add('Bee', pairWith: zed, config: config);
    final cee = await lab.add('Cee', pairWith: zed, config: config);
    await lab.converge(rounds: 2);
    await addNote(zed, 'staged', 'created on Zed');
    expect((await lab.session(zed, bee)).bothComplete, isTrue);
    await _wait();
    await updateRow(bee, 'note_table', 'staged', {'title': 'edited on Bee'});

    var observedStaging = false;
    for (var cutAfter = _minCutFrame; cutAfter <= _maxCutFrame && !observedStaging; cutAfter += 2) {
      await lab.session(bee, cee, faults: TransportFaults(cutAfter: cutAfter));
      final staged = await cee.db.count("SELECT COUNT(*) FROM sync_held_cell WHERE kind = 'staged'");
      final visible = await findRow(cee, 'note_table', 'staged');
      observedStaging = staged > 0 && visible == null;
      if (observedStaging) expect(await countRows(cee, 'note_table'), 0, reason: 'no half-built row is visible');
    }
    expect(observedStaging, isTrue, reason: 'a cut session left the edit staged without its row');

    expect((await lab.session(bee, cee)).bothComplete, isTrue);

    expect(await cellOf(cee, 'note_table', 'staged', 'title'), 'edited on Bee');
    expect(await cee.db.count("SELECT COUNT(*) FROM sync_held_cell WHERE kind = 'staged'"), 0);
    await lab.converge();
    expect(await sameContent(lab.devices), isTrue);
  });

  test('EC-11 cascade revival across 3 devices: a later edit revives the cascade, independent deletes stay', () async {
    final lab = await _threeDevices(['A', 'B', 'C']);
    final [a, b, c] = lab.devices;
    await addTask(a, 'P', 'parent');
    for (final child in ['c1', 'c2', 'c3']) {
      await addTask(a, child, child, extra: {'parent_task_id': 'P'});
    }
    await addTag(a, 'tg', 'tag');
    final linkId = joinId(identityKindTaskTag, 'P', 'tg');
    await insertRow(a, 'task_tag_table', {'id': linkId, 'task_id': 'P', 'tag_id': 'tg'});
    await lab.converge();
    await softDeleteRow(a, 'task_table', 'c3', at: 90);
    await DriftSyncCascadeService(a.appDatabase).withCause('task_table', 'P', () async {
      await softDeleteRow(a, 'task_table', 'P', at: 100);
      await a.db.sql("UPDATE task_table SET deleted_date = 100 WHERE id IN ('c1', 'c2')");
      await softDeleteRow(a, 'task_tag_table', linkId, at: 100);
    });
    // C has not seen the cascade yet; its edit is the later action (FR-006).
    await _wait();
    await updateRow(c, 'task_table', 'P', {'title': 'edited later on C'});
    await lab.converge();

    for (final device in [a, b, c]) {
      for (final id in ['P', 'c1', 'c2']) {
        expect(await cellOf(device, 'task_table', id, 'deleted_date'), isNull, reason: '${device.name}: $id');
      }
      expect(await cellOf(device, 'task_table', 'c3', 'deleted_date'), 90, reason: '${device.name}: c3 stays deleted');
      expect(await cellOf(device, 'task_tag_table', linkId, 'deleted_date'), isNull, reason: device.name);
    }
    expect(await sameContent(lab.devices), isTrue);
  });

  test('EC-12 group switch: a device joins another group, needs the confirmation, and leaves the old group', () async {
    final lab = await Lab.create();
    addTearDown(lab.close);
    final a = await lab.add('A');
    final b = await lab.add('B', pairWith: a);
    final d = await lab.add('D');
    final e = await lab.add('E', pairWith: d);
    await lab.converge(among: [a, b]);
    await lab.converge(among: [d, e]);
    await addNote(a, 'in-g1', 'group one');
    await addNote(d, 'in-g2', 'group two');
    await lab.converge(among: [a, b]);
    await lab.converge(among: [d, e]);
    final oldGroup = d.security.membership.groupId;

    await expectLater(pairDevices(a.security, d.security), throwsA(isA<SyncMembershipException>()));
    await pairDevices(a.security, d.security, confirmGroupSwitch: true);
    // The switch re-authors D's cells onto its new origin in the background upgrade job (D14).
    await SyncUpgradeJob(d.appDatabase).runChunks();
    await lab.converge(among: [a, b, d]);

    expect(d.security.membership.groupId, a.security.membership.groupId);
    expect(d.security.membership.groupId, isNot(oldGroup));
    for (final device in [a, b, d]) {
      expect(await findRow(device, 'note_table', 'in-g1'), isNotNull, reason: device.name);
      expect(await findRow(device, 'note_table', 'in-g2'), isNotNull, reason: '${device.name}: the data comes along');
    }
    expect(await sameContent([a, b, d]), isTrue);
    await addNote(d, 'after-switch', 'after the switch');
    final withOldGroup = await lab.session(e, d);
    expect(withOldGroup.exchangedNothing, isTrue, reason: 'the old group no longer syncs with D: $withOldGroup');
    expect(await findRow(e, 'note_table', 'after-switch'), isNull);
  });

  group('EC-13 set-total concurrent with an add: the add is never lost', () {
    test('EC-13 task time: day total set on A while B adds 600 s', () async {
      final lab = await _threeDevices(['A', 'B']);
      final [a, b] = lab.devices;
      await addTask(a, 't', 'task');
      await lab.converge();
      await addTaskTime(b, 't', _hour, 1000);
      await lab.converge();

      await setTaskTimeTotal(a, 't', _hour, 4000);
      await addTaskTime(b, 't', _hour, 600);
      await lab.converge();

      for (final device in [a, b]) {
        expect(await totalDuration(device, 'task_time_record_table', 'task_id', 't'), 4600, reason: device.name);
      }
      expect(await sameContent([a, b]), isTrue);
    });

    test('EC-13 habit time: hour total set on A while B adds 600 s', () async {
      final lab = await _threeDevices(['A', 'B']);
      final [a, b] = lab.devices;
      await insertRow(a, 'habit_table', {'id': 'h', 'name': 'habit', 'description': ''});
      await lab.converge();
      await addHabitTime(b, 'h', _hour, 1000);
      await lab.converge();

      await setHabitTimeTotal(a, 'h', _hour, 4000);
      await addHabitTime(b, 'h', _hour, 600);
      await lab.converge();

      for (final device in [a, b]) {
        expect(await totalDuration(device, 'habit_time_record_table', 'habit_id', 'h'), 4600, reason: device.name);
      }
      expect(await sameContent([a, b]), isTrue);
    });
  });

  test('EC-14 reset database on a paired device: it leaves the group, the former peer refuses it', () async {
    final scratch = await Directory.systemTemp.createTemp('t27b-reset-');
    addTearDown(() => scratch.delete(recursive: true));
    final applicationDirectory = await Directory('${scratch.path}/app').create();
    AppDatabase.backupServiceForTesting = DatabaseBackupService(
      getApplicationDirectory: () async => applicationDirectory,
      databaseName: 'whph.db',
      isTestMode: true,
    );
    addTearDown(() => AppDatabase.backupServiceForTesting = null);
    final lab = await _threeDevices(['A', 'B']);
    final [a, b] = lab.devices;
    await addNote(a, 'kept', 'in the pre-reset backup');
    await lab.converge();
    final formerMember = a.memberId;
    final reset = ResetLocalDataService(
      keyStore: a.security.keyStore,
      createPreResetBackup: () => a.appDatabase.createPreResetBackup(),
      resetDatabase: (backup) => a.appDatabase.resetDatabase(preResetBackup: backup),
    );

    await reset.reset();
    await a.security.openDatabaseFile('${applicationDirectory.path}/debug_whph.db');
    a.rebuild();
    final action = await a.security.startup.run(deviceName: a.name, databaseCreatedThisLaunch: true);

    expect(action, SyncStartupAction.freshIdentity);
    expect(a.memberId, isNot(formerMember));
    expect(await a.security.service.isPaired(), isFalse);
    expect(await countRows(a, 'note_table'), 0, reason: 'a fresh database');
    expect((await lab.session(b, a)).exchangedNothing, isTrue, reason: 'B refuses the new static key');
    expect((await lab.session(a, b)).exchangedNothing, isTrue, reason: 'the reset device is no member');
    expect(await findRow(b, 'note_table', 'kept'), isNotNull, reason: 'the peer keeps its data');
  });
}
