// T21 acceptance 6 and 7: replace-import as `local_reset` (D14, U4) through the
// real import handler over real Drift repositories and the membership service,
// with store-level pulls between two paired devices (the session engine over
// the Drift store is T22).
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../../../infrastructure/persistence/sync/local_reset_test_support.dart';
import '../../../../infrastructure/persistence/sync/restore_test_support.dart';
import '../../../../infrastructure/shared/features/sync/sync_security_test_support.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory scratch;
  late SecurityDevice a;
  late SecurityDevice b;

  setUp(() async {
    initializeJsonMapper();
    scratch = await Directory.systemTemp.createTemp('t21_import_');
    a = await SecurityDevice.open('a', scratch);
    b = await SecurityDevice.open('b', scratch);
    await pairDevices(a, b);
  });

  tearDown(() async {
    await a.database.close();
    await b.database.close();
    await scratch.delete(recursive: true);
  });

  Future<String> titleOf(SecurityDevice device, String id) async =>
      (await device.database.note(id))['title'] as String;

  /// Clock rows of user tables whose pk has no base row.
  Future<int> orphanUserClockRows(SecurityDevice device) =>
      device.database.count('''
SELECT COUNT(*) FROM sync_clock c JOIN sync_row r ON r.id = c.key / 256
WHERE r.tbl_id < $securityTblIdFloor AND NOT EXISTS (
  SELECT 1 FROM note_table n WHERE r.pk = n.id)
''');

  test('6: re-importing an older export converges to it on both devices',
      () async {
    await a.database.insertNote('k', 'v1');
    await exchange([a, b]);
    final exportOfV1 = exportOfNotes({'k': 'v1'});
    await b.database.setTitle('k', 'v2');
    await exchange([a, b]);
    expect(await titleOf(a, 'k'), 'v2');
    final hlcBeforeImport = await a.database.count(
        'SELECT MAX(hlc) FROM sync_clock c JOIN sync_row r ON r.id = c.key / 256 '
        'WHERE r.tbl_id < $securityTblIdFloor');

    await a.replaceImport(exportOfV1);
    expect(await titleOf(a, 'k'), 'v1');
    await exchange([a, b]);

    expect(await titleOf(a, 'k'), 'v1');
    expect(await titleOf(b, 'k'), 'v1');
    expect(await a.database.content(), await b.database.content());
    expect(
        await a.database.count(
            'SELECT COUNT(*) FROM sync_clock c JOIN sync_row r ON r.id = c.key / 256 '
            'WHERE r.tbl_id < $securityTblIdFloor AND c.hlc <= $hlcBeforeImport'),
        0,
        reason:
            'every user clock row carries an HLC above the pre-import ones');
    expect(await orphanUserClockRows(a), 0);
    expect(await orphanUserClockRows(b), 0);
  });

  test('7: items absent from the import return from peers; nothing is deleted',
      () async {
    await a.database.insertNote('k', 'shared');
    await a.database.insertNote('l', 'authored on a, synced');
    await b.database.insertNote('m', 'only on b');
    await exchange([a, b]);
    final oldOrigin = await a.currentOrigin();
    final importFile = exportOfNotes({'k': 'shared', 'n': 'imported'});

    await a.replaceImport(importFile);

    expect(await a.currentOrigin(), isNot(oldOrigin));
    expect(await a.noteIds(), {'k', 'n'}, reason: 'truncated, then imported');
    expect(
        await a.database.count(
            'SELECT COUNT(*) FROM note_table WHERE deleted_date IS NOT NULL'),
        0);
    expect(
        await a.database.count(
            'SELECT COUNT(*) FROM sync_clock WHERE tomb_value IS NOT NULL'),
        0,
        reason: 'the import created 0 tombstones');
    expect(await a.database.count('SELECT COUNT(*) FROM sync_vector'), 0,
        reason: 'the vector is cleared so peers resend everything');

    await exchange([a, b]);

    for (final device in [a, b]) {
      expect(await device.noteIds(), {'k', 'l', 'm', 'n'}, reason: device.name);
    }
    expect(
        await b.database.count(
            'SELECT COUNT(*) FROM note_table WHERE deleted_date IS NOT NULL'),
        0);
    expect(await a.database.content(), await b.database.content());
  });

  test('a ledger entry is committed for the new origin and is not left pending',
      () async {
    await a.database.insertNote('k', 'v1');

    await a.replaceImport(exportOfNotes({'k': 'v1'}));

    final latest = a.keyStore.latest!;
    expect(latest.state, OriginEntryState.committed);
    expect(latest.reason, OriginSwitchReason.localReset);
    expect(latest.origin.hex, await a.currentOrigin());
  });

  test('a failed import rolls back the DB and drops the pending ledger entry',
      () async {
    await a.database.insertNote('k', 'v1');
    final before = await a.database.content();
    final origin = await a.currentOrigin();
    final entries = a.keyStore.entries.length;
    final broken =
        exportOfNotes({'k': 'v1'}).replaceFirst('"notes":', '"notes":[1],"x":');

    await expectLater(a.replaceImport(broken), throwsA(anything));

    expect(await a.database.content(), before);
    expect(await a.currentOrigin(), origin);
    expect(a.keyStore.entries, hasLength(entries));
  });
}
