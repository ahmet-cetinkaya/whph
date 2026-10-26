// T27 part 2, user story 4 (different app versions): Scenarios 4.1 to 4.3 and
// SC-008.
//
// SIMULATED. No second release exists in this tree, so "release" here is the
// protocol configuration of a real device: v2 is (version 2, min 2), the newer
// release is (version 3, min 2), and the incompatible newer release is
// (version 3, min 3). A field a newer release adds is simulated by a cell for a
// column no release of this tree knows, written into the newer device's own
// change range (held 'unknown' cell, signed in its manifest like any change).
// What is real: the Drift devices, the membership, the Noise sessions, the
// negotiation, the manifests and the relay. What is not covered: a build with
// different code (see TRACE_part2.md).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_status_store.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import '../../infrastructure/persistence/sync/restore_test_support.dart';
import 'support2/data_ops.dart';
import 'support2/lab.dart';
import 'support2/scenario_set.dart';

const SimulatedRelease _v2 = SimulatedRelease(2, 2);
const SimulatedRelease _v3Min2 = SimulatedRelease(3, 2);
const SimulatedRelease _v3Min3 = SimulatedRelease(3, 3);

const ReleaseMix _equalReleases = ReleaseMix('equal releases (v3 min3 on all)', [_v3Min3, _v3Min3, _v3Min3]);
const ReleaseMix _compatibleDifferent =
    ReleaseMix('compatible different releases (A v3 min2, B v2, C v2)', [_v3Min2, _v2, _v2]);

const String _futureColumn = 'future_field';
const String _futureValue = 'value written by a newer release';
const String _englishSyncLocale = 'lib/presentation/ui/features/sync/assets/locales/en.yaml';
const int _hlcStep = 1;

Future<(Lab, LabDevice, LabDevice)> _pairOf(SimulatedRelease first, SimulatedRelease second) async {
  final lab = await Lab.create();
  final a = await lab.add('A', config: first.config());
  final b = await lab.add('B', pairWith: a, config: second.config());
  return (lab, a, b);
}

/// Writes a cell for a column unknown to this tree into [device]'s own change
/// range, the way a newer release that added the column would have.
Future<Map<String, Object?>> _writeFutureCell(LabDevice device, String noteId) async {
  final state = (await device.db.rows('SELECT next_seq, hlc FROM sync_state')).single;
  final seq = state['next_seq'] as int;
  final hlc = (state['hlc'] as int) + _hlcStep;
  final origin = await device.security.currentOrigin();
  final node =
      (await device.db.rows('SELECT i.value AS value FROM sync_state s JOIN sync_intern i ON i.id = s.node_id'))
          .single['value'];
  final value = ChangeValue.of(_futureValue).encode();
  await device.db.sql(
    "INSERT INTO sync_held_cell (tbl, pk, col, kind, value, hlc, node, origin_id, origin_seq) VALUES (?, ?, ?, 'unknown', ?, ?, ?, ?, ?)",
    ['note_table', noteId, _futureColumn, value, hlc, node, origin, seq],
  );
  await device.db.sql('UPDATE sync_state SET next_seq = next_seq + 1, hlc = ?', [hlc]);
  await device.security.signManifests();
  await device.db.sql(
    "UPDATE sync_held_cell SET manifest_id = (SELECT manifest_id FROM sync_origin_batch WHERE origin_id = ? AND from_seq < ? AND to_seq >= ?) "
    "WHERE kind = 'unknown' AND origin_id = ? AND origin_seq = ?",
    [origin, seq, seq, origin, seq],
  );
  return {'seq': seq, 'hlc': hlc, 'node': node, 'origin': origin};
}

Future<List<Map<String, Object?>>> _unknownCells(LabDevice device) => device.db
    .rows("SELECT tbl, pk, col, value, hlc, node, origin_id, origin_seq FROM sync_held_cell WHERE kind = 'unknown'");

String _englishText(String key) {
  final line = File(_englishSyncLocale).readAsLinesSync().firstWhere((l) => l.trimLeft().startsWith('$key:'));
  return line.substring(line.indexOf(':') + 1).trim();
}

void main() {
  group('Scenario 4.1 / SC-008 [simulated releases]: compatible releases exchange as equal versions', () {
    test('Scenario 4.1 [simulated]: A (v3 min2) and B (v2) exchange everything, like equal releases', () async {
      Future<String> run(SimulatedRelease first, SimulatedRelease second) async {
        final (lab, a, b) = await _pairOf(first, second);
        try {
          await addTask(a, 't1', 'task from A', extra: {'description': 'desc A'});
          await addNote(b, 'n1', 'note from B', content: 'body B');
          await addTag(a, 'tag1', 'tag from A');
          final pair = await lab.session(a, b);
          expect(pair.bothComplete, isTrue, reason: '$pair');
          expect((await lab.session(b, a)).bothComplete, isTrue);
          expect(await contentOf(a), await contentOf(b));
          return await contentOf(a);
        } finally {
          await lab.close();
        }
      }

      final mixed = await run(_v3Min2, _v2);
      final equal = await run(_v3Min3, _v3Min3);

      expect(mixed, equal, reason: 'the result is the one between equal versions');
      expect(mixed, contains('task from A'));
      expect(mixed, contains('note from B'));
    });

    test('Scenario 4.1 [simulated]: the older release (v2) can start the session too', () async {
      final (lab, a, b) = await _pairOf(_v3Min2, _v2);
      addTearDown(lab.close);
      await addTask(a, 't1', 'from newer');
      await addTask(b, 't2', 'from older');

      expect((await lab.session(b, a)).bothComplete, isTrue);
      expect((await lab.session(b, a)).bothComplete, isTrue);

      expect(await contentOf(a), await contentOf(b));
      expect(await findRow(b, 'task_table', 't1'), isNotNull);
      expect(await findRow(a, 'task_table', 't2'), isNotNull);
    });
  });

  group('SC-008 [simulated releases]: the Scenario 1.1 to 1.9 set on compatible different releases', () {
    for (final mix in [_compatibleDifferent, _equalReleases]) {
      for (final entry in scenarioSet.entries) {
        test('SC-008 [simulated] Scenario ${entry.key} on ${mix.label}', () => entry.value(mix));
      }
    }
  });

  group('Scenario 4.2 / SC-008 [simulated releases]: incompatible releases', () {
    late Lab lab;
    late LabDevice older;
    late LabDevice newer;

    setUp(() async {
      (lab, older, newer) = await _pairOf(_v2, _v3Min3);
      await addNote(older, 'from-older', 'OLDER-DATA');
      await addNote(newer, 'from-newer', 'NEWER-DATA');
    });
    tearDown(() => lab.close());

    test('Scenario 4.2 / SC-008 [simulated]: 0 items are exchanged and both ends name the older device', () async {
      final olderBefore = await contentOf(older);
      final newerBefore = await contentOf(newer);

      for (final pair in [await lab.session(older, newer), await lab.session(newer, older)]) {
        expect(pair.exchangedNothing, isTrue, reason: '$pair');
        for (final result in [pair.initiator, pair.responder]) {
          expect(result, isA<SessionFailed>());
          final failed = result as SessionFailed;
          expect(failed.category, SessionFailure.needsUpdate);
          expect(failed.mustUpdate, DeviceRef(older.memberId, older.name));
          expect(result.stats.envelopesSent, 0);
          expect(result.stats.envelopesReceived, 0);
        }
      }
      expect(await contentOf(older), olderBefore);
      expect(await contentOf(newer), newerBefore);
    });

    test('Scenario 4.2 [simulated]: the engine of each device records "needs update" and keeps its data', () async {
      final fromNewer = await lab.engineSync(newer, older);
      final fromOlder = await lab.engineSync(older, newer);

      expect(fromNewer.category, SyncResultCategory.needsUpdate, reason: 'the newer device names the older peer');
      expect(fromOlder.category, SyncResultCategory.thisDeviceNeedsUpdate, reason: 'the older device must update');
      for (final (device, peer, expected) in [
        (newer, older, SyncResultCategory.needsUpdate),
        (older, newer, SyncResultCategory.thisDeviceNeedsUpdate),
      ]) {
        final status = await DriftSyncPeerStatusStore(device.db.db).read(peer.memberId);
        expect(status?.lastResult, expected, reason: device.name);
        expect(status?.lastSuccessLocal, isNull);
      }
      expect(await findRow(older, 'note_table', 'from-newer'), isNull);
      expect(await findRow(newer, 'note_table', 'from-older'), isNull);
    });

    test('Scenario 4.2 [simulated]: the message template names the device', () {
      expect(_englishText('needs_update'), contains('{device}'));
      expect(_englishText('this_device_needs_update'), contains('{device}'));
    });

    test('Scenario 4.2 [simulated]: after the older device updates (min3), they sync again', () async {
      final (freshLab, a, b) = await _pairOf(_v3Min3, _v3Min3);
      addTearDown(freshLab.close);
      await addNote(a, 'after-update', 'AFTER-UPDATE');

      expect((await freshLab.session(a, b)).bothComplete, isTrue);

      expect(await findRow(b, 'note_table', 'after-update'), isNotNull);
    });
  });

  group('Scenario 4.3 [simulated releases]: a field an older device does not know is relayed unchanged', () {
    test('Scenario 4.3 [simulated]: C receives the future field exactly as A wrote it, through B', () async {
      final lab = await Lab.create();
      addTearDown(lab.close);
      final a = await lab.add('A', config: _v3Min2.config());
      final b = await lab.add('B', pairWith: a, config: _v2.config());
      final c = await lab.add('C', pairWith: a, config: _v2.config());
      await addNote(a, 'n43', 'note with a future field');
      await lab.converge(among: [a, b, c], rounds: 2);
      final written = await _writeFutureCell(a, 'n43');

      final p1 = await lab.session(a, b).timeout(const Duration(seconds: 20));
      final p2 = await lab.session(b, c).timeout(const Duration(seconds: 20));
      expect(p1.bothComplete, isTrue);
      expect(p2.bothComplete, isTrue);

      final atA = await _unknownCells(a);
      final atB = await _unknownCells(b);
      final atC = await _unknownCells(c);
      expect(atA, hasLength(1));
      expect(atB, hasLength(1), reason: 'B stores what it cannot interpret');
      expect(atC, hasLength(1), reason: 'B relayed it to C although A and C never met');
      for (final key in ['tbl', 'pk', 'col', 'hlc', 'node', 'origin_id', 'origin_seq']) {
        expect(atC.single[key], atA.single[key], reason: key);
      }
      expect(atC.single['hlc'], written['hlc']);
      expect(atC.single['origin_seq'], written['seq']);
      expect(
          Uint8List.fromList(atC.single['value'] as List<int>), Uint8List.fromList(atA.single['value'] as List<int>));
      expect(ChangeValue.decode(atC.single['value'] as Uint8List).toDart(), _futureValue);
      expect(await cellOf(c, 'note_table', 'n43', 'title'), 'note with a future field');
      expect(await contentOf(c), await contentOf(a), reason: 'known fields are unaffected');
    });
  });
}
