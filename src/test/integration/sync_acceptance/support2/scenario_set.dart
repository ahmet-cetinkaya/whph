// The Scenario 1.1 to 1.9 set (US1) as plain functions over a mix of
// simulated releases, so SC-008 can run the identical set once with equal
// releases and once with compatible different ones.
import 'package:flutter_test/flutter_test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'data_ops.dart';
import 'lab.dart';

const Duration _pause = Duration(milliseconds: 5);
const int _threeHoursMs = 3 * 60 * 60 * 1000;
const int _hlcBits = 16;
const int _interruptedChanges = 120;
const int _interruptedBatch = 20;
const int _cutFrames = 14;
const String _poisonTitle = 'poison';

/// One simulated release: its protocol version and the oldest it still syncs with.
class SimulatedRelease {
  final int protocolVersion;
  final int minCompatible;

  const SimulatedRelease(this.protocolVersion, this.minCompatible);

  SyncEngineConfig config({int? maxBatchChanges}) => SyncEngineConfig(
        protocolVersion: protocolVersion,
        minCompatible: minCompatible,
        delay: (_) async {},
        maxBatchChanges: maxBatchChanges ?? SyncLimits.maxBatchChanges,
      );
}

/// The releases of devices A, B and C of one scenario run.
class ReleaseMix {
  final String label;
  final List<SimulatedRelease> releases;

  const ReleaseMix(this.label, this.releases);
}

Future<void> _pauseBetweenEdits() => Future<void>.delayed(_pause);

/// A session that must complete on both ends.
Future<void> syncBoth(Lab lab, LabDevice from, LabDevice into) async {
  final pair = await lab.session(from, into);
  expect(pair.bothComplete, isTrue, reason: '${from.name} -> ${into.name}: $pair');
}

Future<void> setClockOffset(LabDevice device, int offsetMs) => device.db.sql(
    "UPDATE sync_state SET hlc = ((CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) + $offsetMs) << $_hlcBits)");

Future<(Lab, List<LabDevice>)> _openGroup(ReleaseMix mix, {int devices = 2, int? batch}) async {
  final lab = await Lab.create();
  final opened = <LabDevice>[];
  for (var index = 0; index < devices; index++) {
    opened.add(await lab.add(
      String.fromCharCode(0x41 + index),
      pairWith: index == 0 ? null : opened.first,
      config: mix.releases[index].config(maxBatchChanges: batch),
    ));
  }
  return (lab, opened);
}

Future<void> _inGroup(
  ReleaseMix mix,
  Future<void> Function(Lab lab, List<LabDevice> devices) body, {
  int devices = 2,
  int? batch,
}) async {
  final (lab, opened) = await _openGroup(mix, devices: devices, batch: batch);
  try {
    await body(lab, opened);
  } finally {
    await lab.close();
  }
}

Future<void> scenario11DifferentFields(ReleaseMix mix) => _inGroup(mix, (lab, devices) async {
      final [a, b] = devices;
      await addTask(a, 't1', 'original', extra: {'description': 'd0'});
      await syncBoth(lab, a, b);
      await updateRow(a, 'task_table', 't1', {'title': 'new title'});
      await updateRow(b, 'task_table', 't1', {'description': 'new description'});
      await syncBoth(lab, a, b);
      await syncBoth(lab, b, a);
      for (final device in [a, b]) {
        expect(await cellOf(device, 'task_table', 't1', 'title'), 'new title');
        expect(await cellOf(device, 'task_table', 't1', 'description'), 'new description');
      }
    });

Future<void> scenario12SameField(ReleaseMix mix) => _inGroup(mix, (lab, devices) async {
      final [a, b] = devices;
      await addNote(a, 'n1', 'note', content: 'start');
      await syncBoth(lab, a, b);
      await updateRow(a, 'note_table', 'n1', {'content': 'body from A'});
      await _pauseBetweenEdits();
      await updateRow(b, 'note_table', 'n1', {'content': 'body from B'});
      await syncBoth(lab, a, b);
      await syncBoth(lab, b, a);
      expect(await cellOf(a, 'note_table', 'n1', 'content'), 'body from B', reason: 'the later write wins (FR-004)');
      expect(await cellOf(b, 'note_table', 'n1', 'content'), 'body from B');
    });

Future<void> scenario13CausalOrderBeatsClocks(ReleaseMix mix) => _inGroup(mix, (lab, devices) async {
      final [a, b] = devices;
      await addTask(a, 't1', 'start');
      await syncBoth(lab, a, b);
      await setClockOffset(a, _threeHoursMs);
      await updateRow(a, 'task_table', 't1', {'title': 'A edit (clock ahead)'});
      await syncBoth(lab, a, b);
      await _pauseBetweenEdits();
      await updateRow(b, 'task_table', 't1', {'title': 'B edit after seeing A'});
      await syncBoth(lab, b, a);
      await syncBoth(lab, a, b);
      expect(await cellOf(a, 'task_table', 't1', 'title'), 'B edit after seeing A');
      expect(await cellOf(b, 'task_table', 't1', 'title'), 'B edit after seeing A');
    });

Future<void> scenario14Relay(ReleaseMix mix) => _inGroup(mix, (lab, devices) async {
      final [a, b, c] = devices;
      await lab.converge(among: [a, b, c], rounds: 2);
      await addTask(a, 'relayed', 'relayed task', extra: {'description': 'through B'});
      await updateRow(a, 'task_table', 'relayed', {'title': 'relayed edit'});
      await syncBoth(lab, a, b);
      await syncBoth(lab, b, c);
      expect(await cellOf(c, 'task_table', 'relayed', 'title'), 'relayed edit');
      expect(await cellOf(c, 'task_table', 'relayed', 'description'), 'through B');
      expect(await contentOf(c), await contentOf(a), reason: 'as if A had synced to C directly');
    }, devices: 3);

Future<void> scenario15NoStaleOverride(ReleaseMix mix) => _inGroup(mix, (lab, devices) async {
      final [a, b, c] = devices;
      await addNote(a, 'n1', 'note', content: 'start');
      await lab.converge(among: [a, b, c], rounds: 2);
      await updateRow(a, 'note_table', 'n1', {'content': 'older edit from A'});
      await _pauseBetweenEdits();
      await updateRow(c, 'note_table', 'n1', {'content': 'newer edit from C'});
      await syncBoth(lab, c, b);
      await syncBoth(lab, a, b);
      await lab.converge(among: [a, b, c]);
      for (final device in [a, b, c]) {
        expect(await cellOf(device, 'note_table', 'n1', 'content'), 'newer edit from C', reason: device.name);
      }
    }, devices: 3);

Future<void> scenario16DeleteAfterSeeingEdit(ReleaseMix mix) => _inGroup(mix, (lab, devices) async {
      final [a, b] = devices;
      await addTask(a, 't1', 'start');
      await syncBoth(lab, a, b);
      await updateRow(b, 'task_table', 't1', {'title': 'edited on B'});
      await syncBoth(lab, b, a);
      await _pauseBetweenEdits();
      await softDeleteRow(a, 'task_table', 't1');
      await syncBoth(lab, a, b);
      await syncBoth(lab, b, a);
      expect(await cellOf(a, 'task_table', 't1', 'deleted_date'), isNotNull);
      expect(await cellOf(b, 'task_table', 't1', 'deleted_date'), isNotNull);
    });

Future<void> scenario17ConcurrentDeleteAndEdit(ReleaseMix mix) async {
  for (final editIsLater in [true, false]) {
    await _inGroup(mix, (lab, devices) async {
      final [a, b] = devices;
      await addTask(a, 't1', 'start');
      await syncBoth(lab, a, b);
      if (editIsLater) {
        await softDeleteRow(a, 'task_table', 't1');
        await _pauseBetweenEdits();
        await updateRow(b, 'task_table', 't1', {'title': 'edited later'});
      } else {
        await updateRow(b, 'task_table', 't1', {'title': 'edited earlier'});
        await _pauseBetweenEdits();
        await softDeleteRow(a, 'task_table', 't1');
      }
      await syncBoth(lab, a, b);
      await syncBoth(lab, b, a);
      final aDeleted = await cellOf(a, 'task_table', 't1', 'deleted_date');
      final bDeleted = await cellOf(b, 'task_table', 't1', 'deleted_date');
      expect(aDeleted == null, bDeleted == null, reason: 'both devices decide the same');
      expect(aDeleted == null, editIsLater, reason: 'the latest action wins (FR-006)');
      expect(await contentOf(a), await contentOf(b));
    });
  }
}

Future<void> scenario18InterruptedSession(ReleaseMix mix) => _inGroup(mix, (lab, devices) async {
      final [a, b] = devices;
      for (var i = 0; i < _interruptedChanges; i++) {
        await addNote(a, 'bulk-$i', 'bulk $i');
      }
      final cut = await lab.session(a, b, faults: const TransportFaults(cutAfter: _cutFrames));
      expect(cut.bothComplete, isFalse);
      await syncBoth(lab, a, b);
      await syncBoth(lab, a, b);
      expect(await countRows(b, 'note_table'), _interruptedChanges, reason: 'none skipped, none duplicated');
      expect(await contentOf(b), await contentOf(a));
      expect(await b.db.count('SELECT COUNT(DISTINCT id) FROM note_table'), _interruptedChanges);
    }, batch: _interruptedBatch);

Future<void> scenario19FailedItem(ReleaseMix mix) => _inGroup(mix, (lab, devices) async {
      final [a, b] = devices;
      await b.db.sql('''
CREATE TRIGGER poison_insert BEFORE INSERT ON note_table WHEN NEW.title = '$_poisonTitle'
BEGIN SELECT RAISE(ABORT, 'poison'); END''');
      await addNote(a, 'stuck', _poisonTitle);
      await addNote(a, 'fine', 'fine note');

      final first = await lab.session(a, b);

      expect(first.bothComplete, isFalse, reason: 'not fully successful: $first');
      expect(first.responder, isA<SessionPartial>());
      expect((first.responder as SessionPartial).reasons, contains(PartialReason.itemsFailed));
      expect(await findRow(b, 'note_table', 'fine'), isNotNull, reason: 'the other changes are kept');
      expect(await findRow(b, 'note_table', 'stuck'), isNull);

      await b.db.sql('DROP TRIGGER poison_insert');
      await syncBoth(lab, a, b);
      expect(await findRow(b, 'note_table', 'stuck'), isNotNull, reason: 'the failed item is tried again');
    });

/// Every scenario of the set, in order, by its id.
final Map<String, Future<void> Function(ReleaseMix)> scenarioSet = {
  '1.1': scenario11DifferentFields,
  '1.2': scenario12SameField,
  '1.3': scenario13CausalOrderBeatsClocks,
  '1.4': scenario14Relay,
  '1.5': scenario15NoStaleOverride,
  '1.6': scenario16DeleteAfterSeeingEdit,
  '1.7': scenario17ConcurrentDeleteAndEdit,
  '1.8': scenario18InterruptedSession,
  '1.9': scenario19FailedItem,
};
