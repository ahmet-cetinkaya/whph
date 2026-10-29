// T19 acceptance 1: session-end diagnostics and unreferenced-manifest cleanup.
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_diagnostics_service.dart';

import '../../../../../infrastructure/persistence/sync/drift_sync_test_support.dart';

const String _secretTitle = 'secret-title-value';
const String _noteTable = 'note_table';
const int _referencedByClock = manifestedMarker;
const int _referencedByHeldCell = 8;
const int _unreferenced = 9;

void main() {
  late SyncTestDevice a;
  late SyncTestDevice b;
  late List<String> logLines;

  DriftSyncDiagnosticsService diagnosticsOf(SyncTestDevice device) =>
      DriftSyncDiagnosticsService(device.db, log: logLines.add);

  setUp(() async {
    a = await SyncTestDevice.open('a');
    b = await SyncTestDevice.open('b');
    logLines = [];
    addTearDown(a.close);
    addTearDown(b.close);
  });

  group('session-end log', () {
    test('records the staged-row count', () async {
      final c = await SyncTestDevice.open('c');
      addTearDown(c.close);
      await a.insertNote('r', 'created');
      await pullChanges(a, b);
      await b.forceHlcAhead();
      await b.setTitle('r', 'edited by b');
      await pullChanges(b, c, onlyOrigins: {'origin-b'});

      final report = await diagnosticsOf(c).logSessionEnd();

      expect(report.stagedRowCount, 1);
      expect(logLines, ['sync session end: staged_rows=1']);
    });

    test('converged devices report equal hashes and no mismatch', () async {
      await a.insertNote('n1', 'one');
      await b.insertNote('n2', 'two');
      await syncAllDevices([a, b]);

      final local = await diagnosticsOf(a).collect(includeContentHash: true);
      final peer = await diagnosticsOf(b).collect(includeContentHash: true);
      final report = await diagnosticsOf(a).logSessionEnd(
          includeContentHash: true, peerTableHashes: peer.tableHashes);

      expect(local.tableHashes, peer.tableHashes);
      expect(report.divergentTables, isEmpty);
      expect(logLines.where((l) => l.contains('divergence')), isEmpty);
    });

    test('an injected divergence logs the table category, never values',
        () async {
      await a.insertNote('n1', 'one');
      await syncAllDevices([a, b]);
      await b.sql(
          "UPDATE $_noteTable SET title = '$_secretTitle' WHERE id = 'n1'");

      final peer = await diagnosticsOf(b).collect(includeContentHash: true);
      final report = await diagnosticsOf(a).logSessionEnd(
          includeContentHash: true, peerTableHashes: peer.tableHashes);

      expect(report.divergentTables, [_noteTable]);
      expect(
          logLines, contains('sync content divergence: category=$_noteTable'));
      expect(logLines.join('\n'), isNot(contains(_secretTitle)));
      expect(logLines.join('\n'), isNot(contains('one')));
    });

    test('staged cells are part of the hash', () async {
      final c = await SyncTestDevice.open('c');
      addTearDown(c.close);
      await a.insertNote('r', 'created');
      await pullChanges(a, b);
      await b.forceHlcAhead();
      await b.setTitle('r', 'edited by b');
      final before = await diagnosticsOf(c).collect(includeContentHash: true);

      await pullChanges(b, c, onlyOrigins: {'origin-b'});
      final after = await diagnosticsOf(c).collect(includeContentHash: true);

      expect(after.tableHashes![_noteTable],
          isNot(before.tableHashes![_noteTable]));
    });
  });

  group('unreferenced manifest cleanup (D7)', () {
    Future<void> insertManifest(int manifestId) => a.sql(
        "INSERT INTO sync_origin_batch (manifest_id, origin_id, from_seq, to_seq, hashes, sig) VALUES ($manifestId, 'origin-a', 0, 1, x'00', 'sig')");

    test('deletes only manifests no clock row or held cell references',
        () async {
      await a.insertNote('n1', 'one');
      await a.sql(
          'UPDATE sync_clock SET manifest_id = $_referencedByClock WHERE origin_seq = 1');
      await a.sql(
          "INSERT INTO sync_held_cell (tbl, pk, col, kind, value, hlc, node, origin_id, origin_seq, manifest_id) VALUES ('$_noteTable', 'x', 'title', 'unknown', NULL, 1, 'n', 'origin-z', 1, $_referencedByHeldCell)");
      for (final id in [
        _referencedByClock,
        _referencedByHeldCell,
        _unreferenced
      ]) {
        await insertManifest(id);
      }

      final deleted = await diagnosticsOf(a).deleteUnreferencedManifests();

      expect(deleted, 1);
      expect(
          (await a.rows(
                  'SELECT manifest_id FROM sync_origin_batch ORDER BY manifest_id'))
              .map((r) => r['manifest_id']),
          [_referencedByClock, _referencedByHeldCell]);
    });
  });
}
