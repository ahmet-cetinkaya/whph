// T18 acceptance 10 (reauthor half): a stored `reauthor_spec` on a database
// with sync rows and clocks is processed by the production SyncUpgradeJob in
// chunks of at most 5000 rows, resumes from its cursor and reaches `done`.
@Timeout(Duration(minutes: 10))
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_reauthor_spec.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_generator.dart';

import 'drift_sync_test_support.dart';

const int _noteCount = 1300;
const int _sentMark = 100;
const String _newOrigin = 'origin-new';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestDevice device;

  setUp(() async {
    device = await SyncTestDevice.open('a');
  });

  tearDown(() => device.close());

  Future<int> originId(String value) async => (await device.rows(
          'SELECT id FROM sync_intern WHERE kind = $internKindOrigin AND value = ?',
          [Variable(value)]))
      .single['id'] as int;

  Future<int> clocksOn(String origin) => device.count(
      "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = '$origin'");

  test('an adopt spec moves the unsent clock rows in bounded, resumable chunks',
      () async {
    await device.db.transaction(() async {
      for (var i = 0; i < _noteCount; i++) {
        await device.insertNote('n$i', 't$i');
      }
    });
    await device.sql(
        'UPDATE sync_clock SET manifest_id = $manifestedMarker WHERE origin_seq <= $_sentMark');
    final total = await device.count('SELECT COUNT(*) FROM sync_clock');
    final sent = await device
        .count('SELECT COUNT(*) FROM sync_clock WHERE manifest_id IS NOT NULL');
    expect(total - sent, greaterThan(SyncUpgradeJob.maxReauthorRowsPerChunk));

    await device.sql(
        'INSERT INTO sync_intern (kind, value) VALUES ($internKindOrigin, ?)',
        [_newOrigin]);
    final spec = ReauthorSpec.adopt(
        oldOriginId: await originId(device.origin),
        newOriginId: await originId(_newOrigin),
        sentMark: _sentMark);
    await device.sql(
        "UPDATE sync_state SET reauthor_spec = ?, upgrade_phase = 'reauthor', upgrade_cursor = NULL",
        [spec.encode()]);

    final chunkRows = <int>[];
    void record(UpgradeChunkTiming timing) => chunkRows.add(timing.units);

    expect(
        await SyncUpgradeJob(device.db, onChunk: record)
            .runChunks(stopAfterChunks: 1),
        isFalse);
    final midway = await SyncUpgradeJob(device.db).getProgress();
    expect(midway.phase, SyncUpgradePhase.reauthor);
    expect(midway.cursor, isNotNull);
    expect(chunkRows, [SyncUpgradeJob.maxReauthorRowsPerChunk]);

    expect(
        await SyncUpgradeJob(device.db, onChunk: record).runChunks(), isTrue);

    expect(
        chunkRows
            .where((rows) => rows > SyncUpgradeJob.maxReauthorRowsPerChunk),
        isEmpty);
    expect(chunkRows.fold<int>(0, (sum, rows) => sum + rows), total - sent);
    expect(await clocksOn(_newOrigin), total - sent);
    expect(await clocksOn(device.origin), sent);
    expect(
        await device.count(
            'SELECT COUNT(*) FROM sync_clock WHERE origin_id = ${spec.newOriginId} AND manifest_id IS NOT NULL'),
        0);
    expect(
        (await device
                .rows('SELECT reauthor_spec, upgrade_phase FROM sync_state'))
            .single,
        {'reauthor_spec': null, 'upgrade_phase': 'done'});
  });
}
