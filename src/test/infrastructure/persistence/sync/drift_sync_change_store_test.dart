// T18 acceptance: the Drift change store (read, apply, switch_origin,
// local_reset, reauthor) on real AppDatabase.forTesting() devices.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_repository.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_cascade_service.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'drift_sync_test_support.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestDevice a;
  late SyncTestDevice b;

  setUp(() async {
    a = await SyncTestDevice.open('a');
    b = await SyncTestDevice.open('b');
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  group('apply', () {
    test('keeps remote hlc and origin, adds no own cell (acc 1)', () async {
      await a.insertNote('n1', 'one');
      await pullChanges(a, b);

      expect((await b.note('n1'))['title'], 'one');
      final foreign = await b.rows(
          'SELECT c.hlc AS hlc, o.value AS origin FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id');
      final aClock = await a.rows('SELECT hlc FROM sync_clock');
      expect({for (final r in foreign) r['hlc']},
          {for (final r in aClock) r['hlc']});
      expect({for (final r in foreign) r['origin']}, {'origin-a'});
      expect(
          (await b.rows("SELECT next_seq FROM sync_state")).single['next_seq'],
          1);
      expect(
          await b.count(
              "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = 'origin-b'"),
          0);
    });

    test(
        'bumps modified_date; updateIfRevision honors the new revision (acc 2)',
        () async {
      await a.insertNote('n1', 'one');
      await pullChanges(a, b);
      final repository = DriftNoteRepository.withDatabase(b.db);
      final before = (await repository.getById('n1'))!;
      final preApplyRevision = before.modifiedDate ?? before.createdDate;

      await a.setTitle('n1', 'two');
      await pullChanges(a, b);

      final after = (await repository.getById('n1'))!;
      expect(after.title, 'two');
      expect(after.modifiedDate!.isAfter(preApplyRevision), isTrue);
      expect(
          await repository.updateIfRevision(
              Note(id: 'n1', createdDate: before.createdDate, title: 'stale'),
              preApplyRevision),
          isNull);
      expect(
          await repository.updateIfRevision(
              Note(id: 'n1', createdDate: before.createdDate, title: 'fresh'),
              after.modifiedDate!),
          isNotNull);
    });

    test(
        'one failing item rolls back alone, is recorded, cursor advances (acc 3)',
        () async {
      await b.sql(
          "CREATE TRIGGER inject_failure BEFORE INSERT ON note_table WHEN NEW.title = 'boom' "
          "BEGIN SELECT RAISE(ABORT, 'injected'); END");
      await a.insertNote('bad', 'boom');
      await a.insertNote('good', 'fine');

      await pullChanges(a, b);

      expect((await b.note('good'))['title'], 'fine');
      expect(
          await b.count("SELECT COUNT(*) FROM note_table WHERE id = 'bad'"), 0);
      final held =
          await b.rows('SELECT reason, fail_count FROM sync_held_envelope');
      expect(held.single['reason'], 'apply_failed');
      expect((await b.store.readVector())['origin-a'],
          (await a.store.readVector())['origin-a']);
    });

    test('applying the same batch twice leaves identical content (acc 4)',
        () async {
      await a.insertNote('n1', 'one');
      await a.setTitle('n1', 'two');
      final batch = await a.store.readChanges('origin-a', afterSeq: 0);

      await b.store.applyBatch(batch);
      final once = await b.content();
      final second = await b.store.applyBatch(batch);

      expect(await b.content(), once);
      expect(second.applied, 0);
    });

    test('a stale version after a tombstone changes nothing (acc 5)', () async {
      await a.insertNote('n1', 'one');
      await pullChanges(a, b);
      final base = DateTime.now().millisecondsSinceEpoch;
      await b.store.applyBatch(
          ChangeBatch(origin: 'origin-x', fromSeq: 0, toSeq: 2, cells: [
        testCell('note_table', 'n1', '~', 500,
            clock: hlcAt(base + 20000), seq: 2),
      ]));
      final before = await b.note('n1');

      await b.store.applyBatch(
          ChangeBatch(origin: 'origin-y', fromSeq: 0, toSeq: 1, cells: [
        testCell('note_table', 'n1', 'title', 'stale',
            clock: hlcAt(base - 20000), origin: 'origin-y'),
      ]));

      expect(await b.note('n1'), before);
    });

    test('an unknown column is stored and re-emitted identically (acc 6)',
        () async {
      final base = DateTime.now().millisecondsSinceEpoch;
      final future = testCell('note_table', 'n9', 'future_col', 'v4-value',
          clock: hlcAt(base), node: 'node-v3', origin: 'origin-v3', seq: 1);

      final report = await b.store.applyBatch(ChangeBatch(
          origin: 'origin-v3', fromSeq: 0, toSeq: 1, cells: [future]));
      final reEmitted = await b.store.readChanges('origin-v3', afterSeq: 0);

      expect(report.held, 1);
      expect(reEmitted.cells.single.toString(), future.toString());
      expect(reEmitted.toSeq, 1);
    });

    test(
        'a cell for an unseen row is staged until the row is complete (acc 12)',
        () async {
      final c = await SyncTestDevice.open('c');
      addTearDown(c.close);
      await a.insertNote('r', 'created');
      await pullChanges(a, b);
      await b.forceHlcAhead();
      await b.setTitle('r', 'edited by b');

      await pullChanges(b, c, onlyOrigins: {'origin-b'});

      expect(
          await c.count("SELECT COUNT(*) FROM note_table WHERE id = 'r'"), 0);
      expect(await c.count('SELECT COUNT(*) FROM sync_held_envelope'), 0);
      expect(
          await c.count(
              "SELECT COUNT(*) FROM sync_held_cell WHERE kind = 'staged'"),
          1);

      await syncAllDevices([a, b, c]);

      expect((await c.note('r'))['title'], 'edited by b');
      expect(
          await c.count(
              "SELECT COUNT(*) FROM sync_held_cell WHERE kind = 'staged'"),
          0);
      expect(await a.content(), await c.content());
      expect(await b.content(), await c.content());
    });
  });

  group('cascade (D5b)', () {
    Future<void> seedTaskTree(SyncTestDevice device) async {
      await device.sql(
          "INSERT INTO task_table (id, created_date, title) VALUES ('P', 1, 'parent')");
      await device.sql(
          "INSERT INTO task_table (id, created_date, title, parent_task_id) VALUES ('c1', 1, 'c1', 'P')");
      await device.sql(
          "INSERT INTO task_table (id, created_date, title, parent_task_id) VALUES ('c2', 1, 'c2', 'P')");
      await device.sql(
          "INSERT INTO task_table (id, created_date, title, parent_task_id) VALUES ('c3', 1, 'c3', 'P')");
      await device.sql(
          "INSERT INTO task_tag_table (id, created_date, task_id, tag_id) VALUES ('tt', 1, 'P', 'g')");
    }

    test('a later edit revives the cascade; independent deletes stay (acc 9)',
        () async {
      await seedTaskTree(a);
      await pullChanges(a, b);
      await a.sql("UPDATE task_table SET deleted_date = 90 WHERE id = 'c3'");
      await DriftSyncCascadeService(a.db).withCause('task_table', 'P',
          () async {
        await a.sql("UPDATE task_table SET deleted_date = 100 WHERE id = 'P'");
        await a.sql(
            "UPDATE task_table SET deleted_date = 100 WHERE id IN ('c1', 'c2')");
        await a.sql(
            "UPDATE task_tag_table SET deleted_date = 100 WHERE id = 'tt'");
      });
      await b.forceHlcAhead();
      await b
          .sql("UPDATE task_table SET title = 'edited later' WHERE id = 'P'");

      await syncAllDevices([a, b]);

      for (final device in [a, b]) {
        final deleted = await device.rows(
            "SELECT id, deleted_date FROM task_table WHERE id IN ('P','c1','c2','c3') ORDER BY id");
        expect({for (final r in deleted) r['id']: r['deleted_date']},
            {'P': null, 'c1': null, 'c2': null, 'c3': 90});
        expect(
            await device.count(
                "SELECT COUNT(*) FROM task_tag_table WHERE deleted_date IS NOT NULL"),
            0);
        final tomb =
            await device.store.readChanges('origin-a', afterSeq: 0, limit: 500);
        final children = tomb.cells.where(
            (c) => c.key.isExistence && c.key.pk == 'c1' && c.value != null);
        expect(children.single.cause, const RowRef('task_table', 'P'));
      }
      expect(await a.content(), await b.content());
    });

    test('a child tombstone follows its cause (acc 13)', () async {
      await seedTaskTree(a);
      await pullChanges(a, b);
      final base = DateTime.now().millisecondsSinceEpoch + 5 * farFutureMs;
      const cause = RowRef('task_table', 'P');
      final before =
          await b.rows("SELECT modified_date FROM task_table WHERE id = 'c1'");

      await b.store.applyBatch(
          ChangeBatch(origin: 'origin-x', fromSeq: 0, toSeq: 1, cells: [
        testCell('task_table', 'c1', '~', 700,
            clock: hlcAt(base), seq: 1, cause: cause),
      ]));
      final whileParentAlive = await b.rows(
          "SELECT deleted_date, modified_date FROM task_table WHERE id = 'c1'");
      expect(whileParentAlive.single['deleted_date'], isNull);
      expect(whileParentAlive.single['modified_date'] as int,
          greaterThan(before.single['modified_date'] as int));

      await b.store.applyBatch(
          ChangeBatch(origin: 'origin-x', fromSeq: 1, toSeq: 2, cells: [
        testCell('task_table', 'P', '~', 700,
            clock: hlcAt(base + 1000), seq: 2),
      ]));
      expect(
          (await b.rows("SELECT deleted_date FROM task_table WHERE id = 'c1'"))
              .single['deleted_date'],
          700);
    });
  });

  group('switch_origin (D6b) and reauthor (D17)', () {
    Future<void> seedNotes(SyncTestDevice device, int notes) async {
      for (var i = 0; i < notes; i++) {
        await device.insertNote('n$i', 'title $i');
      }
    }

    Future<List<Map<String, Object?>>> clockSnapshot(
            SyncTestDevice device, String where) =>
        device.rows(
            'SELECT key, hlc, node_id, origin_id, origin_seq, manifest_id, tomb_value FROM sync_clock WHERE $where ORDER BY key');

    test(
        'restore adopts un-manifested cells above the mark, keeps signed ones (acc 8)',
        () async {
      await seedNotes(a, 14);
      const sentMark = 40;
      await a.sql(
          'UPDATE sync_clock SET manifest_id = $manifestedMarker WHERE origin_seq <= $sentMark');
      final signedBefore = await clockSnapshot(a, 'origin_seq <= $sentMark');
      final movedBefore = await a.rows(
          'SELECT key, hlc, node_id FROM sync_clock WHERE origin_seq > $sentMark ORDER BY key');
      final highest = (await a.store.readVector())['origin-a']!;
      expect(highest, greaterThan(sentMark + 10));

      final report = await a.store.switchOrigin(OriginSwitchReason.restore,
          newOrigin: 'origin-a2', sentMark: sentMark);
      expect(report.sealedCursor, sentMark);
      expect(await SyncUpgradeJob(a.db).runChunks(), isTrue);

      expect(
          await clockSnapshot(a,
              'origin_seq <= $sentMark AND origin_id = (SELECT id FROM sync_intern WHERE value = \'origin-a\')'),
          signedBefore);
      final moved = await a.rows(
          "SELECT c.key, c.hlc, c.node_id FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = 'origin-a2' ORDER BY c.key");
      expect(moved, movedBefore);
      expect((await a.store.readVector())['origin-a'], sentMark);
      expect(
          await a.count(
              "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = 'origin-a' AND c.origin_seq > $sentMark"),
          0);

      await a.setTitle('n0', 'after restore');
      expect(
          await a.count(
              "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = 'origin-a2' AND c.origin_seq > ${moved.length}"),
          1);
    });

    test('cells all signed and below the mark adopt nothing (acc 8)', () async {
      await seedNotes(a, 7);
      await a.sql('UPDATE sync_clock SET manifest_id = $manifestedMarker');
      final top = (await a.store.readVector())['origin-a']!;

      await a.store.switchOrigin(OriginSwitchReason.restore,
          newOrigin: 'origin-a2', sentMark: 40);
      await SyncUpgradeJob(a.db).runChunks();

      expect((await a.store.readVector())['origin-a'], top);
      expect(
          await a.count(
              "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = 'origin-a2'"),
          0);
    });

    test(
        'un-manifested cells below the mark are adopted and the cursor stops before them (U11)',
        () async {
      await seedNotes(a, 10);
      await a.sql(
          'UPDATE sync_clock SET manifest_id = $manifestedMarker WHERE origin_seq <= 35');

      final report = await a.store.switchOrigin(OriginSwitchReason.restore,
          newOrigin: 'origin-a2', sentMark: 40);
      await SyncUpgradeJob(a.db).runChunks();

      expect(report.sealedCursor, 35);
      expect(
          await a.count(
              "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = 'origin-a' AND c.origin_seq > 35"),
          0);
      expect(
          await a.count(
              "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = 'origin-a2'"),
          5);
    });

    test('reauthor moves at most 5000 rows per chunk and resumes after a kill',
        () async {
      final chunkRows = <int>[];
      await a.db.transaction(() async {
        for (var i = 0; i < 1300; i++) {
          await a.insertNote('n$i', 't$i');
        }
      });
      final total = await a.count('SELECT COUNT(*) FROM sync_clock');
      await a.store
          .switchOrigin(OriginSwitchReason.groupSwitch, newOrigin: 'origin-a2');
      final job = SyncUpgradeJob(a.db,
          onChunk: (timing) => chunkRows.add(timing.units));

      expect(await job.runChunks(stopAfterChunks: 1), isFalse);
      expect(
          await SyncUpgradeJob(a.db, onChunk: (t) => chunkRows.add(t.units))
              .runChunks(),
          isTrue);

      expect(
          chunkRows
              .where((rows) => rows > SyncUpgradeJob.maxReauthorRowsPerChunk),
          isEmpty);
      expect(chunkRows.first, SyncUpgradeJob.maxReauthorRowsPerChunk);
      expect(
          await a.count(
              "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = 'origin-a2'"),
          total);
      expect(await a.count('SELECT COUNT(DISTINCT origin_seq) FROM sync_clock'),
          total);
      expect(
          (await a.rows('SELECT next_seq, reauthor_spec FROM sync_state'))
              .single,
          {'next_seq': total + 1, 'reauthor_spec': null});
    });

    test(
        'group_switch clears security state and re-authors every user row (acc 10)',
        () async {
      await seedNotes(a, 5);
      await a.sql(
          "INSERT INTO sync_member_table (id, member_id, x25519_pub, ed25519_pub, added_by, created_date) "
          "VALUES ('m1', 'node-a', 'x', 'e', 'node-a', 1)");
      await a.sql(
          "INSERT INTO sync_peer_state_table (member_id, addresses) VALUES ('old-peer', '[]')");
      await a.sql('UPDATE sync_clock SET manifest_id = $manifestedMarker');
      final before = await a.rows(
          'SELECT key, hlc, node_id, tomb_value FROM sync_clock ORDER BY key');

      await a.store
          .switchOrigin(OriginSwitchReason.groupSwitch, newOrigin: 'origin-a2');
      expect(await SyncUpgradeJob(a.db).runChunks(stopAfterChunks: 0), isFalse);
      expect(await SyncUpgradeJob(a.db).runChunks(), isTrue);

      for (final table in [
        'sync_member_table',
        'sync_origin',
        'sync_revocation',
        'sync_epoch_grant',
        'sync_origin_batch',
        'sync_peer_state_table'
      ]) {
        expect(await a.count('SELECT COUNT(*) FROM $table'), 0, reason: table);
      }
      expect(
          await a.rows(
              'SELECT key, hlc, node_id, tomb_value FROM sync_clock ORDER BY key'),
          before);
      expect(
          await a.count(
              "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value != 'origin-a2' OR c.manifest_id IS NOT NULL"),
          0);
      expect(await a.count('SELECT COUNT(*) FROM sync_vector'), 0);
    });

    test('local_reset leaves no pre-reset clock row and no orphan (acc 11)',
        () async {
      await a.insertNote('old', 'old');
      await pullChanges(a, b);
      final preResetHlc =
          (await b.rows('SELECT MAX(hlc) AS top FROM sync_clock')).single['top']
              as int;

      await b.store.localReset(
          newOrigin: 'origin-b2',
          importRows: () => b.insertNote('imported', 'fresh'));

      expect(
          await b.count(
              'SELECT COUNT(*) FROM sync_clock WHERE hlc <= $preResetHlc'),
          0);
      expect(
          await b.count(
              'SELECT COUNT(*) FROM sync_clock c JOIN sync_row r ON r.id = c.key / 256 '
              'WHERE (r.tbl_id = 9 AND NOT EXISTS (SELECT 1 FROM note_table n WHERE n.id = r.pk))'),
          0);
      expect(await b.count('SELECT COUNT(*) FROM sync_vector'), 0);
      expect(
          (await b.rows(
                  'SELECT i.value AS origin FROM sync_state s JOIN sync_intern i ON i.id = s.origin_id'))
              .single['origin'],
          'origin-b2');
      expect(
          await b.count("SELECT COUNT(*) FROM note_table WHERE id = 'old'"), 0);
    });
  });
}
